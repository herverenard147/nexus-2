from django.utils import timezone
from rest_framework.response import Response
from rest_framework.views import APIView

from mobility.models import RoadSegment
from mobility.serializers import RoadSegmentSerializer
from .models import WeatherEvent
from .serializers import WeatherEventSerializer


class WeatherCurrentView(APIView):
    def get(self, request):
        zone = request.query_params.get('zone')
        qs = WeatherEvent.objects.order_by('-timestamp')
        if zone:
            qs = qs.filter(zone__icontains=zone)
        latest = qs.first()
        if not latest:
            return Response([])
        return Response(WeatherEventSerializer(latest).data)


class WeatherAlertsView(APIView):
    """Retourne les segments zone_inondable avec un WeatherEvent actif (non normal)."""

    def get(self, request):
        zones_alerte = set(
            WeatherEvent.objects.exclude(type='normal')
            .values_list('zone', flat=True)
            .distinct()
        )
        segments = RoadSegment.objects.filter(
            zone_inondable=True, zone__in=zones_alerte
        )
        return Response(RoadSegmentSerializer(segments, many=True).data)
