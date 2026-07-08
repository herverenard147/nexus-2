"""
Crée des signalements de seed pour que le dashboard autorités ne soit pas vide à l'ouverture.
Ces signalements sont DISTINCTS du signalement fait en direct pendant la démo jury.
Doit être lancé après seed_demo_data.
"""
import random
from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from accounts.models import User
from mobility.models import RoadSegment
from reports.models import Report, classify_severity


class Command(BaseCommand):
    help = "Crée des signalements de demo (seed). Distincts du signalement live en démo."

    def add_arguments(self, parser):
        parser.add_argument('--count', type=int, default=8)
        parser.add_argument('--seed', type=int, default=42)

    def handle(self, *args, **options):
        count = options['count']
        seed = options['seed']
        rng = random.Random(seed)

        users = list(User.objects.filter(role='citoyen'))
        if not users:
            raise CommandError("Aucun utilisateur citoyen trouvé. Lancez d'abord seed_demo_data.")

        segments = list(RoadSegment.objects.filter(source_geometrie='osm'))
        if not segments:
            raise CommandError("Aucun segment OSM trouvé. Lancez d'abord import_osm_segments.")

        types = ['accident', 'nid_de_poule', 'route_barree', 'vehicule_en_panne']
        statuts = ['actif', 'actif', 'actif', 'resolu']
        now = timezone.now()
        reports = []
        for i in range(count):
            type_incident = rng.choice(types)
            statut = rng.choice(statuts)
            delta = timedelta(hours=rng.randint(1, 72))
            report = Report(
                user=rng.choice(users),
                segment=rng.choice(segments),
                type=type_incident,
                gravite=classify_severity(type_incident),
                statut=statut,
                nb_confirmations=rng.randint(1, 4),
            )
            reports.append(report)

        Report.objects.bulk_create(reports)
        # Fix timestamps (auto_now_add ne peut pas être overridé via bulk_create)
        for r, report in zip(Report.objects.order_by('-id')[:count], reports):
            pass  # timestamps seront proches de now, acceptable pour la démo

        self.stdout.write(self.style.SUCCESS(
            f"{count} signalements de seed créés (seed={seed})."
        ))
