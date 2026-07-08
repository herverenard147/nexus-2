from django.urls import path
from .views import WeatherCurrentView, WeatherAlertsView

urlpatterns = [
    path('current/', WeatherCurrentView.as_view(), name='weather-current'),
    path('alerts/', WeatherAlertsView.as_view(), name='weather-alerts'),
]
