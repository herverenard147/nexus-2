import logging

from django.utils import timezone

from .weights import (
    POIDS_METEO_FORTE, POIDS_METEO_MODEREE,
    POIDS_SIGNALEMENT, VERSION_MODELE,
)

logger = logging.getLogger('mobility')


def predict_congestion(segment_id, horizon_min=15, timestamp=None):
    """
    Prédit le niveau de congestion pour un segment à horizon_min minutes.

    Formule :
      score_base = moyenne historique (même heure + jour de semaine)
      × facteur_meteo (si zone_inondable et WeatherEvent actif)
      + bonus_signalement (si reports actifs)
    Résultat plafonné à [0, 100].

    timestamp : optionnel (défaut timezone.now()) pour la testabilité unitaire.
    """
    from environment.models import get_active_weather
    from mobility.models import RoadSegment, TrafficRecord
    from reports.models import Report

    if timestamp is None:
        timestamp = timezone.now()

    # Validate inputs
    try:
        segment = RoadSegment.objects.get(pk=segment_id)
    except RoadSegment.DoesNotExist:
        raise ValueError(f"Segment {segment_id} introuvable")

    if not (1 <= horizon_min <= 120):
        raise ValueError(f"horizon_min doit être entre 1 et 120, reçu : {horizon_min}")

    facteurs = {'version_modele': VERSION_MODELE}

    # 1. Moyenne historique (même heure et jour de semaine)
    heure = timestamp.hour
    jour_semaine = timestamp.weekday()
    historique = TrafficRecord.objects.filter(
        segment=segment,
        source='simule',
        timestamp__hour=heure,
        timestamp__week_day=(jour_semaine + 1) % 7 + 1,  # Django: 1=Sunday
    )
    count = historique.count()
    if count == 0:
        logger.warning("Historique insuffisant pour segment %s heure %s jour %s", segment_id, heure, jour_semaine)
        facteurs['donnees_insuffisantes'] = True
        score = 50
    else:
        facteurs['donnees_insuffisantes'] = False
        values = list(historique.values_list('niveau_congestion', flat=True))
        score = sum(values) / count
        facteurs['historique_moyen'] = round(score)

    # 2. Facteur météo (uniquement si zone_inondable)
    facteurs['effet_meteo'] = 'aucun'
    facteurs['delta_meteo_pts'] = 0
    if segment.zone_inondable:
        weather = get_active_weather(segment.zone)
        if weather and weather.type != 'normal':
            score_avant_meteo = score
            if weather.type == 'pluie_forte':
                score *= POIDS_METEO_FORTE
                facteurs['effet_meteo'] = 'fort'
            elif weather.type == 'pluie_moderee':
                score *= POIDS_METEO_MODEREE
                facteurs['effet_meteo'] = 'modéré'
            facteurs['delta_meteo_pts'] = round(score - score_avant_meteo)

    # 3. Bonus signalements actifs
    nb_reports = Report.objects.filter(segment=segment, statut='actif').count()
    facteurs['nb_signalements'] = nb_reports
    if nb_reports:
        score += nb_reports * POIDS_SIGNALEMENT
        facteurs['effet_signalement'] = 'présent'
        facteurs['delta_signalement_pts'] = round(nb_reports * POIDS_SIGNALEMENT)
    else:
        facteurs['effet_signalement'] = 'aucun'
        facteurs['delta_signalement_pts'] = 0

    score = max(0, min(100, int(round(score))))

    return {
        'score': score,
        'facteurs': facteurs,
        'version_modele': VERSION_MODELE,
    }
