# CityFlow AI — Documentation de lancement

## Prérequis

| Outil | Version |
|---|---|
| Python | 3.12 |
| pip | dernière version |
| Flutter | 3.x (`flutter --version`) |
| Git | — |
| Docker + Docker Compose | (optionnel, pour le mode conteneur) |

---

## Option 1 — Développement local (SQLite, le plus rapide)

### 1. Cloner le dépôt

```bash
git clone git@github.com:herverenard147/nexus-2.git cityflow
cd cityflow
```

### 2. Créer l'environnement Python

```bash
python3 -m venv .venv
source .venv/bin/activate        # Linux/Mac
# .venv\Scripts\activate         # Windows

pip install -r requirements.txt
```

### 3. Initialiser la base de données

```bash
cd cityflow_backend
python manage.py migrate
```

### 4. Charger les données de démo (ordre obligatoire)

```bash
# Segments routiers réels OSM (Grand Abidjan, 4206 routes)
python manage.py import_osm_segments --fichier ../docs/data/grand_abidjan.geojson

# Historique trafic simulé — 3 millions de lignes, ~10 min sur SQLite
python manage.py seed_demo_data --users 100 --days 30 --seed 42

# Météo réelle Open-Meteo (720 heures)
python manage.py import_weather_history --fichier ../docs/data/meteo_abidjan.json

# Signalements de démo (8 incidents pour le dashboard)
python manage.py seed_demo_reports --seed 42

# Calcul initial des prédictions T+15 min
python manage.py recompute_predictions

# Vérification avant démo
python manage.py check_demo_readiness
```

> Les fichiers de données (`grand_abidjan.geojson`, `meteo_abidjan.json`) sont déjà inclus dans `docs/data/` — aucun téléchargement nécessaire.

### 5. Lancer le backend

```bash
# Depuis cityflow_backend/
python manage.py runserver           # port 8000
python manage.py runserver 8001      # si le port 8000 est occupé
```

API disponible sur `http://localhost:8000/api/`

### 6. Lancer l'app Flutter

```bash
cd cityflow_app
flutter pub get
flutter run                          # mobile (émulateur ou appareil connecté)
flutter run -d chrome                # web
```

> Si le backend tourne sur un port différent de 8000, modifier `baseUrl` dans `cityflow_app/lib/services/api_service.dart`.

---

## Option 2 — Docker (PostgreSQL réel)

### 1. Créer le fichier `.env`

```bash
cp .env.example .env
# Éditer .env : SECRET_KEY, ALLOWED_HOSTS, CORS_ALLOWED_ORIGINS
```

### 2. Démarrer les conteneurs

```bash
docker compose up --build
```

Le conteneur `web` lance `migrate` automatiquement au démarrage.

### 3. Charger les données (dans le conteneur)

```bash
docker compose exec web python manage.py import_osm_segments --fichier /app/docs/data/grand_abidjan.geojson
docker compose exec web python manage.py seed_demo_data --users 100 --days 30 --seed 42
docker compose exec web python manage.py import_weather_history --fichier /app/docs/data/meteo_abidjan.json
docker compose exec web python manage.py seed_demo_reports --seed 42
docker compose exec web python manage.py recompute_predictions
```

API disponible sur `http://localhost:8000/api/`

---

## Endpoints API principaux

| Méthode | URL | Description |
|---|---|---|
| `POST` | `/api/auth/register/` | Créer un compte |
| `POST` | `/api/auth/login/` | Obtenir token JWT |
| `POST` | `/api/auth/refresh/` | Rafraîchir le token |
| `GET` | `/api/segments/` | Liste des segments (`?zone=Cocody`) |
| `GET` | `/api/segments/{id}/history/` | Historique trafic d'un segment |
| `GET` | `/api/predictions/` | Dernière prédiction par segment |
| `GET` | `/api/weather/alerts/` | Segments en alerte météo |
| `POST` | `/api/reports/` | Créer un signalement *(auth requise)* |
| `GET` | `/api/dashboard/critical-zones/` | Top 5 zones critiques *(autorité)* |
| `GET` | `/api/dashboard/stats/` | Statistiques globales *(autorité)* |
| `GET` | `/api/dashboard/export/` | Export CSV *(autorité)* |

Tous les endpoints protégés nécessitent le header :

```
Authorization: Bearer <access_token>
```

---

## Tests

```bash
# Django — 42 tests
cd cityflow_backend
python manage.py test --verbosity=2

# Linter
flake8 .

# Flutter — 10 tests
cd cityflow_app
flutter test
```

---

## Créer un compte autorité (dashboard)

```bash
cd cityflow_backend
python manage.py shell -c "
from accounts.models import User
User.objects.create_superuser('admin', 'admin@cityflow.ci', 'admin123', role='autorite')
"
```

Se connecter via `POST /api/auth/login/` avec `{"username": "admin", "password": "admin123"}`.

---

## Vérification pré-démo (à lancer la veille)

```bash
cd cityflow_backend
python manage.py check_demo_readiness
```

Résultat attendu :

```
✓  Segments OSM importés : 4206
✓  WeatherEvent historique réel : 720
✓  Prédictions récentes (< 15min) : 4206/4206 segments
✓  Signalements de seed : 8
Tout est prêt pour la démo ✓
```
