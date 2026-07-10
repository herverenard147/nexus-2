"""
Importe les segments routiers depuis un export GeoJSON Overpass.

Requête Overpass utilisée (à générer via https://overpass-turbo.eu/) :
  [out:json][timeout:60];
  (
    way["highway"~"^(motorway|trunk|primary|secondary|tertiary)$"]
       (5.0,−4.3,5.6,−3.7);
  );
  out body geom;

Emprise : Grand Abidjan (~5.0–5.6°N, −4.3 à −3.7°E).
Source : export HDX ou Overpass, à télécharger au préalable (pas d'appel réseau live).

Zones à risque d'inondation documentées (sources : BNETD, Plan de Gestion des Inondations Abidjan 2018,
rapports OCHA) : Yopougon, Abobo, Attécoubé — traversées par des bassins versants non canalisés ;
corridor Autoroute du Nord (Boulevard Latrille) — zone basse proche de la lagune.
"""
import json
import os

from django.core.management.base import BaseCommand, CommandError

from mobility.models import RoadSegment

ZONES_INONDABLES = {'yopougon', 'abobo', 'attécoubé', 'attecoube', 'nord'}


def _zone_from_feature(props):
    for key in ('addr:city', 'is_in:city', 'addr:suburb'):
        val = props.get(key, '')
        if val:
            return val
    return 'Abidjan'


def _is_inondable(zone: str) -> bool:
    z = zone.lower()
    return any(zi in z for zi in ZONES_INONDABLES)


class Command(BaseCommand):
    help = "Importe les segments OSM depuis un GeoJSON Overpass"

    def add_arguments(self, parser):
        parser.add_argument('--fichier', required=True, help='Chemin vers le fichier GeoJSON')
        parser.add_argument('--dry-run', action='store_true', help='Affiche le résumé sans écrire en base')

    def handle(self, *args, **options):
        fichier = options['fichier']
        dry_run = options['dry_run']

        if not os.path.exists(fichier):
            raise CommandError(f"Fichier introuvable : {fichier}")

        with open(fichier, encoding='utf-8') as f:
            data = json.load(f)

        features = data.get('features', data.get('elements', []))
        if not features and 'elements' in data:
            features = data['elements']

        to_create = []
        to_update = []
        existing_ids = {
            s.nom: s for s in RoadSegment.objects.filter(source_geometrie='osm')
        }

        zone_counts = {}
        inondable_count = 0

        for feat in features:
            props = feat.get('properties', feat.get('tags', {})) or {}
            geom = feat.get('geometry', {})

            nom = props.get('name') or props.get('ref', '')
            zone = _zone_from_feature(props)
            if not nom:
                nom = f"Route sans nom - {zone}"

            coords = None
            if geom.get('type') == 'LineString' and geom.get('coordinates'):
                coords = geom['coordinates'][0]
            elif feat.get('type') == 'way' and feat.get('geometry'):
                geom_pts = feat['geometry']
                if geom_pts:
                    coords = [geom_pts[0]['lon'], geom_pts[0]['lat']]

            if not coords:
                continue

            lon, lat = (coords[0], coords[1]) if len(coords) >= 2 else (0.0, 0.0)
            inondable = _is_inondable(zone)
            zone_counts[zone] = zone_counts.get(zone, 0) + 1
            if inondable:
                inondable_count += 1

            if nom in existing_ids:
                seg = existing_ids[nom]
                seg.latitude = lat
                seg.longitude = lon
                seg.zone = zone
                seg.zone_inondable = inondable
                to_update.append(seg)
            else:
                to_create.append(RoadSegment(
                    nom=nom, latitude=lat, longitude=lon,
                    zone=zone, zone_inondable=inondable,
                    source_geometrie='osm',
                ))

        self.stdout.write(f"\nRésumé : {len(to_create)} à créer, {len(to_update)} à mettre à jour")
        self.stdout.write(f"Segments zone_inondable : {inondable_count}")
        for z, c in sorted(zone_counts.items()):
            self.stdout.write(f"  {z}: {c}")

        if dry_run:
            self.stdout.write(self.style.WARNING("--dry-run : aucune écriture en base."))
            return

        if to_create:
            RoadSegment.objects.bulk_create(to_create, ignore_conflicts=True)
        if to_update:
            RoadSegment.objects.bulk_update(to_update, ['latitude', 'longitude', 'zone', 'zone_inondable'])

        self.stdout.write(self.style.SUCCESS(
            f"Import terminé : {len(to_create)} créés, {len(to_update)} mis à jour."
        ))
