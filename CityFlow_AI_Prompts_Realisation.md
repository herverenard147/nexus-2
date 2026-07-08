# CityFlow AI — Feuille de route de prompts (étape 4 à 8 + présentation jury)

Comment utiliser ce document : copie chaque prompt un par un dans ton assistant IA (Claude Code ou autre), **relis et comprends le résultat avant de passer au suivant**. Ne saute pas d'étape même si un prompt te semble simple — l'ordre respecte les dépendances réelles entre les briques du projet.

---

## Étape 4 — Développement assisté par IA

### 4.1 — Setup du projet Django

> Crée un projet Django nommé `cityflow_backend` avec les apps suivantes : `accounts`, `mobility`, `environment`, `reports`, `dashboard`. Installe et configure `djangorestframework`, `djangorestframework-simplejwt`, et `django-cors-headers`. Ajoute ces apps dans `INSTALLED_APPS`. Fixe explicitement `TIME_ZONE = "Africa/Abidjan"` et `USE_TZ = True` dans `settings.py` (la logique de prédiction dépend de l'heure locale — un mauvais fuseau fausserait silencieusement les heures de pointe). Configure un `LOGGING` de base (handler console, niveau INFO sur les apps du projet, WARNING sur le reste) pour pouvoir diagnostiquer un problème pendant la démo. Ne génère pas encore de modèles, juste la structure et la configuration de base.

### 4.2 — Authentification et rôles (`accounts`)

> Dans l'app `accounts`, crée un modèle `User` qui étend `AbstractUser` avec un champ `role` (choix : `citoyen` ou `autorite`) et un champ `zone` (CharField, optionnel). Configure `AUTH_USER_MODEL`. Ajoute les serializers et vues DRF pour `/api/auth/register/`, `/api/auth/login/` et `/api/auth/refresh/` avec `djangorestframework-simplejwt`. Permissions publiques sur register/login.

### 4.3 — Modèles de mobilité (`mobility`)

> Dans l'app `mobility`, crée deux modèles :
> - `RoadSegment` : nom (CharField), latitude (FloatField), longitude (FloatField), zone (CharField), zone_inondable (BooleanField, default=False), source_geometrie (CharField, choix : `osm` ou `manuel`, default=`manuel`)
> - `TrafficRecord` : segment (ForeignKey vers RoadSegment), timestamp (DateTimeField), niveau_congestion (IntegerField, 0-100), source (CharField, choix : `simule` ou `signalement`)
>
> Ajoute un index sur `zone` pour RoadSegment et sur `(segment, timestamp)` pour TrafficRecord. Génère les migrations.

### 4.4 — Import des segments réels depuis OpenStreetMap

> Crée une management command Django `import_osm_segments` dans `mobility/management/commands/`. Elle doit :
> 1. Lire un fichier GeoJSON exporté depuis Overpass (fourni en argument `--fichier`, généré au préalable — pas d'appel réseau live depuis la commande, pour rester reproductible en démo), filtré par tags `highway=motorway|trunk|primary|secondary|tertiary` sur l'emprise géographique complète du Grand Abidjan (pas de liste manuelle de noms de rues) — objectif : couvrir l'ensemble des communes (Abobo, Adjamé, Attécoubé, Cocody, Koumassi, Marcory, Plateau, Port-Bouët, Treichville, Yopougon, etc.), pas seulement quelques axes emblématiques triés sur le volet. Boulevard Latrille, Autoroute du Nord et Pont Houphouët-Boigny restent des exemples notables inclus dans cet ensemble, mais l'import ne s'arrête pas à eux.
> 2. Pour chaque route du fichier, créer ou mettre à jour un `RoadSegment` avec les vraies coordonnées GPS, le vrai nom (ou un nom composite généré si absent dans OSM, ex. `"Route sans nom - <commune>"`), la zone/commune déduite des tags OSM, et `source_geometrie='osm'`. Utilise des insertions en masse (`bulk_create`/`bulk_update`) plutôt qu'un `create()` par route, le volume attendu (probablement plusieurs centaines de segments sur l'agglomération complète) rendrait une boucle naïve trop lente.
> 3. Détermine `zone_inondable` non plus segment par segment manuellement, mais à partir d'une **liste documentée de zones/communes à risque d'inondation connu** (ex. certains secteurs de Yopougon, Abobo, le corridor de l'Autoroute du Nord et du Boulevard Latrille — à documenter en commentaire avec la source de cette information), appliquée à tous les segments dont la zone correspond. Cette approche reste gérable à l'échelle de centaines de segments, contrairement à un marquage manuel route par route.
>
> Ajoute un argument `--dry-run` qui affiche un résumé (nombre de segments par commune, nombre marqués `zone_inondable`) sans écrire en base. Documente dans le docstring la requête Overpass exacte utilisée (ou l'export HDX) et son emprise géographique, pour traçabilité.

### 4.5 — Génération des données simulées (trafic et utilisateurs)

> Crée une management command Django `seed_demo_data` dans `mobility/management/commands/`, à lancer après `import_osm_segments`. Elle doit :
> 1. Créer des utilisateurs fictifs (rôle `citoyen`), **100 par défaut** (paramétrable via `--users`), générés de façon réaliste plutôt qu'avec des données arbitraires :
>    - noms tirés d'un petit pool de prénoms et noms de famille courants en Côte d'Ivoire (ex. Kouassi, Yao, Koffi, Aka, Konan, N'Guessan, Traoré, Ouattara, Bamba, Coulibaly pour les noms de famille ; Awa, Adjoua, Fatou, Mariam, Aya, Kouamé, Mamadou, Ibrahim, Serge, Yves pour les prénoms), combinés aléatoirement (avec le `--seed` de la commande) pour éviter les doublons trop évidents
>    - profils de trajet répartis de façon pondérée plutôt qu'un profil unique par utilisateur : ~70% domicile-travail (matin/soir), ~15% trajet école, ~15% trajet marché
>    - zone domicile et zone travail choisies parmi des paires réalistes reflétant les flux de navette réels d'Abidjan (communes résidentielles denses comme Yopougon, Abobo, Koumassi, Port-Bouët → zones d'emploi comme Plateau, Cocody, Marcory), plutôt qu'un tirage uniforme sur toutes les zones
> 2. Réutiliser les `RoadSegment` déjà importés depuis OSM (ne pas recréer de segments avec des coordonnées inventées) ; si aucun segment `source_geometrie='osm'` n'existe, lever une erreur claire invitant à lancer `import_osm_segments` d'abord plutôt que de générer un fallback silencieux
> 3. Générer un historique de 30 jours de TrafficRecord par segment et par créneau horaire. Le trafic reste nécessairement simulé (aucune API de congestion historique publique n'existe pour Abidjan), mais la simulation doit être calibrée, pas purement aléatoire :
>    - courbe de base en cloche autour des heures de pointe documentées localement (7h-9h, 17h-19h), avec un niveau de fond plus bas le week-end
>    - bruit gaussien modéré autour de la courbe de base, pas un tirage uniforme sur [0,100]
>    - `--seed` obligatoire (valeur par défaut fixe) pour que le jeu de données soit reproductible à l'identique entre deux exécutions, notamment pour la démo jury
>    - **génération en masse** (`bulk_create` par lots plutôt qu'un `create()` par enregistrement) : avec une couverture complète du réseau routier (étape 4.4), le nombre de segments passe de quelques dizaines à potentiellement plusieurs centaines — un historique de 30 jours par segment et par créneau horaire peut représenter plusieurs centaines de milliers de lignes, à insérer efficacement plutôt que ligne par ligne
>
> Ajoute des arguments `--users` (défaut 100), `--days` et `--seed` pour paramétrer les volumes. Vérifie que la génération reste rapide (quelques minutes maximum) malgré la couverture complète du réseau ; si ce n'est pas le cas, réduis `--days` par défaut ou parallélise par lot de segments plutôt que d'accepter une commande de seed qui prend une heure. Ajoute des assertions de cohérence en fin de commande (niveau_congestion toujours dans [0,100], proportion réelle de segments zone_inondable affichée en résumé) plutôt que de faire confiance à la probabilité de génération seule.

### 4.6 — Import de l'historique météo réel

> Crée une management command Django `import_weather_history` dans l'app `environment`. Elle doit :
> 1. Lire un export local (CSV/JSON, fourni en argument `--fichier`) de l'historique de pluviométrie réel sur Abidjan pour la période couverte par les 30 jours de TrafficRecord simulés (à récupérer au préalable via une API météo historique publique, ex. type Open-Meteo — l'appel réseau se fait en amont, hors de cette commande, pour garder la commande reproductible sans dépendance réseau le jour de la démo)
> 2. Créer les `WeatherEvent` correspondants (zone, type `normal`/`pluie_moderee`/`pluie_forte` déduit de seuils d'intensité documentés en commentaire, intensite, timestamp) à partir de ces vraies valeurs plutôt que d'un tirage aléatoire
> 3. Documenter dans le docstring la source et la période exacte des données importées, pour pouvoir répondre si le jury demande d'où viennent les données météo

### 4.7 — Module environnemental (`environment`)

> Dans l'app `environment`, crée un modèle `WeatherEvent` : zone (CharField), type (choix : `normal`, `pluie_moderee`, `pluie_forte`), intensite (FloatField), timestamp (DateTimeField), source (CharField, choix : `historique_reel` ou `manuel`, default=`manuel`). Ajoute une fonction utilitaire `get_active_weather(zone)` qui retourne l'événement météo actif le plus récent pour une zone donnée. Ce modèle est ensuite peuplé principalement par `import_weather_history` (étape 4.6) plutôt que par génération aléatoire ; garde toutefois un moyen manuel de créer un `WeatherEvent` ponctuel pour forcer un scénario précis en démo (ex. déclencher une alerte pluie_forte sur une zone donnée juste avant la démonstration jury).

### 4.8 — Module IA : prédiction de congestion

> Crée `mobility/ml/weights.py` avec les constantes : `POIDS_METEO_FORTE = 1.3`, `POIDS_METEO_MODEREE = 1.15`, `POIDS_EVENEMENT = 10`, `POIDS_SIGNALEMENT = 5`, et `VERSION_MODELE = "v1"` (à incrémenter manuellement à chaque changement de poids, pour tracer quelle version a produit quelle prédiction).
>
> Puis crée `mobility/ml/predictor.py` avec une fonction `predict_congestion(segment_id, horizon_min=15, timestamp=None)` qui :
> 1. Récupère la moyenne historique de congestion pour ce segment à cette heure et ce jour de semaine (TrafficRecord source=`simule`)
> 2. Applique le facteur météo si le segment est `zone_inondable` et qu'un WeatherEvent actif existe pour sa zone
> 3. Ajoute un bonus si des signalements actifs existent sur ce segment
> 4. Retourne `{'score': int (0-100), 'facteurs': {...}, 'version_modele': VERSION_MODELE}`
>
> Si l'historique est insuffisant pour ce segment/créneau, logue un warning (`logging.getLogger('mobility')`) avec le segment concerné, en plus du flag `facteurs['donnees_insuffisantes']`. Ajoute des docstrings claires expliquant la formule. Le paramètre `timestamp` doit être optionnel (défaut `timezone.now()`) pour que la fonction soit testable unitairement.

### 4.9 — Endpoints segments, prédictions, météo

> Crée le modèle `Prediction` dans `mobility/models.py` : segment (FK), horizon_min (IntegerField, default=15), score_predit (IntegerField), facteurs (JSONField), version_modele (CharField, default=`"v1"`), timestamp_prediction (DateTimeField, auto_now_add=True).
>
> Puis crée les serializers et ViewSets DRF pour :
> - `GET /api/segments/` (liste, filtrable par zone) et `GET /api/segments/<id>/`
> - `GET /api/segments/<id>/history/` (historique TrafficRecord)
> - `GET /api/predictions/` (dernière prédiction de chaque segment)
> - `GET /api/predictions/<segment_id>/` (prédiction détaillée avec facteurs)
> - `GET /api/weather/current/` et `GET /api/weather/alerts/` (segments zone_inondable avec WeatherEvent actif)

### 4.10 — Job périodique de recalcul

> Crée une management command `recompute_predictions` qui parcourt tous les RoadSegment, appelle `predict_congestion` pour chacun, et enregistre le résultat dans un objet `Prediction`. Cette commande sera appelée toutes les 5 minutes via une tâche planifiée de l'hébergeur — ne code pas de scheduler, juste la commande. Entoure l'appel par segment d'un `try/except` qui logue l'erreur (`logging.getLogger('mobility')`) et continue sur les segments suivants plutôt que d'interrompre toute la commande si un seul segment échoue.

### 4.11 — Signalements citoyens (`reports`)

> Dans l'app `reports`, crée un modèle `Report` : user (FK), segment (FK), type (choix : `accident`, `nid_de_poule`, `route_barree`, `vehicule_en_panne`), gravite (choix : `faible`, `moyen`, `critique`), statut (choix : `actif`, `fusionne`, `resolu`, default=`actif`), nb_confirmations (IntegerField, default=1), created_at (auto_now_add).
>
> Dans la logique de création (`POST /api/reports/`), implémente le dédoublonnage :
> 1. Cherche un Report du même type, même segment, statut=`actif`, créé il y a moins de 5 minutes
> 2. Si trouvé : incrémente `nb_confirmations` et retourne ce report existant
> 3. Sinon : crée le nouveau Report, avec `gravite` déterminée par `classify_severity(type)` (accident/route_barree → critique, vehicule_en_panne → moyen, nid_de_poule → faible)
>
> Ajoute aussi `GET /api/reports/` (filtrable) et `PATCH /api/reports/<id>/` (réservé au rôle `autorite`).
>
> Protège `POST /api/reports/` par un throttling DRF par utilisateur (ex. `UserRateThrottle` configuré à 5 requêtes / 10 minutes) pour éviter qu'un utilisateur malveillant ou un bug client (boucle d'envoi) ne pollue le score composite du dashboard avec de faux signalements de types variés — le dédoublonnage seul ne protège que contre les doublons exacts, pas contre ce cas.
>
> Crée une management command `seed_demo_reports` dans `reports/management/commands/` (séparée de `seed_demo_data`, car le modèle `Report` n'existe qu'à partir de cette étape). Elle doit :
> 1. Réutiliser les utilisateurs et segments déjà créés par `seed_demo_data` (ne rien recréer ; lever une erreur claire si aucun n'existe)
> 2. Créer un petit nombre de `Report` avec des timestamps dans le passé (ex. 5 à 10, paramétrable via `--count`), répartis sur quelques segments différents, avec un mélange de statuts (`actif`, `resolu`) et de types
> 3. Utiliser le même `--seed` que `seed_demo_data` pour rester reproductible
>
> Objectif : que le dashboard autorités (`nb_signalements_actifs`, top 5 zones critiques) ne soit pas vide à l'ouverture de la démo, avant même le signalement fait en direct par Awa. Documente bien dans le docstring que ces signalements sont des données de seed distinctes du signalement de démonstration en direct, pour ne pas les confondre pendant la répétition.

### 4.12 — Dashboard autorités (`dashboard`)

> Dans l'app `dashboard`, crée une vue DRF (calcul à la volée, pas de modèle) pour :
> - `GET /api/dashboard/critical-zones/` : score composite = (0.5 × dernière congestion prédite) + (0.3 × nb_signalements_actifs × 10) + (0.2 × 100 si alerte météo active sinon 0) ; retourne les 5 segments les plus critiques
> - `GET /api/dashboard/stats/` : signalements actifs, segments en alerte météo, temps de trajet moyen simulé
> - `GET /api/dashboard/export/` : export CSV de critical-zones
>
> Réserve ces 3 endpoints au rôle `autorite` via une permission DRF personnalisée `IsAutorite`.

### 4.13 — App Flutter citoyens : structure

> Crée la structure d'un projet Flutter `cityflow_app` avec `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`. Crée `ApiService` dans `lib/services/api_service.dart` : appels HTTP vers le backend Django (base URL configurable), gestion du token JWT en mémoire.

### 4.14 — Écran principal (carte + prédiction)

> Crée `HomeScreen` : liste des segments avec leur score de congestion prédit, via `GET /api/predictions/`. Le niveau de risque doit être signalé par un **double codage** — couleur (verte/jaune/rouge) ET un second signal non-couleur (icône ✓/⚠/✕ ou libellé texte "Fluide"/"Modéré"/"Critique") — pour rester lisible par les utilisateurs daltoniens. Ajoute un état de chargement et un état d'erreur. Ajoute une mention discrète en bas d'écran "© OpenStreetMap contributors" (attribution requise par la licence ODbL des données de géométrie des segments).

### 4.15 — Écran détail segment + signalement

> Crée `SegmentDetailScreen` : score prédit, facteurs de la prédiction affichés lisiblement, bouton pour signaler un incident.
>
> Crée le widget `ReportFormSheet` (bottom sheet) : choix du type d'incident, envoi `POST /api/reports/`, confirmation visuelle après envoi.

### 4.16 — Bandeau alerte météo

> Ajoute un bandeau d'alerte en haut de `HomeScreen` si `GET /api/weather/alerts/` retourne au moins un segment à risque, avec le nom des segments concernés. Utilise une icône explicite (ex. goutte de pluie) en plus de la couleur du bandeau, pour rester cohérent avec le principe de double codage accessibilité de l'écran principal.

### 4.17 — Dashboard autorités

> Si le temps le permet : crée `AuthorityDashboardScreen` (Flutter Web) affichant le top 5 des zones critiques et les stats globales. Sinon : enregistre `RoadSegment`, `Report`, `Prediction` dans `admin.py` avec des `list_display`/`list_filter` pertinents pour un usage rapide par une autorité.

### 4.18 — (Bonus, si le temps le permet) Preuve de concept vision par ordinateur

> Uniquement si les étapes 4.1 à 4.17 sont terminées et testées, et qu'il reste du temps avant l'étape 5 : crée un script autonome `mobility/ml/vision_poc.py`, **non branché au reste de l'application** (pas d'appel depuis les endpoints ni depuis `predict_congestion`), qui :
> 1. Charge une vidéo locale pré-enregistrée (fournie en argument `--fichier`, filmée ou téléchargée au préalable sur un axe d'Abidjan — pas d'accès à un flux caméra réel ou à un système tiers)
> 2. Utilise un modèle de détection d'objets déjà entraîné (ex. YOLO via `ultralytics`, ou un détecteur OpenCV plus simple si le temps manque) pour compter les véhicules détectés par intervalle de quelques secondes
> 3. Déduit un niveau de congestion approximatif (ex. nombre de véhicules / zone de comptage) et l'affiche à l'écran, superposé sur la vidéo ou dans un simple graphique
>
> Documente clairement dans un commentaire en tête de fichier que ce script est une **preuve de concept isolée** destinée à illustrer la feuille de route "détection par caméras" du CDCFT (section 6), et non une fonctionnalité de production — à montrer en fin de démo jury comme un extra, pas comme un livrable du MVP. Si `ultralytics`/YOLO s'avère trop long à intégrer, un simple comptage de contours en mouvement (OpenCV `cv2.createBackgroundSubtractorMOG2`) suffit à illustrer le principe.

### 4.19 — Durcissement sécurité transverse (authentification, API, modèle IA)

> Une fois les étapes 4.1 à 4.18 terminées, reviens sur l'ensemble du projet pour un tour de durcissement sécurité qui ne rentre dans aucune étape précédente prise isolément :
> 1. Protège `POST /api/auth/login/` par un throttling dédié (ex. `AnonRateThrottle`, 5 tentatives / 5 minutes par IP) pour limiter le risque de force brute sur les mots de passe — le throttling existant (étape 4.11) ne couvre que les signalements, pas l'authentification.
> 2. Dans `settings.py`, fixe explicitement pour la production, via des variables d'environnement pour ne pas casser le développement local : `DEBUG = False`, `ALLOWED_HOSTS` limité au(x) domaine(s) réel(s), `SECURE_SSL_REDIRECT = True`, `SESSION_COOKIE_SECURE = True`, `CSRF_COOKIE_SECURE = True`.
> 3. Restreins `CORS_ALLOWED_ORIGINS` (django-cors-headers) à l'URL réelle de l'app Flutter Web et du dashboard, plutôt que `CORS_ALLOW_ALL_ORIGINS` qui n'est acceptable qu'en développement local.
> 4. Renforce `AUTH_PASSWORD_VALIDATORS` à l'inscription citoyenne (longueur minimale explicite, ex. 8 caractères) plutôt que de te reposer sans vérification sur les seuls réglages par défaut de Django.
> 5. **Sécurité du modèle de prédiction** : valide les entrées de `predict_congestion` et des endpoints associés (segment_id existant, horizon_min dans une plage raisonnable) pour renvoyer une erreur 404/400 propre plutôt qu'une erreur 500 exploitable.
> 6. **Sécurité du modèle de prédiction (suite)** : protège `GET /api/predictions/` et `GET /api/segments/*/history/` par un throttling de lecture raisonnable (moins strict que celui des signalements) pour limiter le scraping massif du modèle — c'est un actif potentiellement monétisable (voir l'analyse business), pas seulement une fonctionnalité technique à exposer sans limite.
> 7. **Sécurité du modèle de prédiction (suite)** : vérifie que la réponse de `predict_congestion` expose les facteurs de façon lisible pour l'utilisateur (transparence, cohérente avec le principe d'explicabilité du CDCFT) sans reproduire telles quelles les constantes exactes de `weights.py` dans le JSON — préfère des libellés qualitatifs ("effet météo : fort") ou des contributions relatives plutôt que les poids bruts, pour ne pas faciliter la reproduction à l'identique du modèle par un tiers.

---

## Étape 5 — Tests

Cette étape est volontairement plus longue que les précédentes : elle doit couvrir **tout** ce qui a été spécifié dans les étapes 4.1 à 4.19, pas seulement le module IA. Regroupe les tests par app Django pour rester lisible, et lance `python manage.py test` après chaque bloc plutôt qu'à la toute fin.

### 5.1 — `accounts` (authentification et rôles)

> Écris des tests d'intégration DRF (APITestCase) pour l'app `accounts` :
> - `POST /api/auth/register/` crée bien un utilisateur avec le rôle demandé (`citoyen` ou `autorite`) et refuse un rôle invalide
> - `POST /api/auth/login/` renvoie un token JWT valide pour des identifiants corrects, et une erreur claire (401) pour des identifiants incorrects
> - `POST /api/auth/refresh/` renouvelle bien le token à partir d'un refresh token valide, et échoue proprement sur un refresh token expiré/invalide
> - register/login restent accessibles sans authentification (permissions publiques), mais tous les autres endpoints du projet renvoient 401 sans token
> - le mot de passe est refusé à l'inscription s'il ne respecte pas la longueur minimale définie en étape 4.19
> - après 5 tentatives de connexion échouées en moins de 5 minutes depuis la même IP, la 6e tentative est bloquée par le throttling (étape 4.19), même avec des identifiants corrects

### 5.2 — `mobility` (modèles, import, module IA)

> Écris des tests (Django TestCase + APITestCase) couvrant :
> - **Modèles** : les contraintes de champs de `RoadSegment`/`TrafficRecord` (`niveau_congestion` dans [0,100], `source_geometrie` limité à `osm`/`manuel`), et que les index déclarés existent bien
> - **`import_osm_segments`** : sur un petit fichier GeoJSON de test, vérifie que les segments sont créés avec `source_geometrie='osm'`, que `zone_inondable` est déterminé à partir de la liste de zones à risque (pas au hasard), et que `--dry-run` n'écrit rien en base ; vérifie aussi qu'un import répété (mise à jour) ne duplique pas les segments déjà importés
> - **`seed_demo_data`** : avec un même `--seed`, deux exécutions consécutives produisent exactement les mêmes valeurs de congestion (reproductibilité) ; le niveau de congestion simulé aux heures de pointe (7h-9h, 17h-19h) est statistiquement plus élevé qu'aux heures creuses (vérifie une différence de moyenne, pas juste l'absence de crash) ; la commande échoue avec un message clair si aucun `RoadSegment` `source_geometrie='osm'` n'existe encore
> - **`predict_congestion`** : le score reste dans [0,100] ; le facteur météo augmente le score sur un segment `zone_inondable` avec `WeatherEvent` actif ; un segment non `zone_inondable` n'est jamais affecté par la météo ; un signalement actif sur le segment augmente le score ; si l'historique est insuffisant, la fonction retourne un score de repli avec `facteurs['donnees_insuffisantes'] = True` (et un warning est bien loggé, étape 4.8) ; la réponse inclut `version_modele` ; **les constantes exactes de `weights.py` ne sont jamais présentes telles quelles dans la réponse** (test de non-régression sur la sécurité du modèle, étape 4.19)
> - **`recompute_predictions`** : si un segment lève une exception pendant le recalcul, la commande continue sur les segments suivants plutôt que de s'arrêter (simule une erreur sur un segment et vérifie que les autres ont bien une `Prediction` à jour)
> - **Endpoints** `GET /api/segments/`, `GET /api/segments/<id>/`, `GET /api/segments/<id>/history/`, `GET /api/predictions/`, `GET /api/predictions/<segment_id>/` : filtrage par zone fonctionnel, 404 propre sur un `segment_id` inexistant (pas une erreur 500), et `GET /api/predictions/` throttlé en lecture (étape 4.19) sans bloquer un usage normal

### 5.3 — `environment` (météo)

> Écris des tests couvrant :
> - `import_weather_history` : à partir d'un petit export de test, les `WeatherEvent` créés ont bien `source='historique_reel'` et le bon `type` selon les seuils d'intensité documentés
> - `get_active_weather(zone)` renvoie bien l'événement météo actif le plus récent pour une zone donnée, et `None` (ou équivalent) si aucun événement actif n'existe
> - `GET /api/weather/current/` et `GET /api/weather/alerts/` ne renvoient que les segments `zone_inondable` avec un `WeatherEvent` actif, jamais les autres

### 5.4 — `reports` (signalements)

> Écris des tests d'intégration DRF (APITestCase) pour l'app `reports` :
> - `POST /api/reports/` : un second signalement identique (même type, même segment) dans les 5 minutes est fusionné (`nb_confirmations` incrémenté, pas de nouvel objet créé) ; un signalement au-delà de 5 minutes ou avec un type différent crée bien un nouvel objet
> - la `gravite` est déterminée automatiquement selon le type (`accident`/`route_barree` → critique, `vehicule_en_panne` → moyen, `nid_de_poule` → faible), jamais laissée à la charge du client
> - après 5 signalements en moins de 10 minutes par le même utilisateur, le 6e est bloqué par le throttling (étape 4.11), avec un message d'erreur clair (pas une erreur 500)
> - `GET /api/reports/` est filtrable (par segment, par statut) ; `PATCH /api/reports/<id>/` est refusé (403) à un utilisateur `citoyen` et autorisé à `autorite`
> - `seed_demo_reports` : réutilise bien les utilisateurs/segments existants (n'en recrée pas), échoue proprement si aucun n'existe encore, et reste reproductible avec le même `--seed`

### 5.5 — `dashboard` (autorités)

> Écris des tests d'intégration DRF (APITestCase) pour l'app `dashboard` :
> - `GET /api/dashboard/critical-zones/` : le calcul du score composite (0,5 × congestion + 0,3 × signalements×10 + 0,2 × météo) correspond bien à la formule documentée sur un jeu de données de test construit à la main (pas seulement "ça ne plante pas") ; renvoie bien les 5 segments les plus critiques, triés
> - `GET /api/dashboard/stats/` renvoie des valeurs cohérentes avec les données de test injectées (nombre de signalements actifs, segments en alerte météo)
> - `GET /api/dashboard/export/` renvoie un CSV valide et parsable, avec les mêmes données que `critical-zones`
> - les 3 endpoints renvoient 403 pour un utilisateur `citoyen` (déjà couvert, à garder) et 200 pour `autorite`

### 5.6 — Sécurité transverse (étape 4.19)

> Écris des tests dédiés à la sécurité, séparés des tests fonctionnels ci-dessus :
> - `CORS` : une requête depuis une origine non autorisée est refusée ; une requête depuis l'origine de l'app Flutter Web est acceptée
> - les entrées invalides sur les endpoints de prédiction (`segment_id` inexistant, `horizon_min` hors plage) renvoient 400/404, jamais 500
> - vérifie qu'aucune vue ne fuit d'information sensible dans un message d'erreur (ex. trace Python complète renvoyée au client si `DEBUG=True` par erreur)

### 5.7 — Test d'intégration de bout en bout (pipeline complet)

> Écris un test d'intégration de bout en bout du pipeline de données : lance `import_osm_segments` (sur un petit fichier de test), puis `seed_demo_data --users 3 --days 5 --seed 42`, puis `import_weather_history` (sur un petit export de test), puis `seed_demo_reports --seed 42`, puis `recompute_predictions`. Vérifie que toutes les prédictions générées sont dans [0,100], qu'aucun facteur n'est manquant, et que relancer la même séquence avec le même `--seed` produit exactement les mêmes valeurs de congestion simulée (reproductibilité). Ce test protège contre les régressions silencieuses en amont du modèle IA, pas seulement contre les erreurs dans `predict_congestion` lui-même.

### 5.8 — Tests côté Flutter (`cityflow_app`)

> Dans le projet Flutter, écris des tests avec `flutter test` (widget tests, pas besoin de tests end-to-end complets vu le délai) :
> - `HomeScreen` : affiche bien l'état de chargement, l'état d'erreur, et la liste des segments avec le double codage couleur + icône/texte (étape 4.14) plutôt que la couleur seule
> - `ReportFormSheet` : la soumission déclenche bien l'appel `POST /api/reports/` et affiche la confirmation visuelle attendue
> - le bandeau météo (étape 4.16) ne s'affiche que si `GET /api/weather/alerts/` renvoie au moins un segment à risque

### 5.9 — Vérification finale contre les critères d'acceptation

> Relis les critères d'acceptation MVP définis dans le CDCFT (section 1) et vérifie un par un qu'ils sont couverts par au moins un des tests ci-dessus ou par une vérification manuelle documentée. S'il manque un test pour un critère, ajoute-le avant de passer à l'étape 6 — ne considère pas l'étape 5 terminée tant qu'il reste un critère d'acceptation non couvert.

---

## Étape 6 — CI/CD & revue de code

> Crée `.github/workflows/ci.yml` qui, à chaque push et pull request : installe les dépendances Python, lance `python manage.py test`, lance `flake8` sur le code Django, et (si le temps le permet) un job séparé qui installe Flutter et lance `flutter test` sur `cityflow_app`. Le job doit échouer si l'un des trois échoue.

> Fais une auto-revue à froid de mon code Django généré : relis chaque `views.py` et signale les incohérences de nommage, le code dupliqué, et les endpoints sans gestion d'erreur.

---

## Étape 7 — Déploiement

> Crée un `Dockerfile` pour le backend Django (Python 3.12, gunicorn) et un `docker-compose.yml` incluant Django + PostgreSQL. Ajoute un `.env.example` listant les variables nécessaires (SECRET_KEY, DATABASE_URL, DEBUG).

> Prépare les instructions de déploiement sur Render (ou Railway) : variables d'environnement, commande de build, commande de démarrage (gunicorn), et comment lancer, dans l'ordre, `import_osm_segments`, `seed_demo_data --seed <valeur fixe utilisée en démo>`, `import_weather_history` puis `seed_demo_reports --seed <même valeur>` une fois en production. Précise que les fichiers d'export (GeoJSON OSM, historique météo) doivent être présents sur le serveur ou embarqués dans l'image Docker, puisque ces commandes ne font pas d'appel réseau live.

> Décris un plan de rollback simple : comment revenir à la version précédente en cas d'échec de déploiement le jour de la démo (garder le tag Git précédent déployable, tester la veille et pas le jour J).

> Crée une management command `check_demo_readiness` qui vérifie, sans rien modifier : qu'il existe au moins un `RoadSegment` avec `source_geometrie='osm'`, qu'il existe des `WeatherEvent` avec `source='historique_reel'`, qu'il existe une `Prediction` récente (moins de 15 minutes) pour chaque segment, et qu'il existe au moins un `Report` de seed (issu de `seed_demo_reports`) pour que le dashboard ne soit pas vide à l'ouverture. Affiche un résumé clair (✓/✕ par vérification). À lancer systématiquement la veille de la démo, pour détecter un import manquant ou un job périodique en échec avant qu'il ne soit trop tard.

---

## Étape 8 — Release & versioning

> Génère un `CHANGELOG.md` pour la version v0.1.0 : fonctionnalités livrées (prédiction T+15min, alertes météo, signalement citoyen, dashboard autorités) et limitations connues (géométrie des segments et historique météo basés sur des données réelles — OSM/HDX et historique météo public —, mais historique de congestion et signalements toujours simulés faute d'API de trafic ouverte pour Abidjan ; modèle statistique simple ; jusqu'à 100 utilisateurs fictifs générés avec des noms et trajets domicile-travail réalistes pour Abidjan, mais restant des profils synthétiques).

> Génère un `README.md` complet : présentation, installation locale (backend + app Flutter), comment lancer dans l'ordre `import_osm_segments`, `seed_demo_data`, `import_weather_history` et `seed_demo_reports` (avec un mot sur la provenance des fichiers d'import : export OSM/HDX pour les segments, export d'une API météo historique pour la pluviométrie, et une précision que `seed_demo_reports` crée des signalements de démo distincts du signalement fait en direct pendant la présentation), comment lancer les tests, lien vers le scénario de démonstration jury.

---

## Feuille de route V2 (hors périmètre du vibeathon — à garder pour plus tard)

Ces quatre prompts **ne sont pas destinés à être exécutés pendant la semaine du vibeathon**. Ils sont rédigés à l'avance pour que l'équipe puisse reprendre le projet directement avec Claude Code une fois le MVP livré, sans repartir de zéro sur la formulation. Voir le CDCFT, section 6 ("Vision V2 — hors MVP") pour le contexte et la priorisation de ces quatre évolutions.

### V2.1 — Optimisation d'itinéraire multi-critères

> Crée un module `mobility/ml/routing.py` qui modélise le réseau routier comme un graphe (`networkx` ou équivalent) : nœuds = intersections, arêtes = segments existants, poids dynamique de chaque arête calculé à partir de `predict_congestion` (congestion) et de `get_active_weather` (risque météo), combinés à la distance/temps de base du segment. Implémente une fonction `meilleur_itineraire(origine, destination)` qui retourne le chemin le plus court pondéré (Dijkstra ou A*) entre deux points, avec le détail segment par segment (score de congestion et facteur météo de chacun). Expose un endpoint `GET /api/itineraire/?origine=<segment_id>&destination=<segment_id>`. Contrairement à la version initiale de cette feuille de route, ce prérequis est désormais déjà couvert par le MVP : depuis que l'étape 4.4 importe l'ensemble du réseau routier principal d'Abidjan (toutes communes, tags `highway=motorway|trunk|primary|secondary|tertiary`) plutôt qu'une liste restreinte d'axes, le graphe est normalement déjà suffisamment maillé pour connecter la plupart des origines/destinations demandées — vérifie simplement la connexité entre les deux points avant de renvoyer un résultat, et prévois un message d'erreur clair si aucun chemin n'existe dans le graphe importé.

### V2.2 — IA comportementale

> Une fois qu'un historique réel d'usage existe sur plusieurs semaines (pas de données simulées), crée un module qui identifie les trajets récurrents d'un utilisateur (mêmes segments, mêmes créneaux horaires répétés) et personnalise les alertes en conséquence (ex. "vous partez habituellement vers 7h30 sur ce trajet, la congestion prédite est élevée aujourd'hui, envisagez de partir 15 minutes plus tôt"). Ne pas tenter cette étape avec des données simulées ou un historique de moins de plusieurs semaines — le résultat ne serait pas représentatif et risquerait de donner de fausses alertes personnalisées.

### V2.3 — Détection automatique par caméras (passage du POC à la production)

> Une fois un partenariat d'accès à un flux caméra réel obtenu (STI ou réseau dédié — voir CDCFT section 6), fais évoluer le script `mobility/ml/vision_poc.py` (étape 4.18) vers un service branché : ingestion du flux vidéo réel, détection en continu, écriture des comptages dans un nouveau modèle `CameraDetection` (segment, timestamp, nb_vehicules_detectes, source='camera'), et intégration de ce signal dans `predict_congestion` comme facteur supplémentaire (au même titre que la météo ou les signalements). Traiter ce changement comme une migration de données majeure, à tester en parallèle du système existant avant de le remplacer.

### V2.4 — Digital Twin de la ville

> Modélise le réseau routier complet d'Abidjan comme un graphe pondéré, avec un moteur de simulation permettant de répondre à des scénarios du type "si le segment X est fermé, quel est l'effet prédit sur la congestion des segments voisins ?". La base du graphe (axes principaux, toutes communes) est déjà disponible depuis l'étape 4.4 ; ce qui manque encore pour un vrai digital twin est une géométrie plus fine (rues secondaires/résidentielles, utile pour des itinéraires de repli réalistes) et surtout un modèle de report de trafic (comment les usagers se reportent sur des itinéraires alternatifs), qui n'existe pas dans le MVP actuel — ne pas sous-estimer l'effort de modélisation que cela demande avant de commencer l'implémentation.

---

## Bonus — Préparation de la présentation jury

> Aide-moi à rédiger un script de démonstration de 5 minutes suivant le scénario Awa (Cocody → Plateau) :
> - Introduction du problème (30s)
> - Démonstration de la prédiction T+15min (1 min)
> - Démonstration de l'alerte météo/inondation (1 min)
> - Démonstration du signalement citoyen (1 min)
> - Démonstration du dashboard autorités (1 min)
> - Conclusion sur l'impact et la feuille de route (30s) : illustre concrètement la feuille de route V2 avec un second exemple parlant pour le jury — un utilisateur au Foyer des Jeunes de Marcory qui veut se rendre à Saint Jean, Cocody. Explique que le MVP actuel affiche la congestion segment par segment sur son trajet, mais ne calcule pas encore l'itinéraire optimal ; puis montre en une phrase ce que l'optimisation d'itinéraire multi-critères (V2.1, déjà spécifiée et prête à être développée) changerait concrètement pour ce même utilisateur.

---

## Rappel — checklist avant de soumettre (voir bootcamp)

- [ ] Je comprends chaque ligne de code générée, pas juste "ça tourne"
- [ ] Le module IA reste explicable (facteurs visibles à chaque prédiction)
- [ ] Les utilisateurs fictifs (jusqu'à 100, noms et trajets réalistes) et l'historique de trafic simulé sont cohérents et reproductibles (même `--seed` → mêmes résultats)
- [ ] La géométrie des segments (OSM/HDX) et l'historique météo (API météo historique) sont bien des données réelles, avec leur source documentée dans le code
- [ ] L'import OSM couvre bien l'ensemble des communes d'Abidjan (pas seulement quelques axes emblématiques), avec des insertions en masse pour rester performant
- [ ] La CI passe au vert avant la démo
- [ ] Le déploiement a été testé la veille, pas le jour J
- [ ] La version livrée a un numéro et un changelog
- [ ] Les niveaux de risque (congestion, météo) sont lisibles sans dépendre de la seule couleur
- [ ] L'attribution "© OpenStreetMap contributors" est visible dans l'app
- [ ] `TIME_ZONE = "Africa/Abidjan"` est bien fixé dans les settings
- [ ] `check_demo_readiness` a été lancé la veille et est passé au vert
- [ ] `seed_demo_reports` a bien été lancé : le dashboard autorités n'est pas vide à l'ouverture de la démo
- [ ] Les critères d'acceptation du CDCFT sont listés et vérifiés un par un (étape 5)
- [ ] Si la preuve de concept vision par ordinateur (4.18) a été tentée, elle est clairement présentée comme un extra hors MVP, pas comme un livrable branché au reste de l'application
- [ ] Le durcissement sécurité transverse (4.19) a été fait : throttling sur le login, `DEBUG=False`/`ALLOWED_HOSTS`/cookies sécurisés en production, CORS restreint, validation des entrées de `predict_congestion`, poids du modèle non exposés bruts dans l'API
- [ ] Chaque app Django (`accounts`, `mobility`, `environment`, `reports`, `dashboard`) a ses propres tests, pas seulement le module IA
- [ ] Les tests Flutter (`flutter test`) couvrent au moins `HomeScreen`, `ReportFormSheet` et le bandeau météo
- [ ] Aucun critère d'acceptation du CDCFT n'est laissé sans test ni vérification manuelle documentée (étape 5.9)
