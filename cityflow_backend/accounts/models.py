from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_CHOICES = [('citoyen', 'Citoyen'), ('autorite', 'Autorité')]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='citoyen')
    zone = models.CharField(max_length=100, blank=True)
