from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Report
from .permissions import IsAutorite
from .serializers import ReportSerializer, ReportCreateSerializer, ReportPatchSerializer
from .throttles import ReportCreateThrottle


class ReportListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return ReportCreateSerializer
        return ReportSerializer

    def get_throttles(self):
        if self.request.method == 'POST':
            return [ReportCreateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        qs = Report.objects.all()
        segment = self.request.query_params.get('segment')
        statut = self.request.query_params.get('statut')
        if segment:
            qs = qs.filter(segment_id=segment)
        if statut:
            qs = qs.filter(statut=statut)
        return qs

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        report = serializer.save()
        return Response(ReportSerializer(report).data, status=status.HTTP_201_CREATED)


class ReportDetailView(generics.RetrieveUpdateAPIView):
    queryset = Report.objects.all()

    def get_serializer_class(self):
        if self.request.method == 'PATCH':
            return ReportPatchSerializer
        return ReportSerializer

    def get_permissions(self):
        if self.request.method == 'PATCH':
            return [IsAutorite()]
        return [IsAuthenticated()]
