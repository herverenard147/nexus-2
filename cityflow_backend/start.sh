#!/bin/sh
set -e

echo "[CityFlow] Migration..."
python manage.py migrate --noinput

# Seeding en arrière-plan — ne bloque pas le health check Render
(
  SEGMENTS=$(python manage.py shell -c \
    "from mobility.models import RoadSegment; print(RoadSegment.objects.count())" 2>/dev/null)
  if [ "$SEGMENTS" = "0" ]; then
    echo "[CityFlow] Première installation — chargement des données demo..."
    python manage.py import_osm_segments --fichier /app/docs/data/grand_abidjan.geojson
    python manage.py seed_demo_data --users 100 --days 30 --seed 42
    python manage.py import_weather_history --fichier /app/docs/data/meteo_abidjan.json
    python manage.py seed_demo_reports --seed 42
    python manage.py recompute_predictions
    echo "[CityFlow] Données chargées !"
  else
    echo "[CityFlow] Données déjà présentes ($SEGMENTS segments). Skipping seed."
  fi
) &

echo "[CityFlow] Démarrage Gunicorn..."
exec gunicorn cityflow_backend.wsgi:application \
    --bind "0.0.0.0:${PORT:-8000}" \
    --workers 2 \
    --timeout 120
