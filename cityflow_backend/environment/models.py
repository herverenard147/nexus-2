from django.db import models


class WeatherEvent(models.Model):
    TYPE_CHOICES = [
        ('normal', 'Normal'),
        ('pluie_moderee', 'Pluie modérée'),
        ('pluie_forte', 'Pluie forte'),
    ]
    SOURCE_CHOICES = [('historique_reel', 'Historique réel'), ('manuel', 'Manuel')]

    zone = models.CharField(max_length=100)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='normal')
    intensite = models.FloatField()
    timestamp = models.DateTimeField()
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='manuel')

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"Météo {self.zone} {self.type} @ {self.timestamp}"


def get_active_weather(zone):
    return WeatherEvent.objects.filter(zone=zone).order_by('-timestamp').first()
