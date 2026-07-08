import csv
import io

from django.db.models import Count, Max
from rest_framework.response import Response
from rest_framework.views import APIView
from django.http import HttpResponse

from environment.models import WeatherEvent
from mobility.models import RoadSegment, Prediction
from reports.models import Report
from .permissions import IsAutorite


def _composite_score(congestion, nb_reports_actifs, has_alerte_meteo):
    """score = 0.5×congestion + 0.3×(nb_reports×10) + 0.2×(100 si alerte météo)"""
    return (
        0.5 * congestion
        + 0.3 * min(nb_reports_actifs * 10, 100)
        + 0.2 * (100 if has_alerte_meteo else 0)
    )


class CriticalZonesView(APIView):
    permission_classes = [IsAutorite]

    def get(self, request):
        zones_alerte = set(
            WeatherEvent.objects.exclude(type='normal').values_list('zone', flat=True)
        )
        latest_pred_ids = (
            Prediction.objects.values('segment')
            .annotate(latest_id=Max('id'))
            .values_list('latest_id', flat=True)
        )
        predictions = Prediction.objects.filter(id__in=latest_pred_ids).select_related('segment')
        active_counts = dict(
            Report.objects.filter(statut='actif')
            .values('segment')
            .annotate(cnt=Count('id'))
            .values_list('segment', 'cnt')
        )
        results = []
        for pred in predictions:
            seg = pred.segment
            nb_reports = active_counts.get(seg.id, 0)
            has_meteo = seg.zone_inondable and seg.zone in zones_alerte
            score = _composite_score(pred.score_predit, nb_reports, has_meteo)
            results.append({
                'segment_id': seg.id,
                'segment_nom': seg.nom,
                'zone': seg.zone,
                'zone_inondable': seg.zone_inondable,
                'congestion_predite': pred.score_predit,
                'nb_signalements_actifs': nb_reports,
                'alerte_meteo': has_meteo,
                'score_composite': round(score, 2),
            })
        results.sort(key=lambda x: x['score_composite'], reverse=True)
        return Response(results[:5])


class DashboardStatsView(APIView):
    permission_classes = [IsAutorite]

    def get(self, request):
        zones_alerte = set(
            WeatherEvent.objects.exclude(type='normal').values_list('zone', flat=True)
        )
        nb_signalements_actifs = Report.objects.filter(statut='actif').count()
        segments_alerte = RoadSegment.objects.filter(zone_inondable=True, zone__in=zones_alerte).count()
        avg_congestion = None
        latest_ids = (
            Prediction.objects.values('segment')
            .annotate(latest_id=Max('id'))
            .values_list('latest_id', flat=True)
        )
        preds = Prediction.objects.filter(id__in=latest_ids)
        if preds.exists():
            avg_congestion = round(
                sum(p.score_predit for p in preds) / preds.count(), 1
            )
        return Response({
            'nb_signalements_actifs': nb_signalements_actifs,
            'segments_en_alerte_meteo': segments_alerte,
            'congestion_moyenne': avg_congestion,
        })


class DashboardExportView(APIView):
    permission_classes = [IsAutorite]

    def get(self, request):
        zones_view = CriticalZonesView()
        zones_view.request = request
        zones_response = zones_view.get(request)
        rows = zones_response.data

        output = io.StringIO()
        writer = csv.DictWriter(output, fieldnames=[
            'segment_id', 'segment_nom', 'zone', 'zone_inondable',
            'congestion_predite', 'nb_signalements_actifs', 'alerte_meteo', 'score_composite',
        ])
        writer.writeheader()
        writer.writerows(rows)
        response = HttpResponse(output.getvalue(), content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="critical_zones.csv"'
        return response
