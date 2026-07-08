# Changelog

## v0.1.0 — MVP Vibeathon

### Fonctionnalités livrées

- **Prédiction T+15 min** : score de congestion par segment basé sur l'historique simulé, pondéré par la météo et les signalements actifs. Chaque prédiction expose ses facteurs (explicabilité).
- **Alertes météo / inondation** : détection des segments `zone_inondable` avec un événement météo actif ; bandeau d'alerte dans l'app citoyenne.
- **Signalement citoyen** : création de rapports d'incident, déduplication automatique (même type sur le même segment dans les 5 minutes), throttling anti-abus.
- **Dashboard autorités** : score composite (congestion × signalements × météo), top 5 zones critiques, export CSV — accès réservé au rôle `autorite`.
- **Authentification JWT** : register/login/refresh, rôles `citoyen` / `autorite`, throttle sur le login (5 tentatives / 5 min).
- **App Flutter** : liste des segments avec double codage couleur + icône (accessibilité daltoniens), détail segment, formulaire de signalement, bandeau alerte météo, attribution OSM.
- **CI/CD** : GitHub Actions — tests Django + flake8 + tests Flutter à chaque push.
- **Docker** : `Dockerfile` + `docker-compose.yml` (Django + PostgreSQL).

### Limitations connues

- **Historique de congestion simulé** : aucune API de trafic ouverte n'existe pour Abidjan. L'historique est généré par `seed_demo_data` avec une courbe calibrée sur les heures de pointe locales (7h–9h, 17h–19h), mais reste synthétique.
- **Géométrie OSM** : les segments sont importés depuis OpenStreetMap (toutes communes du Grand Abidjan, tags `highway=motorway|trunk|primary|secondary|tertiary`). Données réelles, mais la précision dépend de la communauté OSM locale.
- **Météo historique** : importée depuis une API publique (ex. Open-Meteo) via `import_weather_history`. Les données sont réelles sur la période importée.
- **Signalements de seed** : les signalements créés par `seed_demo_reports` sont des données de démonstration distinctes des signalements faits en direct pendant la présentation jury.
- **Jusqu'à 100 utilisateurs fictifs** : noms et trajets domicile-travail réalistes pour Abidjan (profils Yopougon/Abobo → Plateau/Cocody), mais restant des profils synthétiques.
- **Modèle IA statistique simple** : pas de machine learning entraîné — moyenne historique + facteurs pondérés. Suffisant pour le MVP, à faire évoluer avec des données réelles.
- **Pas d'optimisation d'itinéraire** : le MVP affiche la congestion segment par segment ; le calcul d'itinéraire optimal est planifié pour la V2.
