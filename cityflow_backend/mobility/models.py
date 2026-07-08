from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class RoadSegment(models.Model):
    SOURCE_CHOICES = [('osm', 'OpenStreetMap'), ('manuel', 'Manuel')]

    nom = models.CharField(max_length=255)
    latitude = models.FloatField()
    longitude = models.FloatField()
    zone = models.CharField(max_length=100, db_index=True)
    zone_inondable = models.BooleanField(default=False)
    source_geometrie = models.CharField(max_length=10, choices=SOURCE_CHOICES, default='manuel')

    def __str__(self):
        return f"{self.nom} ({self.zone})"


class TrafficRecord(models.Model):
    SOURCE_CHOICES = [('simule', 'Simulé'), ('signalement', 'Signalement')]

    segment = models.ForeignKey(RoadSegment, on_delete=models.CASCADE, related_name='traffic_records')
    timestamp = models.DateTimeField()
    niveau_congestion = models.IntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='simule')

    class Meta:
        indexes = [models.Index(fields=['segment', 'timestamp'])]

    def __str__(self):
        return f"{self.segment} @ {self.timestamp}: {self.niveau_congestion}"


class Prediction(models.Model):
    segment = models.ForeignKey(RoadSegment, on_delete=models.CASCADE, related_name='predictions')
    horizon_min = models.IntegerField(default=15)
    score_predit = models.IntegerField(validators=[MinValueValidator(0), MaxValueValidator(100)])
    facteurs = models.JSONField(default=dict)
    version_modele = models.CharField(max_length=20, default='v1')
    timestamp_prediction = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp_prediction']

    def __str__(self):
        return f"Prédiction {self.segment} T+{self.horizon_min}min: {self.score_predit}"
