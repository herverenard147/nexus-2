import mobility.ml.predictor as _pred_module
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from environment.models import WeatherEvent
from mobility.ml.predictor import predict_congestion
from mobility.ml.weights import (
    POIDS_METEO_FORTE, POIDS_METEO_MODEREE, POIDS_SIGNALEMENT, VERSION_MODELE,
)
from mobility.models import Prediction, RoadSegment, TrafficRecord
from reports.models import Report


def _make_segment(nom='Test', zone='Cocody', inondable=False):
    return RoadSegment.objects.create(
        nom=nom, latitude=5.3, longitude=-3.9,
        zone=zone, zone_inondable=inondable, source_geometrie='osm',
    )


def _make_user(username='awa', role='citoyen'):
    return User.objects.create_user(username=username, password='pass', role=role)


class PredictorTests(TestCase):
    def setUp(self):
        self.seg = _make_segment()

    def _add_history(self, segment, hour=8, congestion=60):
        ts = timezone.now().replace(hour=hour, minute=0, second=0, microsecond=0)
        TrafficRecord.objects.create(
            segment=segment, timestamp=ts,
            niveau_congestion=congestion, source='simule',
        )

    # ── Tests indépendants du chemin ML/fallback ──────────────────────────────

    def test_score_in_range(self):
        self._add_history(self.seg)
        result = predict_congestion(self.seg.id)
        self.assertIn('score', result)
        self.assertGreaterEqual(result['score'], 0)
        self.assertLessEqual(result['score'], 100)

    def test_version_modele_in_response(self):
        result = predict_congestion(self.seg.id)
        self.assertEqual(result['version_modele'], VERSION_MODELE)

    def test_raw_weights_not_in_facteurs(self):
        result = predict_congestion(self.seg.id)
        facteurs_str = str(result['facteurs'])
        for raw in [str(POIDS_METEO_FORTE), str(POIDS_METEO_MODEREE), str(POIDS_SIGNALEMENT)]:
            self.assertNotIn(raw, facteurs_str)

    def test_invalid_segment_raises(self):
        with self.assertRaises(ValueError):
            predict_congestion(99999)

    def test_invalid_horizon_raises(self):
        with self.assertRaises(ValueError):
            predict_congestion(self.seg.id, horizon_min=999)

    def test_weather_does_not_affect_non_inondable(self):
        """Même avec météo active, segment non inondable → effet_meteo='aucun'."""
        seg = _make_segment(zone='Plateau', inondable=False)
        self._add_history(seg, congestion=50)
        WeatherEvent.objects.create(
            zone='Plateau', type='pluie_forte',
            intensite=10.0, timestamp=timezone.now(),
        )
        result = predict_congestion(seg.id)
        self.assertEqual(result['facteurs']['effet_meteo'], 'aucun')

    # ── Tests du chemin FALLBACK (forcé via patch de _model) ─────────────────
    # Ces tests vérifient la logique de la formule pondérée : seuils de score,
    # multiplicateurs météo, bonus signalement. Le patch garantit qu'on teste
    # le fallback même si model.pkl est présent.

    def test_fallback_no_history_score_is_50(self):
        """Fallback sans historique → score=50, donnees_insuffisantes=True."""
        original = _pred_module._model
        _pred_module._model = None
        try:
            result = predict_congestion(self.seg.id)
            self.assertEqual(result['score'], 50)
            self.assertTrue(result['facteurs']['donnees_insuffisantes'])
            self.assertEqual(result['facteurs']['source_modele'], 'fallback')
        finally:
            _pred_module._model = original

    def test_fallback_weather_factor_increases_score(self):
        """Fallback : pluie forte sur segment inondable → score > score_base."""
        original = _pred_module._model
        _pred_module._model = None
        try:
            seg = _make_segment(zone='Yopougon', inondable=True)
            self._add_history(seg, congestion=50)
            WeatherEvent.objects.create(
                zone='Yopougon', type='pluie_forte',
                intensite=10.0, timestamp=timezone.now(),
            )
            result = predict_congestion(seg.id)
            self.assertGreater(result['score'], 50)
            self.assertEqual(result['facteurs']['effet_meteo'], 'fort')
            self.assertEqual(result['facteurs']['source_modele'], 'fallback')
        finally:
            _pred_module._model = original

    def test_fallback_active_report_increases_score(self):
        """Fallback : signalement actif → score augmente, effet_signalement='présent'."""
        original = _pred_module._model
        _pred_module._model = None
        try:
            self._add_history(self.seg, congestion=30)
            user = _make_user()
            Report.objects.create(
                user=user, segment=self.seg, type='accident',
                gravite='critique', statut='actif',
            )
            result = predict_congestion(self.seg.id)
            self.assertGreater(result['score'], 30)
            self.assertEqual(result['facteurs']['effet_signalement'], 'présent')
            self.assertEqual(result['facteurs']['source_modele'], 'fallback')
        finally:
            _pred_module._model = original

    def test_fallback_activated_when_model_absent(self):
        """Patch _model=None → source_modele='fallback' même si model.pkl existe."""
        original = _pred_module._model
        _pred_module._model = None
        try:
            self._add_history(self.seg, congestion=60)
            result = predict_congestion(self.seg.id)
            self.assertEqual(result['facteurs']['source_modele'], 'fallback')
        finally:
            _pred_module._model = original


class MLModelTests(TestCase):
    """Tests spécifiques au modèle ML — ignorés si model.pkl absent."""

    def setUp(self):
        self.seg = _make_segment()
        if _pred_module._model is None:
            self.skipTest('model.pkl absent — lancez : python manage.py train_model')

    def test_ml_score_in_range(self):
        """Modèle ML chargé → score dans [0, 100]."""
        result = predict_congestion(self.seg.id)
        self.assertEqual(result['facteurs']['source_modele'], 'ml')
        self.assertGreaterEqual(result['score'], 0)
        self.assertLessEqual(result['score'], 100)

    def test_ml_facteurs_explicatifs_presents(self):
        """ML : les clés d'explicabilité sont toujours renseignées."""
        result = predict_congestion(self.seg.id)
        for key in ('effet_meteo', 'effet_signalement', 'nb_signalements',
                    'source_modele', 'version_modele'):
            self.assertIn(key, result['facteurs'])

    def test_ml_weather_flag_set_on_inondable(self):
        """ML : effet_meteo renseigné correctement même si le score vient du modèle."""
        seg = _make_segment(zone='Yopougon', inondable=True)
        WeatherEvent.objects.create(
            zone='Yopougon', type='pluie_forte',
            intensite=10.0, timestamp=timezone.now(),
        )
        result = predict_congestion(seg.id)
        self.assertEqual(result['facteurs']['effet_meteo'], 'fort')
        self.assertEqual(result['facteurs']['source_modele'], 'ml')

    def test_ml_signalement_flag_set(self):
        """ML : effet_signalement renseigné correctement."""
        user = _make_user()
        Report.objects.create(
            user=user, segment=self.seg, type='accident',
            gravite='critique', statut='actif',
        )
        result = predict_congestion(self.seg.id)
        self.assertEqual(result['facteurs']['effet_signalement'], 'présent')
        self.assertEqual(result['facteurs']['nb_signalements'], 1)
        self.assertEqual(result['facteurs']['source_modele'], 'ml')


class RoadSegmentAPITests(APITestCase):
    def setUp(self):
        self.user = _make_user()
        self.client.force_authenticate(user=self.user)
        self.seg = _make_segment()

    def test_list_segments(self):
        res = self.client.get('/api/segments/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_filter_by_zone(self):
        _make_segment(nom='Autre', zone='Plateau')
        res = self.client.get('/api/segments/?zone=Cocody')
        self.assertTrue(all(r['zone'] == 'Cocody' for r in res.data))

    def test_segment_detail_404(self):
        res = self.client.get('/api/segments/99999/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)

    def test_history_endpoint(self):
        TrafficRecord.objects.create(
            segment=self.seg, timestamp=timezone.now(),
            niveau_congestion=50, source='simule',
        )
        res = self.client.get(f'/api/segments/{self.seg.id}/history/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(res.data), 1)

    def test_history_404_unknown_segment(self):
        res = self.client.get('/api/segments/99999/history/')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)


class RecomputePredictionsTests(TestCase):
    def test_continues_on_error(self):
        from mobility.management.commands.recompute_predictions import Command
        _make_segment(nom='Good')
        cmd = Command()
        cmd.stdout = open('/dev/null', 'w')
        cmd.style = type('S', (), {
            'SUCCESS': lambda self, x: x,
            'ERROR': lambda self, x: x,
        })()
        cmd.handle()
        self.assertEqual(Prediction.objects.count(), 1)
