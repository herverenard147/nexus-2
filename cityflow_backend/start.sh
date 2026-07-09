#!/bin/sh

echo "[CityFlow] Démarrage..."

# Attendre que la base soit prête (max 30s)
MAX=6
I=0
until python manage.py migrate --noinput 2>&1; do
  I=$((I+1))
  if [ "$I" -ge "$MAX" ]; then
    echo "[CityFlow] Base de données inaccessible après ${MAX} tentatives. Démarrage sans migration."
    break
  fi
  echo "[CityFlow] DB pas encore prête, nouvelle tentative dans 5s... ($I/$MAX)"
  sleep 5
done

# Seeding en arrière-plan si la base est vide (ne bloque pas le health check)
(
  SEGMENTS=$(python manage.py shell -c \
    "from mobility.models import RoadSegment; print(RoadSegment.objects.count())" 2>/dev/null) || SEGMENTS=""
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
