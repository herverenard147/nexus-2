"""
Prédicateur de congestion CityFlow.

Stratégie :
  1. Modèle GradientBoosting (ML) — chargé une fois au démarrage depuis model.pkl
  2. Formule pondérée (fallback) — si model.pkl absent ou erreur ML

Les facteurs explicatifs (effet_meteo, effet_signalement, etc.) sont toujours
renseignés dans les deux chemins, pour ne pas casser l'API d'explicabilité.
"""
import logging
import os

from django.utils import timezone

from .weights import (
    POIDS_METEO_FORTE, POIDS_METEO_MODEREE,
    POIDS_SIGNALEMENT, VERSION_MODELE,
)

logger = logging.getLogger('mobility')

_MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'model.pkl')

# Chargement unique au démarrage du processus
_model = None
try:
    import joblib
    _model = joblib.load(_MODEL_PATH)
    logger.info('predictor: modèle ML chargé (%s)', _MODEL_PATH)
except FileNotFoundError:
    logger.warning('predictor: model.pkl absent — mode fallback (formule pondérée)')
except Exception as _exc:
    logger.error('predictor: échec chargement modèle — fallback. %s', _exc)


def predict_congestion(segment_id, horizon_min=15, timestamp=None):
    """
    Prédit le niveau de congestion pour un segment à horizon_min minutes.

    Retourne :
      {
        'score': int [0, 100],
        'facteurs': {
          'version_modele': str,
          'source_modele': 'ml' | 'fallback',
          'effet_meteo': 'aucun' | 'modéré' | 'fort',
          'delta_meteo_pts': int,
          'nb_signalements': int,
          'effet_signalement': 'aucun' | 'présent',
          'delta_signalement_pts': int,
          'donnees_insuffisantes': bool,   # fallback uniquement
          'historique_moyen': int,         # fallback uniquement
        },
        'version_modele': str,
      }

    timestamp : optionnel (défaut timezone.now()) pour la testabilité unitaire.
    """
    from environment.models import get_active_weather
    from mobility.models import RoadSegment, TrafficRecord
    from reports.models import Report

    if timestamp is None:
        timestamp = timezone.now()

    # Validation des entrées
    try:
        segment = RoadSegment.objects.get(pk=segment_id)
    except RoadSegment.DoesNotExist:
        raise ValueError(f'Segment {segment_id} introuvable')

    if not (1 <= horizon_min <= 120):
        raise ValueError(f'horizon_min doit être entre 1 et 120, reçu : {horizon_min}')

    facteurs = {'version_modele': VERSION_MODELE}

    heure = timestamp.hour
    jour_semaine = timestamp.weekday()

    # ── Contexte météo (commun ML + fallback) ────────────────────────────────
    intensite_meteo = 0          # 0=normal, 1=moderée, 2=forte
    facteurs['effet_meteo'] = 'aucun'
    facteurs['delta_meteo_pts'] = 0
    weather = None
    if segment.zone_inondable:
        weather = get_active_weather(segment.zone)
        if weather and weather.type != 'normal':
            if weather.type == 'pluie_forte':
                intensite_meteo = 2
                facteurs['effet_meteo'] = 'fort'
            elif weather.type == 'pluie_moderee':
                intensite_meteo = 1
                facteurs['effet_meteo'] = 'modéré'

    # ── Signalements actifs (commun ML + fallback) ────────────────────────────
    nb_reports = Report.objects.filter(segment=segment, statut='actif').count()
    facteurs['nb_signalements'] = nb_reports
    facteurs['effet_signalement'] = 'présent' if nb_reports > 0 else 'aucun'
    facteurs['delta_signalement_pts'] = 0

    # ══════════════════════════════════════════════════════════════════════════
    # CHEMIN 1 — Modèle ML
    # ══════════════════════════════════════════════════════════════════════════
    if _model is not None:
        try:
            import numpy as np
            features = np.array([[
                float(heure),
                float(jour_semaine),
                float(segment.pk),
                float(int(segment.zone_inondable)),
                float(intensite_meteo),
                float(nb_reports),
            ]], dtype=np.float32)
            raw = float(_model.predict(features)[0])
            score = max(0, min(100, int(round(raw))))
            facteurs['source_modele'] = 'ml'
            facteurs['donnees_insuffisantes'] = False
            return {
                'score': score,
                'facteurs': facteurs,
                'version_modele': VERSION_MODELE,
            }
        except Exception as exc:
            logger.error('predictor: erreur lors de la prédiction ML — repli formule. %s', exc)

    # ══════════════════════════════════════════════════════════════════════════
    # CHEMIN 2 — Formule pondérée (fallback)
    # ══════════════════════════════════════════════════════════════════════════
    facteurs['source_modele'] = 'fallback'

    historique = TrafficRecord.objects.filter(
        segment=segment,
        source='simule',
        timestamp__hour=heure,
        timestamp__week_day=(jour_semaine + 1) % 7 + 1,  # Django: 1=Sunday
    )
    count = historique.count()
    if count == 0:
        logger.warning(
            'predictor(fallback): historique insuffisant — segment=%s heure=%s jour=%s',
            segment_id, heure, jour_semaine,
        )
        facteurs['donnees_insuffisantes'] = True
        score = 50
    else:
        facteurs['donnees_insuffisantes'] = False
        values = list(historique.values_list('niveau_congestion', flat=True))
        score = sum(values) / count
        facteurs['historique_moyen'] = round(score)

    # Facteur météo
    if intensite_meteo == 2:
        score_avant = score
        score *= POIDS_METEO_FORTE
        facteurs['delta_meteo_pts'] = round(score - score_avant)
    elif intensite_meteo == 1:
        score_avant = score
        score *= POIDS_METEO_MODEREE
        facteurs['delta_meteo_pts'] = round(score - score_avant)

    # Bonus signalements
    if nb_reports:
        bonus = nb_reports * POIDS_SIGNALEMENT
        score += bonus
        facteurs['delta_signalement_pts'] = round(bonus)

    score = max(0, min(100, int(round(score))))
    return {
        'score': score,
        'facteurs': facteurs,
        'version_modele': VERSION_MODELE,
    }
