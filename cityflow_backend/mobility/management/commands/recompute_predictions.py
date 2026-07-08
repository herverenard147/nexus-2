import logging

from django.core.management.base import BaseCommand

from mobility.ml.predictor import predict_congestion
from mobility.models import Prediction, RoadSegment

logger = logging.getLogger('mobility')


class Command(BaseCommand):
    help = "Recalcule les prédictions pour tous les segments (à appeler toutes les 5 min)"

    def handle(self, *args, **options):
        segments = RoadSegment.objects.all()
        ok = 0
        errors = 0
        for seg in segments:
            try:
                result = predict_congestion(seg.id)
                Prediction.objects.create(
                    segment=seg,
                    score_predit=result['score'],
                    facteurs=result['facteurs'],
                    version_modele=result['version_modele'],
                )
                ok += 1
            except Exception as e:
                logger.error("Erreur prédiction segment %s : %s", seg.id, e)
                errors += 1
        self.stdout.write(self.style.SUCCESS(
            f"Prédictions recalculées : {ok} OK, {errors} erreurs."
        ))
