from django.contrib import admin
from .models import RoadSegment, TrafficRecord, Prediction


@admin.register(RoadSegment)
class RoadSegmentAdmin(admin.ModelAdmin):
    list_display = ('nom', 'zone', 'zone_inondable', 'source_geometrie')
    list_filter = ('zone_inondable', 'source_geometrie', 'zone')
    search_fields = ('nom', 'zone')


@admin.register(TrafficRecord)
class TrafficRecordAdmin(admin.ModelAdmin):
    list_display = ('segment', 'timestamp', 'niveau_congestion', 'source')
    list_filter = ('source',)


@admin.register(Prediction)
class PredictionAdmin(admin.ModelAdmin):
    list_display = ('segment', 'score_predit', 'version_modele', 'timestamp_prediction')
    list_filter = ('version_modele',)
