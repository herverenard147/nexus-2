from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APITestCase
from rest_framework import status

from accounts.models import User
from environment.models import WeatherEvent
from mobility.ml.predictor import predict_congestion
from mobility.ml.weights import VERSION_MODELE, POIDS_METEO_FORTE, POIDS_METEO_MODEREE, POIDS_SIGNALEMENT
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
        from datetime import datetime
        ts = timezone.now().replace(hour=hour, minute=0, second=0, microsecond=0)
        TrafficRecord.objects.create(
            segment=segment, timestamp=ts,
            niveau_congestion=congestion, source='simule',
        )

    def test_score_in_range(self):
        self._add_history(self.seg)
        result = predict_congestion(self.seg.id)
        self.assertIn('score', result)
        self.assertGreaterEqual(result['score'], 0)
        self.assertLessEqual(result['score'], 100)

    def test_no_history_returns_fallback(self):
        result = predict_congestion(self.seg.id)
        self.assertTrue(result['facteurs'].get('donnees_insuffisantes'))

    def test_weather_factor_on_inondable_segment(self):
        seg = _make_segment(zone='Yopougon', inondable=True)
        self._add_history(seg, congestion=50)
        WeatherEvent.objects.create(
            zone='Yopougon', type='pluie_forte',
            intensite=10.0, timestamp=timezone.now(),
        )
        result = predict_congestion(seg.id)
        self.assertGreater(result['score'], 50)
        self.assertEqual(result['facteurs']['effet_meteo'], 'fort')

    def test_weather_does_not_affect_non_inondable(self):
        seg = _make_segment(zone='Plateau', inondable=False)
        self._add_history(seg, congestion=50)
        WeatherEvent.objects.create(
            zone='Plateau', type='pluie_forte',
            intensite=10.0, timestamp=timezone.now(),
        )
        result = predict_congestion(seg.id)
        self.assertEqual(result['facteurs']['effet_meteo'], 'aucun')

    def test_active_report_increases_score(self):
        self._add_history(self.seg, congestion=30)
        user = _make_user()
        Report.objects.create(
            user=user, segment=self.seg, type='accident',
            gravite='critique', statut='actif',
        )
        result = predict_congestion(self.seg.id)
        self.assertGreater(result['score'], 30)
        self.assertEqual(result['facteurs']['effet_signalement'], 'présent')

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
        # Segment valide → 1 prédiction créée, pas d'exception globale
        cmd = Command()
        cmd.stdout = open('/dev/null', 'w')
        cmd.style = type('S', (), {
            'SUCCESS': lambda self, x: x,
            'ERROR': lambda self, x: x,
        })()
        cmd.handle()
        self.assertEqual(Prediction.objects.count(), 1)
