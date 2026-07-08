from django.contrib import admin
from .models import Report


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ('type', 'gravite', 'statut', 'segment', 'user', 'nb_confirmations', 'created_at')
    list_filter = ('type', 'gravite', 'statut')
