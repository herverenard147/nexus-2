"""
Répare le champ `zone` des segments dont la zone == nom de la rue
(bug _zone_from_feature : 'name' utilisé comme fallback avant 'Abidjan').

Stratégie :
1. Si le nom de la rue contient le nom d'une commune connue → utilise cette commune.
2. Sinon → 'Abidjan'.

Recalcule aussi zone_inondable après la correction.
"""
from django.core.management.base import BaseCommand
from django.db.models import F

from mobility.models import RoadSegment

COMMUNES = [
    ('yopougon', 'Yopougon'),
    ('abobo', 'Abobo'),
    ('attécoubé', 'Attécoubé'),
    ('attecoube', 'Attécoubé'),
    ('cocody', 'Cocody'),
    ('adjamé', 'Adjamé'),
    ('adjame', 'Adjamé'),
    ('koumassi', 'Koumassi'),
    ('marcory', 'Marcory'),
    ('plateau', 'Plateau'),
    ('treichville', 'Treichville'),
    ('port-bouët', 'Port-Bouët'),
    ('port-bouet', 'Port-Bouët'),
    ('port bouet', 'Port-Bouët'),
    ('bingerville', 'Bingerville'),
    ('anyama', 'Anyama'),
    ('songon', 'Songon'),
]

ZONES_INONDABLES = {'yopougon', 'abobo', 'attécoubé', 'nord'}


def _commune_from_nom(nom: str) -> str:
    nom_lower = nom.lower()
    for keyword, commune in COMMUNES:
        if keyword in nom_lower:
            return commune
    return 'Abidjan'


def _is_inondable(zone: str) -> bool:
    z = zone.lower()
    return any(zi in z for zi in ZONES_INONDABLES)


class Command(BaseCommand):
    help = "Corrige zone='nom de rue' → commune ou Abidjan, recalcule zone_inondable"

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        dry_run = options['dry_run']

        affected = RoadSegment.objects.filter(zone=F('nom'))
        total = affected.count()
        self.stdout.write(f"Segments avec zone == nom : {total}")

        if total == 0:
            self.stdout.write(self.style.SUCCESS("Aucune correction nécessaire."))
            return

        commune_counts: dict[str, int] = {}
        to_update = []

        for seg in affected.iterator(chunk_size=500):
            new_zone = _commune_from_nom(seg.nom)
            seg.zone = new_zone
            seg.zone_inondable = _is_inondable(new_zone)
            commune_counts[new_zone] = commune_counts.get(new_zone, 0) + 1
            to_update.append(seg)

        self.stdout.write("Distribution après correction :")
        for commune, count in sorted(commune_counts.items(), key=lambda x: -x[1]):
            self.stdout.write(f"  {commune}: {count}")

        if dry_run:
            self.stdout.write(self.style.WARNING("--dry-run : aucune écriture."))
            return

        BATCH = 1_000
        updated = 0
        for i in range(0, len(to_update), BATCH):
            chunk = to_update[i:i + BATCH]
            RoadSegment.objects.bulk_update(chunk, ['zone', 'zone_inondable'])
            updated += len(chunk)

        self.stdout.write(self.style.SUCCESS(f"fix_zones terminé : {updated} segments corrigés."))
