# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CityFlow AI — a traffic/mobility prediction system for Abidjan, Côte d'Ivoire, built as a vibeathon MVP. Reference spec: `CityFlow_AI_CDCFT_Vibeathon_1.docx`. Implementation roadmap (step-by-step prompts to execute in order): `CityFlow_AI_Prompts_Realisation.md`.

## Stack

- **Backend**: Python 3.12, Django + DRF + `djangorestframework-simplejwt` + `django-cors-headers`, PostgreSQL
- **Frontend**: Flutter (mobile for citizens, web for authorities dashboard)
- **Directory layout**: `cityflow_backend/` (Django project), `cityflow_app/` (Flutter), `docs/`

## Commands

### Backend (run from `cityflow_backend/`)
```bash
python manage.py runserver
python manage.py test                                    # run all tests
python manage.py test accounts.tests.TestClassName       # run a single test
python manage.py makemigrations && python manage.py migrate
```

### Data pipeline (run in this order after first deploy)
```bash
python manage.py import_osm_segments --fichier <geojson>   # must run first
python manage.py seed_demo_data --users 100 --days 30 --seed 42
python manage.py import_weather_history --fichier <csv/json>
python manage.py seed_demo_reports --seed 42
python manage.py recompute_predictions
python manage.py check_demo_readiness                   # run the day before demo
```

### Flutter (run from `cityflow_app/`)
```bash
flutter run
flutter test
```

### CI/CD
```bash
flake8 cityflow_backend/           # linting
python manage.py test              # Django suite
flutter test                       # Flutter suite
docker compose up --build          # local integration test
```

## Django App Architecture

Five apps under `cityflow_backend/`:

| App | Responsibility |
|---|---|
| `accounts` | Custom `User` (extends `AbstractUser`) with `role` (`citoyen`/`autorite`) and `zone`; JWT auth endpoints |
| `mobility` | `RoadSegment`, `TrafficRecord`, `Prediction`; ML predictor at `mobility/ml/predictor.py`; management commands for OSM import and seeding |
| `environment` | `WeatherEvent`; `get_active_weather(zone)` utility; weather history import |
| `reports` | `Report` with deduplication logic (same type + segment within 5 min → increment `nb_confirmations`); citizen throttling (5 reports / 10 min) |
| `dashboard` | Authority-only computed views: composite score, stats, CSV export |

## Key Invariants

**Data sourcing — never mix real and synthetic silently:**
- `RoadSegment.source_geometrie`: `'osm'` (imported) or `'manuel'`
- `TrafficRecord.source` / `WeatherEvent.source`: `'simule'`, `'signalement'`, `'historique_reel'`, or `'manuel'`
- `seed_demo_data` must fail with a clear error if no `source_geometrie='osm'` segments exist (never fall back silently)

**Reproducibility:** `seed_demo_data` and `seed_demo_reports` must accept `--seed` and produce bit-identical output on re-runs with the same value. Never break this.

**Performance:** Use `bulk_create`/`bulk_update` for all data imports and seed commands — the OSM network can exceed several hundred segments; a 30-day history generates hundreds of thousands of rows.

**AI explainability:** `predict_congestion()` always returns `{'score': int, 'facteurs': {...}, 'version_modele': VERSION_MODELE}`. Factors must use qualitative labels (not raw weight constants from `weights.py`).

**Timezone:** `TIME_ZONE = "Africa/Abidjan"` and `USE_TZ = True` in `settings.py`. Peak-hour logic (7h–9h, 17h–19h) depends on local time — a wrong timezone silently corrupts predictions.

**Accessibility:** Every risk level (congestion, weather) must use a dual encoding: colour + icon or text label (for colour-blind users).

**Attribution:** The string `"© OpenStreetMap contributors"` must be visible in the Flutter app (ODbL licence requirement).

## ML Predictor (`mobility/ml/`)

- `weights.py` — constants: `POIDS_METEO_FORTE`, `POIDS_METEO_MODEREE`, `POIDS_EVENEMENT`, `POIDS_SIGNALEMENT`, `VERSION_MODELE`
- `predictor.py` — `predict_congestion(segment_id, horizon_min=15, timestamp=None)`:
  1. Historical average for segment × hour × weekday
  2. Weather multiplier if segment is `zone_inondable` and active `WeatherEvent` exists
  3. Active-report bonus
  4. Result clamped to [0, 100]
  - `timestamp` defaults to `timezone.now()` so the function is unit-testable
  - Logs a warning via `logging.getLogger('mobility')` when history is insufficient, in addition to setting `facteurs['donnees_insuffisantes']`

## Security Requirements (step 4.19)

- Login throttle: `AnonRateThrottle` 5 attempts / 5 min per IP
- Reports throttle: `UserRateThrottle` 5 requests / 10 min
- Prediction read throttle on `GET /api/predictions/` and `GET /api/segments/*/history/`
- Production settings via env vars: `DEBUG=False`, `ALLOWED_HOSTS`, `SECURE_SSL_REDIRECT`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`
- `CORS_ALLOWED_ORIGINS` restricted to Flutter Web URL — never `CORS_ALLOW_ALL_ORIGINS` in production
- `predict_congestion` inputs validated; invalid `segment_id` or out-of-range `horizon_min` → 404/400, never 500
- Model weights must never appear verbatim in API responses

## Implementation Order

Follow `CityFlow_AI_Prompts_Realisation.md` strictly — steps have real dependencies:

```
4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6 → 4.7 → 4.8 → 4.9 → 4.10
→ 4.11 → 4.12 → 4.13–4.17 (Flutter, run from cityflow_app/)
→ (4.18 bonus, separate branch) → 4.19
→ Step 5 (tests) → Step 6 (CI/CD) → Step 7 (deploy) → Step 8 (release)
```

One commit per completed step. Run `python manage.py test` after every test block (step 5), not just at the end. Use `/clear` between unrelated prompts to keep context clean.
