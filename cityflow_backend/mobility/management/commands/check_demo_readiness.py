from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from environment.models import WeatherEvent
from mobility.models import Prediction, RoadSegment
from reports.models import Report


class Command(BaseCommand):
    help = "Vérifie que tout est prêt pour la démo (sans rien modifier)"

    def handle(self, *args, **options):
        ok = "✓"
        ko = "✕"
        results = []

        # 1. Segments OSM
        nb_osm = RoadSegment.objects.filter(source_geometrie='osm').count()
        results.append((nb_osm > 0, f"Segments OSM importés : {nb_osm}"))

        # 2. WeatherEvent réels
        nb_weather = WeatherEvent.objects.filter(source='historique_reel').count()
        results.append((nb_weather > 0, f"WeatherEvent historique réel : {nb_weather}"))

        # 3. Prédictions récentes (< 15 min)
        cutoff = timezone.now() - timedelta(minutes=15)
        nb_recent = Prediction.objects.filter(timestamp_prediction__gte=cutoff).count()
        nb_segments = RoadSegment.objects.count()
        results.append((
            nb_recent >= nb_segments and nb_segments > 0,
            f"Prédictions récentes (< 15min) : {nb_recent}/{nb_segments} segments"
        ))

        # 4. Signalements de seed
        nb_reports = Report.objects.count()
        results.append((nb_reports > 0, f"Signalements de seed : {nb_reports}"))

        self.stdout.write("\n=== CHECK DEMO READINESS ===")
        all_ok = True
        for passed, msg in results:
            icon = ok if passed else ko
            self.stdout.write(f"  {icon}  {msg}")
            if not passed:
                all_ok = False

        if all_ok:
            self.stdout.write(self.style.SUCCESS("\nTout est prêt pour la démo ✓"))
        else:
            self.stdout.write(self.style.ERROR("\nCertains points sont en échec — voir ci-dessus."))
