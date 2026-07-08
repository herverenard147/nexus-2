from rest_framework import serializers
from .models import WeatherEvent


class WeatherEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = WeatherEvent
        fields = '__all__'
