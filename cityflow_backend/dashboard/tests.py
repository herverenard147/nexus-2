from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from mobility.models import Prediction, RoadSegment
from reports.models import Report


def _seg(nom='S', zone='Cocody', inondable=False):
    return RoadSegment.objects.create(
        nom=nom, latitude=5.3, longitude=-3.9,
        zone=zone, zone_inondable=inondable, source_geometrie='osm',
    )


def _pred(seg, score=50):
    return Prediction.objects.create(
        segment=seg, score_predit=score,
        facteurs={'effet_meteo': 'aucun'}, version_modele='v1',
    )


def _auth_client(client, role='autorite'):
    user = User.objects.create_user(username=f'u_{role}', password='pass', role=role)
    client.force_authenticate(user=user)
    return user


class DashboardPermissionsTests(APITestCase):
    def test_citoyen_forbidden(self):
        _auth_client(self.client, role='citoyen')
        for url in ['/api/dashboard/critical-zones/', '/api/dashboard/stats/', '/api/dashboard/export/']:
            res = self.client.get(url)
            self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN, msg=url)

    def test_autorite_allowed(self):
        _auth_client(self.client, role='autorite')
        for url in ['/api/dashboard/critical-zones/', '/api/dashboard/stats/', '/api/dashboard/export/']:
            res = self.client.get(url)
            self.assertNotEqual(res.status_code, status.HTTP_403_FORBIDDEN, msg=url)


class CriticalZonesTests(APITestCase):
    def setUp(self):
        _auth_client(self.client)

    def test_composite_score_formula(self):
        """score = 0.5×congestion + 0.3×(nb_reports×10) + 0.2×(100 si météo)"""
        seg = _seg()
        _pred(seg, score=80)
        user = User.objects.create_user(username='c', password='p', role='citoyen')
        Report.objects.create(
            user=user, segment=seg, type='accident', gravite='critique', statut='actif'
        )
        res = self.client.get('/api/dashboard/critical-zones/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        zone = next((z for z in res.data if z['segment_id'] == seg.id), None)
        self.assertIsNotNone(zone)
        expected = round(0.5 * 80 + 0.3 * 1 * 10 + 0.2 * 0, 2)
        self.assertAlmostEqual(zone['score_composite'], expected, places=1)

    def test_returns_at_most_5(self):
        for i in range(7):
            s = _seg(nom=f'S{i}', zone=f'Zone{i}')
            _pred(s, score=i * 10)
        res = self.client.get('/api/dashboard/critical-zones/')
        self.assertLessEqual(len(res.data), 5)


class DashboardStatsTests(APITestCase):
    def setUp(self):
        _auth_client(self.client)

    def test_stats_counts(self):
        seg = _seg()
        user = User.objects.create_user(username='c2', password='p', role='citoyen')
        Report.objects.create(
            user=user, segment=seg, type='accident', gravite='critique', statut='actif'
        )
        res = self.client.get('/api/dashboard/stats/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['nb_signalements_actifs'], 1)


class DashboardExportTests(APITestCase):
    def setUp(self):
        _auth_client(self.client)

    def test_export_returns_csv(self):
        seg = _seg()
        _pred(seg)
        res = self.client.get('/api/dashboard/export/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('text/csv', res['Content-Type'])
        content = res.content.decode()
        self.assertIn('segment_id', content)
        self.assertIn('score_composite', content)
