from django.conf import settings
from django.db import models
from mobility.models import RoadSegment

GRAVITE_PAR_TYPE = {
    'accident': 'critique',
    'route_barree': 'critique',
    'vehicule_en_panne': 'moyen',
    'nid_de_poule': 'faible',
}


def classify_severity(type_incident):
    return GRAVITE_PAR_TYPE.get(type_incident, 'faible')


class Report(models.Model):
    TYPE_CHOICES = [
        ('accident', 'Accident'),
        ('nid_de_poule', 'Nid de poule'),
        ('route_barree', 'Route barrée'),
        ('vehicule_en_panne', 'Véhicule en panne'),
    ]
    GRAVITE_CHOICES = [('faible', 'Faible'), ('moyen', 'Moyen'), ('critique', 'Critique')]
    STATUT_CHOICES = [('actif', 'Actif'), ('fusionne', 'Fusionné'), ('resolu', 'Résolu')]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reports')
    segment = models.ForeignKey(RoadSegment, on_delete=models.CASCADE, related_name='reports')
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    gravite = models.CharField(max_length=10, choices=GRAVITE_CHOICES)
    statut = models.CharField(max_length=10, choices=STATUT_CHOICES, default='actif')
    nb_confirmations = models.IntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Report {self.type} {self.segment} ({self.statut})"
