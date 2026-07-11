from django.urls import path
from .views import conseil_trajet

urlpatterns = [
    path('', conseil_trajet),
]
