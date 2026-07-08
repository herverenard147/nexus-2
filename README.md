# CityFlow AI

Système de prédiction de congestion pour Abidjan (Côte d'Ivoire) — MVP Vibeathon.

Backend Django REST Framework + App Flutter (mobile citoyens + dashboard web autorités).

---

## Installation locale

### Prérequis

- Python 3.12, pip
- PostgreSQL 16 (ou SQLite pour le dev)
- Flutter 3.x
- Git

### Backend

```bash
cd cityflow_backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r ../requirements.txt

# Dev avec SQLite (aucune config nécessaire)
python manage.py migrate
python manage.py runserver
```

Pour PostgreSQL, créer une base puis exporter la variable :

```bash
export DATABASE_URL=postgres://cityflow:motdepasse@localhost:5432/cityflow_db
python manage.py migrate
```

### App Flutter

```bash
cd cityflow_app
flutter pub get
flutter run          # mobile
flutter run -d chrome  # web
```

---

## Pipeline de données (ordre obligatoire)

> Les fichiers d'import (GeoJSON OSM, historique météo) doivent être présents **avant** de lancer ces commandes. Ils ne font pas d'appel réseau live — télécharger au préalable.

```bash
# 1. Segments routiers réels (export Overpass/HDX, Grand Abidjan)
python manage.py import_osm_segments --fichier /chemin/grand_abidjan.geojson

# 2. Historique de trafic simulé (30 jours, reproductible)
python manage.py seed_demo_data --users 100 --days 30 --seed 42

# 3. Météo historique réelle (export Open-Meteo ou équivalent)
python manage.py import_weather_history --fichier /chemin/meteo_abidjan.csv

# 4. Signalements de seed (distincts du signalement live en démo)
python manage.py seed_demo_reports --seed 42

# 5. Calcul initial des prédictions
python manage.py recompute_predictions
```

**Provenance des fichiers d'import :**
- `grand_abidjan.geojson` : export Overpass Turbo, tags `highway=motorway|trunk|primary|secondary|tertiary`, emprise Grand Abidjan (5.0–5.6°N, −4.3–−3.7°E).
- `meteo_abidjan.csv` : export horaire Open-Meteo (champ `precipitation` en mm/h) sur la période des 30 jours simulés.
- `seed_demo_reports` crée des signalements de démo **distincts** du signalement fait en direct pendant la présentation jury — ne pas les confondre lors de la répétition.

---

## Tests

```bash
# Django
cd cityflow_backend
python manage.py test --verbosity=2

# Flutter
cd cityflow_app
flutter test
```

---

## Docker (dev / staging)

```bash
cp .env.example .env   # puis éditer les valeurs
docker compose up --build
```

Le service `web` lance automatiquement `migrate` au démarrage.

Lancer ensuite le pipeline de données dans le conteneur :

```bash
docker compose exec web python manage.py import_osm_segments --fichier /chemin/fichier.geojson
docker compose exec web python manage.py seed_demo_data --seed 42
docker compose exec web python manage.py import_weather_history --fichier /chemin/meteo.csv
docker compose exec web python manage.py seed_demo_reports --seed 42
docker compose exec web python manage.py recompute_predictions
```

---

## Déploiement Render / Railway

| Variable | Valeur |
|---|---|
| `SECRET_KEY` | clé secrète aléatoire (générer avec `python -c "import secrets; print(secrets.token_hex(50))"`) |
| `DEBUG` | `False` |
| `ALLOWED_HOSTS` | `votre-app.onrender.com` |
| `DATABASE_URL` | fourni automatiquement par Render/Railway |
| `CORS_ALLOWED_ORIGINS` | URL Flutter Web déployée |
| `SECURE_SSL_REDIRECT` | `True` |

**Commande de build :** `pip install -r requirements.txt`

**Commande de démarrage :** `gunicorn cityflow_backend.wsgi:application --bind 0.0.0.0:$PORT --workers 2`

**Ordre de lancement sur l'environnement de production :**

```
import_osm_segments → seed_demo_data --seed 42 → import_weather_history → seed_demo_reports --seed 42 → recompute_predictions
```

Utiliser **le même `--seed 42`** à chaque fois pour garantir la reproductibilité des données de démo.

---

## Plan de rollback

En cas d'échec de déploiement le jour de la démo :

```bash
# Revenir au tag précédent (à créer avant chaque déploiement)
git checkout v0.1.0
# Redéployer depuis ce tag sur Render/Railway
```

Règle : **tester le déploiement la veille**, jamais le jour J. Garder le tag Git précédent déployable.

---

## Vérification avant démo

```bash
python manage.py check_demo_readiness
```

Vérifie (sans rien modifier) :
- ✓ Segments OSM importés
- ✓ WeatherEvent historique réel présents
- ✓ Prédictions récentes (< 15 min) pour tous les segments
- ✓ Signalements de seed présents (dashboard non vide)

---

## Scénario de démonstration jury (5 min)

Voir `docs/CityFlow_AI_Prompts_Realisation.md` — section "Bonus — Préparation de la présentation jury".

---

## Licence données

Les segments routiers sont issus d'**OpenStreetMap** — © OpenStreetMap contributors, licence ODbL.
Attribution visible dans l'app citoyenne (bas de l'écran principal).
