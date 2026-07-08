from django.urls import reverse
from rest_framework.test import APITestCase
from rest_framework import status
from .models import User


class AuthTests(APITestCase):
    def test_register_citoyen(self):
        res = self.client.post(reverse('auth-register'), {
            'username': 'awa', 'email': 'awa@cityflow.ci',
            'password': 'Abidjan2025!', 'role': 'citoyen',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['role'], 'citoyen')

    def test_register_autorite(self):
        res = self.client.post(reverse('auth-register'), {
            'username': 'admin', 'email': 'admin@cityflow.ci',
            'password': 'Abidjan2025!', 'role': 'autorite',
        })
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        self.assertEqual(res.data['role'], 'autorite')

    def test_register_invalid_role(self):
        res = self.client.post(reverse('auth-register'), {
            'username': 'bad', 'email': 'bad@cityflow.ci',
            'password': 'Abidjan2025!', 'role': 'superadmin',
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_valid(self):
        User.objects.create_user(username='awa2', password='Abidjan2025!', role='citoyen')
        res = self.client.post(reverse('auth-login'), {
            'username': 'awa2', 'password': 'Abidjan2025!',
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('access', res.data)

    def test_login_invalid(self):
        res = self.client.post(reverse('auth-login'), {
            'username': 'nobody', 'password': 'wrong',
        })
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_password_too_short_rejected(self):
        res = self.client.post(reverse('auth-register'), {
            'username': 'short', 'email': 'short@cityflow.ci',
            'password': '1234', 'role': 'citoyen',
        })
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)

    def test_protected_endpoint_requires_auth(self):
        res = self.client.get('/api/segments/')
        self.assertEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_register_login_are_public(self):
        res = self.client.post(reverse('auth-register'), {
            'username': 'pub', 'email': 'pub@c.ci',
            'password': 'Abidjan2025!', 'role': 'citoyen',
        })
        self.assertNotEqual(res.status_code, status.HTTP_401_UNAUTHORIZED)
