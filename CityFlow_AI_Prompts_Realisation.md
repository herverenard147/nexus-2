# CityFlow AI — Feuille de route de prompts (étape 4 à 8 + présentation jury)

Comment utiliser ce document : copie chaque prompt un par un dans ton assistant IA (Claude Code ou autre), **relis et comprends le résultat avant de passer au suivant**. Ne saute pas d'étape même si un prompt te semble simple — l'ordre respecte les dépendances réelles entre les briques du projet.

---

## Étape 4 — Développement assisté par IA

### 4.1 — Setup du projet Django

> Crée un projet Django nommé `cityflow_backend` avec les apps suivantes : `accounts`, `mobility`, `environment`, `reports`, `dashboard`. Installe et configure `djangorestframework`, `djangorestframework-simplejwt`, et `django-cors-headers`. Ajoute ces apps dans `INSTALLED_APPS`. Ne génère pas encore de modèles, juste la structure et la configuration de base.

### 4.2 — Authentification et rôles (`accounts`)

> Dans l'app `accounts`, crée un modèle `User` qui étend `AbstractUser` avec un champ `role` (choix : `citoyen` ou `autorite`) et un champ `zone` (CharField, optionnel). Configure `AUTH_USER_MODEL`. Ajoute les serializers et vues DRF pour `/api/auth/register/`, `/api/auth/login/` et `/api/auth/refresh/` avec `djangorestframework-simplejwt`. Permissions publiques sur register/login.

### 4.3 — Modèles de mobilité (`mobility`)

> Dans l'app `mobility`, crée deux modèles :
> - `RoadSegment` : nom (CharField), latitude (FloatField), longitude (FloatField), zone (CharField), zone_inondable (BooleanField, default=False)
> - `TrafficRecord` : segment (ForeignKey vers RoadSegment), timestamp (DateTimeField), niveau_congestion (IntegerField, 0-100), source (CharField, choix : `simule` ou `signalement`)
>
> Ajoute un index sur `zone` pour RoadSegment et sur `(segment, timestamp)` pour TrafficRecord. Génère les migrations.

### 4.4 — Génération des données simulées

> Crée une management command Django `seed_demo_data` dans `mobility/management/commands/`. Elle doit :
> 1. Créer 10 utilisateurs fictifs (rôle `citoyen`), chacun avec un profil de trajet type (domicile-travail matin/soir, école, marché)
> 2. Créer 15 segments de route représentatifs d'Abidjan (ex : Boulevard Latrille, Autoroute du Nord, Pont HKB...), avec `zone_inondable=True` pour environ 30% d'entre eux
> 3. Générer un historique de 30 jours de TrafficRecord par segment et par créneau horaire, avec des pics réalistes aux heures de pointe (7h-9h, 17h-19h)
>
> Ajoute des arguments `--users` et `--days` pour paramétrer les volumes.

### 4.5 — Module environnemental (`environment`)

> Dans l'app `environment`, crée un modèle `WeatherEvent` : zone (CharField), type (choix : `normal`, `pluie_moderee`, `pluie_forte`), intensite (FloatField), timestamp (DateTimeField). Ajoute une fonction utilitaire `get_active_weather(zone)` qui retourne l'événement météo actif le plus récent pour une zone donnée.

### 4.6 — Module IA : prédiction de congestion

> Crée `mobility/ml/weights.py` avec les constantes : `POIDS_METEO_FORTE = 1.3`, `POIDS_METEO_MODEREE = 1.15`, `POIDS_EVENEMENT = 10`, `POIDS_SIGNALEMENT = 5`.
>
> Puis crée `mobility/ml/predictor.py` avec une fonction `predict_congestion(segment_id, horizon_min=15, timestamp=None)` qui :
> 1. Récupère la moyenne historique de congestion pour ce segment à cette heure et ce jour de semaine (TrafficRecord source=`simule`)
> 2. Applique le facteur météo si le segment est `zone_inondable` et qu'un WeatherEvent actif existe pour sa zone
> 3. Ajoute un bonus si des signalements actifs existent sur ce segment
> 4. Retourne `{'score': int (0-100), 'facteurs': {...}}`
>
> Ajoute des docstrings claires expliquant la formule. Le paramètre `timestamp` doit être optionnel (défaut `timezone.now()`) pour que la fonction soit testable unitairement.

### 4.7 — Endpoints segments, prédictions, météo

> Crée le modèle `Prediction` dans `mobility/models.py` : segment (FK), horizon_min (IntegerField, default=15), score_predit (IntegerField), facteurs (JSONField), timestamp_prediction (DateTimeField, auto_now_add=True).
>
> Puis crée les serializers et ViewSets DRF pour :
> - `GET /api/segments/` (liste, filtrable par zone) et `GET /api/segments/<id>/`
> - `GET /api/segments/<id>/history/` (historique TrafficRecord)
> - `GET /api/predictions/` (dernière prédiction de chaque segment)
> - `GET /api/predictions/<segment_id>/` (prédiction détaillée avec facteurs)
> - `GET /api/weather/current/` et `GET /api/weather/alerts/` (segments zone_inondable avec WeatherEvent actif)

### 4.8 — Job périodique de recalcul

> Crée une management command `recompute_predictions` qui parcourt tous les RoadSegment, appelle `predict_congestion` pour chacun, et enregistre le résultat dans un objet `Prediction`. Cette commande sera appelée toutes les 5 minutes via une tâche planifiée de l'hébergeur — ne code pas de scheduler, juste la commande.

### 4.9 — Signalements citoyens (`reports`)

> Dans l'app `reports`, crée un modèle `Report` : user (FK), segment (FK), type (choix : `accident`, `nid_de_poule`, `route_barree`, `vehicule_en_panne`), gravite (choix : `faible`, `moyen`, `critique`), statut (choix : `actif`, `fusionne`, `resolu`, default=`actif`), nb_confirmations (IntegerField, default=1), created_at (auto_now_add).
>
> Dans la logique de création (`POST /api/reports/`), implémente le dédoublonnage :
> 1. Cherche un Report du même type, même segment, statut=`actif`, créé il y a moins de 5 minutes
> 2. Si trouvé : incrémente `nb_confirmations` et retourne ce report existant
> 3. Sinon : crée le nouveau Report, avec `gravite` déterminée par `classify_severity(type)` (accident/route_barree → critique, vehicule_en_panne → moyen, nid_de_poule → faible)
>
> Ajoute aussi `GET /api/reports/` (filtrable) et `PATCH /api/reports/<id>/` (réservé au rôle `autorite`).

### 4.10 — Dashboard autorités (`dashboard`)

> Dans l'app `dashboard`, crée une vue DRF (calcul à la volée, pas de modèle) pour :
> - `GET /api/dashboard/critical-zones/` : score composite = (0.5 × dernière congestion prédite) + (0.3 × nb_signalements_actifs × 10) + (0.2 × 100 si alerte météo active sinon 0) ; retourne les 5 segments les plus critiques
> - `GET /api/dashboard/stats/` : signalements actifs, segments en alerte météo, temps de trajet moyen simulé
> - `GET /api/dashboard/export/` : export CSV de critical-zones
>
> Réserve ces 3 endpoints au rôle `autorite` via une permission DRF personnalisée `IsAutorite`.

### 4.11 — App Flutter citoyens : structure

> Crée la structure d'un projet Flutter `cityflow_app` avec `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`. Crée `ApiService` dans `lib/services/api_service.dart` : appels HTTP vers le backend Django (base URL configurable), gestion du token JWT en mémoire.

### 4.12 — Écran principal (carte + prédiction)

> Crée `HomeScreen` : liste des segments avec leur score de congestion prédit (couleur verte/jaune/rouge selon le score), via `GET /api/predictions/`. Ajoute un état de chargement et un état d'erreur.

### 4.13 — Écran détail segment + signalement

> Crée `SegmentDetailScreen` : score prédit, facteurs de la prédiction affichés lisiblement, bouton pour signaler un incident.
>
> Crée le widget `ReportFormSheet` (bottom sheet) : choix du type d'incident, envoi `POST /api/reports/`, confirmation visuelle après envoi.

### 4.14 — Bandeau alerte météo

> Ajoute un bandeau d'alerte en haut de `HomeScreen` si `GET /api/weather/alerts/` retourne au moins un segment à risque, avec le nom des segments concernés.

### 4.15 — Dashboard autorités

> Si le temps le permet : crée `AuthorityDashboardScreen` (Flutter Web) affichant le top 5 des zones critiques et les stats globales. Sinon : enregistre `RoadSegment`, `Report`, `Prediction` dans `admin.py` avec des `list_display`/`list_filter` pertinents pour un usage rapide par une autorité.

---

## Étape 5 — Tests

> Écris des tests unitaires (Django TestCase) pour `predict_congestion` : le score reste dans [0,100] ; le facteur météo augmente le score sur un segment zone_inondable avec WeatherEvent actif ; un segment non zone_inondable n'est jamais affecté par la météo.

> Écris des tests d'intégration DRF (APITestCase) pour `POST /api/reports/` : vérifie qu'un second signalement identique dans les 5 minutes est fusionné (nb_confirmations incrémenté, pas de nouvel objet créé).

> Écris un test d'intégration pour `GET /api/dashboard/critical-zones/` : vérifie que l'accès est refusé (403) pour un utilisateur de rôle `citoyen`.

> Relis les critères d'acceptation définis en étape 1 (voir le CDCFT) et vérifie un par un qu'ils sont couverts par au moins un test automatique ou une vérification manuelle documentée.

---

## Étape 6 — CI/CD & revue de code

> Crée `.github/workflows/ci.yml` qui, à chaque push et pull request : installe les dépendances Python, lance `python manage.py test`, lance `flake8` sur le code Django. Le job doit échouer si l'un des deux échoue.

> Fais une auto-revue à froid de mon code Django généré : relis chaque `views.py` et signale les incohérences de nommage, le code dupliqué, et les endpoints sans gestion d'erreur.

---

## Étape 7 — Déploiement

> Crée un `Dockerfile` pour le backend Django (Python 3.12, gunicorn) et un `docker-compose.yml` incluant Django + PostgreSQL. Ajoute un `.env.example` listant les variables nécessaires (SECRET_KEY, DATABASE_URL, DEBUG).

> Prépare les instructions de déploiement sur Render (ou Railway) : variables d'environnement, commande de build, commande de démarrage (gunicorn), et comment lancer `seed_demo_data` une fois en production.

> Décris un plan de rollback simple : comment revenir à la version précédente en cas d'échec de déploiement le jour de la démo (garder le tag Git précédent déployable, tester la veille et pas le jour J).

---

## Étape 8 — Release & versioning

> Génère un `CHANGELOG.md` pour la version v0.1.0 : fonctionnalités livrées (prédiction T+15min, alertes météo, signalement citoyen, dashboard autorités) et limitations connues (données simulées, modèle statistique simple, 10 utilisateurs fictifs).

> Génère un `README.md` complet : présentation, installation locale (backend + app Flutter), comment lancer `seed_demo_data`, comment lancer les tests, lien vers le scénario de démonstration jury.

---

## Bonus — Préparation de la présentation jury

> Aide-moi à rédiger un script de démonstration de 5 minutes suivant le scénario Awa (Cocody → Plateau) :
> - Introduction du problème (30s)
> - Démonstration de la prédiction T+15min (1 min)
> - Démonstration de l'alerte météo/inondation (1 min)
> - Démonstration du signalement citoyen (1 min)
> - Démonstration du dashboard autorités (1 min)
> - Conclusion sur l'impact et la feuille de route (30s)

---

## Rappel — checklist avant de soumettre (voir bootcamp)

- [ ] Je comprends chaque ligne de code générée, pas juste "ça tourne"
- [ ] Le module IA reste explicable (facteurs visibles à chaque prédiction)
- [ ] Les 10 utilisateurs fictifs et l'historique simulé sont cohérents
- [ ] La CI passe au vert avant la démo
- [ ] Le déploiement a été testé la veille, pas le jour J
- [ ] La version livrée a un numéro et un changelog
