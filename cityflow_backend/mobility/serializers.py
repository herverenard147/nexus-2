from rest_framework import serializers
from .models import RoadSegment, TrafficRecord, Prediction


class RoadSegmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = RoadSegment
        fields = '__all__'


class TrafficRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrafficRecord
        fields = '__all__'


class PredictionSerializer(serializers.ModelSerializer):
    segment_nom = serializers.CharField(source='segment.nom', read_only=True)
    segment_zone = serializers.CharField(source='segment.zone', read_only=True)

    class Meta:
        model = Prediction
        fields = '__all__'
