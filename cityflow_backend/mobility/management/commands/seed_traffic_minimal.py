"""
Génère un TrafficRecord par (segment × heure × jour_semaine) pour que le
prédicteur ML produise des scores VARIÉS (pas tous à 50).

Volume : 4206 segments × 24 h × 7 jours = ~706 k lignes — bulk_create par
batches de 5 000. Durée estimée ~60 s sur Render gratuit (PostgreSQL).

Reproductible : même --seed → même distribution.
"""
import math
import random
from datetime import datetime, timedelta, timezone as dt_timezone

from django.core.management.base import BaseCommand
from django.utils import timezone

from mobility.models import RoadSegment, TrafficRecord

BATCH = 5_000


def _congestion(hour: int, weekday: int, segment_id: int, rng: random.Random) -> int:
    """
    Score réaliste : courbe en cloche heures de pointe + bruit par segment.
    weekday : 0=lundi … 6=dimanche
    """
    is_weekend = weekday >= 5
    if is_weekend:
        base = 15 + rng.gauss(0, 5)
    else:
        matin = 70 * math.exp(-((hour - 8) ** 2) / 2.5)
        soir  = 75 * math.exp(-((hour - 18) ** 2) / 2.5)
        base  = max(matin, soir) + 10
        # variation par segment : ±20 pts pour diversifier
        base += (segment_id % 40) - 20
        base += rng.gauss(0, 8)

    return max(0, min(100, int(round(base))))


class Command(BaseCommand):
    help = "Seed léger : 1 TrafficRecord par (segment × heure × jour_semaine)"

    def add_arguments(self, parser):
        parser.add_argument('--seed', type=int, default=42)
        parser.add_argument('--clear', action='store_true',
                            help='Supprime les TrafficRecord simulés existants avant de seeder')

    def handle(self, *args, **options):
        rng = random.Random(options['seed'])

        segments = list(RoadSegment.objects.filter(source_geometrie='osm').values_list('id', flat=True))
        if not segments:
            self.stderr.write("Aucun segment OSM. Lancez import_osm_segments d'abord.")
            return

        if options['clear']:
            deleted, _ = TrafficRecord.objects.filter(source='simule').delete()
            self.stdout.write(f"  {deleted} TrafficRecord simulés supprimés.")

        total_existing = TrafficRecord.objects.filter(source='simule').count()
        self.stdout.write(f"{len(segments)} segments | TrafficRecord existants : {total_existing}")

        # Ancre temporelle : lundi de la semaine courante à minuit UTC
        now = timezone.now()
        # Trouver le lundi de la semaine courante
        monday = (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )

        batch: list[TrafficRecord] = []
        created = 0

        for seg_id in segments:
            for weekday in range(7):          # 0=lundi … 6=dimanche
                for hour in range(24):
                    score = _congestion(hour, weekday, seg_id, rng)
                    ts = monday + timedelta(days=weekday, hours=hour)
                    batch.append(TrafficRecord(
                        segment_id=seg_id,
                        timestamp=ts,
                        niveau_congestion=score,
                        source='simule',
                    ))
                    if len(batch) >= BATCH:
                        TrafficRecord.objects.bulk_create(batch, ignore_conflicts=False)
                        created += len(batch)
                        batch = []
                        self.stdout.write(f"  {created:,} insérés…")

        if batch:
            TrafficRecord.objects.bulk_create(batch, ignore_conflicts=False)
            created += len(batch)

        self.stdout.write(self.style.SUCCESS(
            f"seed_traffic_minimal terminé : {created:,} TrafficRecord créés."
        ))
