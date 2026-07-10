"""
Supprime les doublons parfaits de segments (distance < ~1m, même nom).
Garde le segment avec le plus petit id. Réassigne les FK (Report, Prediction,
TrafficRecord) vers le segment conservé avant suppression.

Usage :
    python manage.py deduplicate_perfect_segments            # dry-run
    python manage.py deduplicate_perfect_segments --execute  # exécution réelle
"""
import logging
from collections import defaultdict

from django.core.management.base import BaseCommand
from django.db import transaction

from environment.models import WeatherEvent  # noqa – import pour vérif FK éventuelle
from mobility.models import Prediction, RoadSegment, TrafficRecord
from reports.models import Report

logger = logging.getLogger('mobility')

# (0.00001 deg)² ≈ (1.11m)² à lat 5°N — seuil conservateur pour doublons parfaits
_THRESHOLD_SQ = 1e-10


def _find(parent: dict, x: int) -> int:
    if x not in parent:
        parent[x] = x
    if parent[x] != x:
        parent[x] = _find(parent, parent[x])
    return parent[x]


def _union(parent: dict, x: int, y: int) -> None:
    rx, ry = _find(parent, x), _find(parent, y)
    if rx != ry:
        # Le plus petit id (segment le plus ancien) devient la racine
        if rx < ry:
            parent[ry] = rx
        else:
            parent[rx] = ry


class Command(BaseCommand):
    help = (
        'Supprime les doublons parfaits de RoadSegment (même nom, distance < ~1 m). '
        'Dry-run par défaut — relancer avec --execute pour appliquer.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--execute',
            action='store_true',
            default=False,
            help='Applique réellement la déduplication (défaut : dry-run).',
        )

    def handle(self, *args, **options):
        execute = options['execute']
        mode = 'EXÉCUTION' if execute else 'DRY-RUN'
        self.stdout.write(f'\n=== deduplicate_perfect_segments — {mode} ===\n')

        # 1. Charger les segments des noms dupliqués uniquement
        dup_noms = (
            RoadSegment.objects
            .values('nom')
            .annotate()
            .raw(
                'SELECT nom, COUNT(*) c FROM mobility_roadsegment '
                'GROUP BY nom HAVING c > 1'
            )
        )
        dup_noms_set = {r.nom for r in dup_noms}

        segments = list(
            RoadSegment.objects
            .filter(nom__in=dup_noms_set)
            .values('id', 'nom', 'latitude', 'longitude', 'zone')
            .order_by('id')
        )
        self.stdout.write(f'Segments avec nom partagé : {len(segments)}')

        # 2. Paires parfaites (même nom, dist² < seuil)
        by_nom: dict = defaultdict(list)
        for s in segments:
            by_nom[s['nom']].append(s)

        pairs = []
        for group in by_nom.values():
            if len(group) < 2:
                continue
            for i in range(len(group)):
                for j in range(i + 1, len(group)):
                    a, b = group[i], group[j]
                    dlat = a['latitude'] - b['latitude']
                    dlon = a['longitude'] - b['longitude']
                    if dlat * dlat + dlon * dlon < _THRESHOLD_SQ:
                        pairs.append((a['id'], b['id']))

        self.stdout.write(f'Paires parfaites trouvées   : {len(pairs)}')

        # 3. Union-Find → clusters
        parent: dict = {}
        for a, b in pairs:
            _union(parent, a, b)

        all_ids = {id_ for p in pairs for id_ in p}
        clusters: dict = defaultdict(set)
        for id_ in all_ids:
            clusters[_find(parent, id_)].add(id_)

        self.stdout.write(f'Clusters identifiés         : {len(clusters)}')

        # 4. Plan de suppression
        plan = []
        total_delete = total_reports = total_preds = total_trafic = 0

        seg_index = {s['id']: s for s in segments}

        for root, members in sorted(clusters.items()):
            keeper = min(members)
            to_delete = sorted(members - {keeper})
            if not to_delete:
                continue

            nb_r = Report.objects.filter(segment_id__in=to_delete).count()
            nb_p = Prediction.objects.filter(segment_id__in=to_delete).count()
            nb_t = TrafficRecord.objects.filter(segment_id__in=to_delete).count()

            plan.append({
                'keeper': keeper,
                'delete': to_delete,
                'nb_reports': nb_r,
                'nb_preds': nb_p,
                'nb_trafic': nb_t,
            })
            total_delete += len(to_delete)
            total_reports += nb_r
            total_preds += nb_p
            total_trafic += nb_t

        # 5. Affichage du plan
        self.stdout.write(f'\n{"="*62}')
        self.stdout.write(f'RÉSUMÉ')
        self.stdout.write(f'{"="*62}')
        self.stdout.write(f'  Segments à supprimer      : {total_delete}')
        self.stdout.write(f'  Segments conservés        : {len(plan)}')
        self.stdout.write(f'  Signalements à réassigner : {total_reports}')
        self.stdout.write(f'  Prédictions à réassigner  : {total_preds}')
        self.stdout.write(f'  TrafficRecords à réassigner: {total_trafic}')
        self.stdout.write(f'{"="*62}')

        self.stdout.write('\nDÉTAIL PAR CLUSTER :')
        for entry in plan:
            k = entry['keeper']
            ks = seg_index.get(k, {})
            self.stdout.write(
                f"\n  ✓ GARDER  id={k:5d}  {ks.get('nom','')}  "
                f"({ks.get('latitude',''):.6f}, {ks.get('longitude',''):.6f})  "
                f"zone={ks.get('zone','')}"
            )
            for del_id in entry['delete']:
                ds = seg_index.get(del_id, {})
                suffix = ''
                if entry['nb_reports'] or entry['nb_preds']:
                    suffix = (
                        f"  ← {entry['nb_reports']} report(s) + "
                        f"{entry['nb_preds']} pred(s) réassignés"
                    )
                self.stdout.write(
                    f"    ✗ SUPPR  id={del_id:5d}  {ds.get('nom','')}  "
                    f"({ds.get('latitude',''):.6f}, {ds.get('longitude',''):.6f}){suffix}"
                )

        # 6. Exécution
        if not execute:
            self.stdout.write(
                "\n[DRY-RUN] Rien n'a été modifié. "
                "Relancer avec --execute pour appliquer."
            )
            return

        self.stdout.write(f'\n{"="*62}')
        self.stdout.write('EXÉCUTION (transaction atomique)')
        self.stdout.write(f'{"="*62}')

        before_count = RoadSegment.objects.count()

        with transaction.atomic():
            for entry in plan:
                keeper_id = entry['keeper']
                to_delete = entry['delete']

                # Réassigner les FK avant suppression
                if entry['nb_reports']:
                    n = Report.objects.filter(segment_id__in=to_delete).update(
                        segment_id=keeper_id
                    )
                    self.stdout.write(f'  Report réassignés → {keeper_id}: {n}')

                if entry['nb_preds']:
                    n = Prediction.objects.filter(segment_id__in=to_delete).update(
                        segment_id=keeper_id
                    )
                    self.stdout.write(f'  Prediction réassignées → {keeper_id}: {n}')

                if entry['nb_trafic']:
                    n = TrafficRecord.objects.filter(segment_id__in=to_delete).update(
                        segment_id=keeper_id
                    )
                    self.stdout.write(f'  TrafficRecord réassignés → {keeper_id}: {n}')

                deleted, _ = RoadSegment.objects.filter(id__in=to_delete).delete()
                self.stdout.write(
                    f'  Supprimé(s) : {to_delete}  ({deleted} segment(s))'
                )

        after_count = RoadSegment.objects.count()
        self.stdout.write(f'\nTerminé.')
        self.stdout.write(f'  Avant : {before_count} segments')
        self.stdout.write(f'  Après : {after_count} segments')
        self.stdout.write(f'  Supprimés : {before_count - after_count}')

        logger.info(
            'deduplicate_perfect_segments: %d segments supprimés (%d → %d)',
            before_count - after_count, before_count, after_count,
        )
