FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Code backend + start.sh (start.sh est dans cityflow_backend/)
COPY cityflow_backend/ .

# Données de démo incluses dans l'image (GeoJSON OSM + météo Open-Meteo)
COPY docs/data/ /app/docs/data/

RUN python manage.py collectstatic --noinput || true
RUN chmod +x /app/start.sh

EXPOSE 8000

CMD ["/app/start.sh"]
