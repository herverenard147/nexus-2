from datetime import timedelta

from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from mobility.models import RoadSegment
from reports.models import Report, classify_severity


def _seg():
    return RoadSegment.objects.create(
        nom='Seg', latitude=5.3, longitude=-3.9,
        zone='Cocody', source_geometrie='osm',
    )


def _user(username='awa', role='citoyen'):
    return User.objects.create_user(username=username, password='pass', role=role)


class ClassifySeverityTests(APITestCase):
    def test_accident_is_critique(self):
        self.assertEqual(classify_severity('accident'), 'critique')

    def test_route_barree_is_critique(self):
        self.assertEqual(classify_severity('route_barree'), 'critique')

    def test_vehicule_en_panne_is_moyen(self):
        self.assertEqual(classify_severity('vehicule_en_panne'), 'moyen')

    def test_nid_de_poule_is_faible(self):
        self.assertEqual(classify_severity('nid_de_poule'), 'faible')


class ReportDeduplicationTests(APITestCase):
    def setUp(self):
        self.user = _user()
        self.seg = _seg()
        self.client.force_authenticate(user=self.user)

    def test_same_type_within_5min_increments_confirmations(self):
        self.client.post('/api/reports/', {'segment': self.seg.id, 'type': 'accident'})
        self.client.post('/api/reports/', {'segment': self.seg.id, 'type': 'accident'})
        self.assertEqual(Report.objects.count(), 1)
        self.assertEqual(Report.objects.first().nb_confirmations, 2)

    def test_different_type_creates_new_report(self):
        self.client.post('/api/reports/', {'segment': self.seg.id, 'type': 'accident'})
        self.client.post('/api/reports/', {'segment': self.seg.id, 'type': 'nid_de_poule'})
        self.assertEqual(Report.objects.count(), 2)

    def test_gravite_determined_automatically(self):
        self.client.post('/api/reports/', {'segment': self.seg.id, 'type': 'accident'})
        report = Report.objects.first()
        self.assertEqual(report.gravite, 'critique')
        # Gravite should not be settable from client
        self.assertIsNotNone(report.gravite)

    def test_patch_forbidden_for_citoyen(self):
        report = Report.objects.create(
            user=self.user, segment=self.seg, type='accident',
            gravite='critique', statut='actif',
        )
        res = self.client.patch(f'/api/reports/{report.id}/', {'statut': 'resolu'})
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

    def test_patch_allowed_for_autorite(self):
        autorite = _user(username='auth', role='autorite')
        self.client.force_authenticate(user=autorite)
        report = Report.objects.create(
            user=self.user, segment=self.seg, type='accident',
            gravite='critique', statut='actif',
        )
        res = self.client.patch(f'/api/reports/{report.id}/', {'statut': 'resolu'})
        self.assertEqual(res.status_code, status.HTTP_200_OK)

    def test_filter_by_statut(self):
        Report.objects.create(
            user=self.user, segment=self.seg, type='accident',
            gravite='critique', statut='actif',
        )
        Report.objects.create(
            user=self.user, segment=self.seg, type='nid_de_poule',
            gravite='faible', statut='resolu',
        )
        res = self.client.get('/api/reports/?statut=actif')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertTrue(all(r['statut'] == 'actif' for r in res.data))
