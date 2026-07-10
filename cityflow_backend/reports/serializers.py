from rest_framework import serializers
from .models import Report, classify_severity


class ReportSerializer(serializers.ModelSerializer):
    segment_nom = serializers.CharField(source='segment.nom', read_only=True)

    class Meta:
        model = Report
        fields = '__all__'
        read_only_fields = ('gravite', 'statut', 'nb_confirmations', 'created_at', 'user')


class ReportPatchSerializer(serializers.ModelSerializer):
    """Autorité uniquement : permet de changer le statut d'un signalement."""

    class Meta:
        model = Report
        fields = ('statut',)


class ReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = ('segment', 'type')

    def create(self, validated_data):
        from django.utils import timezone
        from datetime import timedelta
        user = self.context['request'].user
        segment = validated_data['segment']
        type_incident = validated_data['type']
        cutoff = timezone.now() - timedelta(minutes=5)
        existing = Report.objects.filter(
            segment=segment, type=type_incident, statut='actif', created_at__gte=cutoff
        ).first()
        if existing:
            existing.nb_confirmations += 1
            existing.save(update_fields=['nb_confirmations'])
            return existing
        return Report.objects.create(
            user=user,
            segment=segment,
            type=type_incident,
            gravite=classify_severity(type_incident),
        )
