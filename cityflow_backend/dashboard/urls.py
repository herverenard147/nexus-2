from django.urls import path
from .views import CriticalZonesView, DashboardStatsView, DashboardExportView

urlpatterns = [
    path('critical-zones/', CriticalZonesView.as_view(), name='dashboard-critical-zones'),
    path('stats/', DashboardStatsView.as_view(), name='dashboard-stats'),
    path('export/', DashboardExportView.as_view(), name='dashboard-export'),
]
