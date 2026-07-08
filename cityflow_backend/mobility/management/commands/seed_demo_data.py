"""
Génère des utilisateurs fictifs et un historique de trafic simulé (30 jours par défaut).
Doit être lancé APRÈS import_osm_segments.
Reproductible : même --seed → mêmes données.
"""
import math
import random
from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from accounts.models import User
from mobility.models import RoadSegment, TrafficRecord

PRENOMS = ['Awa', 'Adjoua', 'Fatou', 'Mariam', 'Aya', 'Kouamé', 'Mamadou', 'Ibrahim', 'Serge', 'Yves']
NOMS = ['Kouassi', 'Yao', 'Koffi', 'Aka', 'Konan', "N'Guessan", 'Traoré', 'Ouattara', 'Bamba', 'Coulibaly']

PROFILS = ['domicile_travail', 'domicile_travail', 'domicile_travail',
           'domicile_travail', 'domicile_travail', 'domicile_travail',
           'domicile_travail', 'ecole', 'ecole', 'marche']

ZONES_RESIDENCE = ['Yopougon', 'Abobo', 'Koumassi', 'Port-Bouët', 'Attécoubé']
ZONES_TRAVAIL = ['Plateau', 'Cocody', 'Marcory', 'Adjamé', 'Treichville']

BATCH = 2000


def _congestion_horaire(hour, weekday):
    """Courbe en cloche autour des heures de pointe locales d'Abidjan."""
    is_weekend = weekday >= 5
    if is_weekend:
        base = 20
    else:
        matin = 60 * math.exp(-((hour - 8) ** 2) / 2)
        soir = 65 * math.exp(-((hour - 18) ** 2) / 2)
        base = max(matin, soir) + 10
    return base


class Command(BaseCommand):
    help = "Génère les données de démo (utilisateurs + historique trafic simulé)"

    def add_arguments(self, parser):
        parser.add_argument('--users', type=int, default=100)
        parser.add_argument('--days', type=int, default=30)
        parser.add_argument('--seed', type=int, default=42)

    def handle(self, *args, **options):
        nb_users = options['users']
        nb_days = options['days']
        seed = options['seed']
        rng = random.Random(seed)

        segments = list(RoadSegment.objects.filter(source_geometrie='osm'))
        if not segments:
            raise CommandError(
                "Aucun segment OSM trouvé. Lancez d'abord : python manage.py import_osm_segments"
            )
        self.stdout.write(f"{len(segments)} segments OSM chargés.")

        # Utilisateurs fictifs
        self.stdout.write(f"Création de {nb_users} utilisateurs...")
        users_to_create = []
        existing_usernames = set(User.objects.values_list('username', flat=True))
        for i in range(nb_users):
            prenom = rng.choice(PRENOMS)
            nom = rng.choice(NOMS)
            username = f"{prenom.lower()}.{nom.lower().replace(chr(39), '')}_{i}"
            if username in existing_usernames:
                continue
            existing_usernames.add(username)
            profil = rng.choice(PROFILS)
            zone = rng.choice(ZONES_RESIDENCE)
            users_to_create.append(User(
                username=username,
                email=f"{username}@cityflow.ci",
                first_name=prenom,
                last_name=nom,
                role='citoyen',
                zone=zone,
            ))
        created_users = User.objects.bulk_create(users_to_create, ignore_conflicts=True)
        self.stdout.write(f"{len(users_to_create)} utilisateurs créés.")

        # Historique de trafic simulé
        self.stdout.write(f"Génération de l'historique trafic ({nb_days} jours, {len(segments)} segments)…")
        now = timezone.now().replace(minute=0, second=0, microsecond=0)
        records = []
        count = 0

        for day_offset in range(nb_days):
            day_ts = now - timedelta(days=day_offset)
            weekday = day_ts.weekday()
            for hour in range(24):
                ts = day_ts.replace(hour=hour)
                base = _congestion_horaire(hour, weekday)
                for seg in segments:
                    noise = rng.gauss(0, 8)
                    niveau = max(0, min(100, int(round(base + noise))))
                    records.append(TrafficRecord(
                        segment=seg,
                        timestamp=ts,
                        niveau_congestion=niveau,
                        source='simule',
                    ))
                    count += 1
                    if len(records) >= BATCH:
                        TrafficRecord.objects.bulk_create(records, ignore_conflicts=True)
                        records = []

        if records:
            TrafficRecord.objects.bulk_create(records, ignore_conflicts=True)

        # Assertions de cohérence
        sample = list(TrafficRecord.objects.filter(source='simule').values_list('niveau_congestion', flat=True)[:1000])
        assert all(0 <= v <= 100 for v in sample), "ERREUR : niveau_congestion hors [0,100]"
        inondable_count = RoadSegment.objects.filter(zone_inondable=True).count()
        pct = inondable_count / len(segments) * 100 if segments else 0
        self.stdout.write(f"Segments zone_inondable : {inondable_count}/{len(segments)} ({pct:.1f}%)")
        self.stdout.write(self.style.SUCCESS(f"Seed terminé : {count} TrafficRecord créés."))
