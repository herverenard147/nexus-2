from django.contrib import admin
from .models import WeatherEvent


@admin.register(WeatherEvent)
class WeatherEventAdmin(admin.ModelAdmin):
    list_display = ('zone', 'type', 'intensite', 'timestamp', 'source')
    list_filter = ('type', 'source', 'zone')
