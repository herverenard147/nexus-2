from rest_framework.routers import DefaultRouter
from django.urls import path, include
from .views import RoadSegmentViewSet, PredictionViewSet

router = DefaultRouter()
router.register('segments', RoadSegmentViewSet, basename='segment')
router.register('predictions', PredictionViewSet, basename='prediction')

urlpatterns = [path('', include(router.urls))]
