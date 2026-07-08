from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from environment.models import WeatherEvent, get_active_weather
from mobility.models import RoadSegment


def _user():
    return User.objects.create_user(username='awa', password='pass', role='citoyen')


class WeatherModelTests(APITestCase):
    def test_get_active_weather_returns_latest(self):
        WeatherEvent.objects.create(
            zone='Cocody', type='pluie_forte', intensite=10.0,
            timestamp=timezone.now() - timezone.timedelta(hours=2),
        )
        latest = WeatherEvent.objects.create(
            zone='Cocody', type='pluie_moderee', intensite=5.0,
            timestamp=timezone.now(),
        )
        result = get_active_weather('Cocody')
        self.assertEqual(result.id, latest.id)

    def test_get_active_weather_no_event_returns_none(self):
        self.assertIsNone(get_active_weather('ZoneInconnue'))


class WeatherAlertsAPITests(APITestCase):
    def setUp(self):
        self.client.force_authenticate(user=_user())

    def test_alerts_only_inondable_with_active_event(self):
        seg_inond = RoadSegment.objects.create(
            nom='Risk', latitude=5.3, longitude=-3.9,
            zone='Yopougon', zone_inondable=True, source_geometrie='osm',
        )
        seg_normal = RoadSegment.objects.create(
            nom='Safe', latitude=5.3, longitude=-3.9,
            zone='Plateau', zone_inondable=False, source_geometrie='osm',
        )
        WeatherEvent.objects.create(
            zone='Yopougon', type='pluie_forte', intensite=10.0,
            timestamp=timezone.now(),
        )
        res = self.client.get('/api/weather/alerts/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        ids = [r['id'] for r in res.data]
        self.assertIn(seg_inond.id, ids)
        self.assertNotIn(seg_normal.id, ids)
