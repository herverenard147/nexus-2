from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import NotFound

from .models import RoadSegment, TrafficRecord, Prediction
from .serializers import RoadSegmentSerializer, TrafficRecordSerializer, PredictionSerializer
from .throttles import PredictionsReadThrottle


class RoadSegmentViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = RoadSegment.objects.all()
    serializer_class = RoadSegmentSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        qs = super().get_queryset()
        zone = self.request.query_params.get('zone')
        if zone:
            qs = qs.filter(zone__icontains=zone)
        return qs

    @action(detail=True, methods=['get'], url_path='history',
            throttle_classes=[PredictionsReadThrottle])
    def history(self, request, pk=None):
        try:
            segment = RoadSegment.objects.get(pk=pk)
        except RoadSegment.DoesNotExist:
            raise NotFound(f"Segment {pk} introuvable.")
        records = TrafficRecord.objects.filter(segment=segment).order_by('-timestamp')[:100]
        return Response(TrafficRecordSerializer(records, many=True).data)


class PredictionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PredictionSerializer
    permission_classes = [AllowAny]
    throttle_classes = [PredictionsReadThrottle]

    def get_queryset(self):
        if self.action == 'list':
            from django.db.models import Max
            latest_ids = (
                Prediction.objects.values('segment')
                .annotate(latest_id=Max('id'))
                .values_list('latest_id', flat=True)
            )
            return Prediction.objects.filter(id__in=latest_ids)
        segment_id = self.kwargs.get('pk')
        if segment_id and not RoadSegment.objects.filter(pk=segment_id).exists():
            raise NotFound(f"Segment {segment_id} introuvable.")
        return Prediction.objects.filter(segment_id=self.kwargs.get('pk'))
