from django.urls import path
from .views import ReportListCreateView, ReportDetailView

urlpatterns = [
    path('', ReportListCreateView.as_view(), name='report-list'),
    path('<int:pk>/', ReportDetailView.as_view(), name='report-detail'),
]
