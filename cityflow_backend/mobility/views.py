from django.db.models import Avg, Count, Max, Q
from rest_framework import generics, viewsets
from rest_framework.decorators import action
from rest_framework.pagination import LimitOffsetPagination
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.exceptions import NotFound

from .models import RoadSegment, TrafficRecord, Prediction
from .serializers import RoadSegmentSerializer, TrafficRecordSerializer, PredictionSerializer
from .throttles import PredictionsReadThrottle

_KNOWN_COMMUNES = [
    'Abidjan', 'Abobo', 'Yopougon', 'Bingerville', 'Treichville',
    'Port-Bouët', 'Koumassi', 'Songon', 'Adjamé',
]


class PredictionPagination(LimitOffsetPagination):
    default_limit = 25
    max_limit = 100


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

    @action(detail=True, methods=['get'], url_path='predict',
            throttle_classes=[PredictionsReadThrottle])
    def predict(self, request, pk=None):
        """Prédiction live (appel direct du predictor ML/fallback)."""
        from .ml.predictor import predict_congestion
        try:
            result = predict_congestion(int(pk))
        except ValueError as exc:
            raise NotFound(str(exc))
        return Response(result)


class PredictionViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PredictionSerializer
    permission_classes = [AllowAny]
    throttle_classes = [PredictionsReadThrottle]
    pagination_class = PredictionPagination

    def get_queryset(self):
        if self.action == 'list':
            latest_ids = (
                Prediction.objects.values('segment')
                .annotate(latest_id=Max('id'))
                .values_list('latest_id', flat=True)
            )
            qs = Prediction.objects.filter(id__in=latest_ids).order_by('-score_predit')
            zone = self.request.query_params.get('zone')
            if zone:
                qs = qs.filter(segment__zone__iexact=zone)
            return qs
        segment_id = self.kwargs.get('pk')
        if segment_id and not RoadSegment.objects.filter(pk=segment_id).exists():
            raise NotFound(f"Segment {segment_id} introuvable.")
        return Prediction.objects.filter(segment_id=self.kwargs.get('pk'))


class CommuneStatsView(generics.GenericAPIView):
    permission_classes = [AllowAny]
    throttle_classes = [PredictionsReadThrottle]

    def get(self, request):
        latest_ids = (
            Prediction.objects.values('segment')
            .annotate(latest_id=Max('id'))
            .values_list('latest_id', flat=True)
        )
        stats = (
            Prediction.objects
            .filter(id__in=latest_ids, segment__zone__in=_KNOWN_COMMUNES)
            .values('segment__zone')
            .annotate(
                nb_segments=Count('id'),
                score_moyen=Avg('score_predit'),
                score_max=Max('score_predit'),
                nb_critiques=Count('id', filter=Q(score_predit__gte=70)),
            )
            .order_by('-score_moyen')
        )
        return Response([
            {
                'zone': s['segment__zone'],
                'nb_segments': s['nb_segments'],
                'score_moyen': round(s['score_moyen'] or 0),
                'score_max': s['score_max'] or 0,
                'nb_critiques': s['nb_critiques'],
            }
            for s in stats
        ])
