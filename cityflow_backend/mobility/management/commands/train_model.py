"""
Entraîne un GradientBoostingRegressor sur les TrafficRecords existants.

Features (6) :
  heure, jour_semaine, segment_id, zone_inondable, intensite_meteo, nb_signalements_actifs

  Note : intensite_meteo et nb_signalements_actifs valent 0 dans les données
  historiques (non stockés sur les TrafficRecord). Le modèle apprend les
  patterns temporels et géographiques ; les deux features de contexte
  enrichissent la prédiction à l'inférence.

Cible : niveau_congestion (entier [0, 100])

Sauvegarde : mobility/ml/model.pkl

Usage :
    python manage.py train_model
"""
import logging
import os

from django.core.management.base import BaseCommand

logger = logging.getLogger('mobility')

# Chemin absolu vers model.pkl (même dossier que predictor.py)
_ML_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'ml')
)
MODEL_PATH = os.path.join(_ML_DIR, 'model.pkl')


class Command(BaseCommand):
    help = (
        'Entraîne un GradientBoostingRegressor sur les TrafficRecords '
        'et sauvegarde le modèle dans mobility/ml/model.pkl.'
    )

    def handle(self, *args, **options):
        try:
            import joblib
            import numpy as np
            from sklearn.ensemble import GradientBoostingRegressor
            from sklearn.metrics import mean_absolute_error
            from sklearn.model_selection import train_test_split
        except ImportError as exc:
            self.stderr.write(f'Dépendance manquante : {exc}. Installez scikit-learn et joblib.')
            return

        from mobility.models import TrafficRecord

        self.stdout.write('\n=== train_model ===\n')
        self.stdout.write('Extraction des TrafficRecords (source=simule)...')

        qs = (
            TrafficRecord.objects
            .filter(source='simule')
            .select_related('segment')
            .values(
                'niveau_congestion',
                'timestamp',
                'segment__id',
                'segment__zone_inondable',
            )
        )

        total = qs.count()
        self.stdout.write(f'  {total} enregistrements trouvés.')

        if total < 100:
            self.stderr.write(
                'Données insuffisantes (< 100 lignes). '
                'Lancez d\'abord : python manage.py seed_traffic_minimal --seed 42'
            )
            return

        # Construction de la matrice de features
        X, y = [], []
        for rec in qs.iterator(chunk_size=5000):
            ts = rec['timestamp']
            X.append([
                float(ts.hour),                            # heure (0-23)
                float(ts.weekday()),                       # jour_semaine (0=lundi)
                float(rec['segment__id']),                 # segment_id (numérique)
                float(int(rec['segment__zone_inondable'])),# zone_inondable (0/1)
                0.0,                                       # intensite_meteo (non stocké en historique)
                0.0,                                       # nb_signalements_actifs (idem)
            ])
            y.append(float(rec['niveau_congestion']))

        X = np.array(X, dtype=np.float32)
        y = np.array(y, dtype=np.float32)
        self.stdout.write(f'  Matrice features : {X.shape}  (6 features × {len(y)} échantillons)')

        # Split 80/20
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        self.stdout.write(f'  Train : {len(X_train)}, Test : {len(X_test)}')

        # Entraînement
        self.stdout.write('Entraînement GradientBoostingRegressor...')
        model = GradientBoostingRegressor(
            n_estimators=200,
            learning_rate=0.1,
            max_depth=5,
            subsample=0.8,
            random_state=42,
        )
        model.fit(X_train, y_train)

        # Évaluation
        y_pred = model.predict(X_test)
        mae = mean_absolute_error(y_test, y_pred)
        self.stdout.write(self.style.SUCCESS(f'\nMAE (test set) : {mae:.2f} pts / 100'))
        logger.info(
            'train_model: MAE=%.2f pts, n_train=%d, n_test=%d',
            mae, len(X_train), len(X_test),
        )

        # Feature importances
        names = ['heure', 'jour_semaine', 'segment_id', 'zone_inondable',
                 'intensite_meteo', 'nb_signalements']
        self.stdout.write('Feature importances :')
        for name, imp in zip(names, model.feature_importances_):
            self.stdout.write(f'  {name:<25} {imp:.4f}')

        # Sauvegarde
        os.makedirs(_ML_DIR, exist_ok=True)
        joblib.dump(model, MODEL_PATH)
        self.stdout.write(self.style.SUCCESS(f'\nModèle sauvegardé : {MODEL_PATH}'))
