# CityFlow AI — Procédure de lancement du projet avec Claude Code

Ce guide explique comment utiliser **Claude Code** pour exécuter, de bout en bout, la feuille de route décrite dans `CityFlow_AI_Prompts_Realisation.md`, en s'appuyant sur le `CityFlow_AI_CDCFT_Vibeathon_1.docx` comme référence de cadrage.

---

## 0. Prérequis

| Outil | Pourquoi | Vérification |
|---|---|---|
| Node.js 18+ | requis pour installer Claude Code | `node -v` |
| Claude Code | l'agent qui va exécuter les prompts | voir étape 1 |
| Python 3.12 + pip | backend Django | `python3 --version` |
| PostgreSQL | base de données du MVP | `psql --version` |
| Flutter SDK | app citoyenne + dashboard web | `flutter --version` |
| Git | versioning, rollback, CI/CD | `git --version` |
| Un abonnement Claude (Pro/Max/Team) ou un compte Console avec crédits API | authentification de Claude Code | — |

---

## 1. Installer et authentifier Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

(Une installation native sans Node.js existe aussi ; voir `docs.claude.com` si vous préférez cette option.)

Première connexion :

```bash
claude
# Une fenêtre de navigateur s'ouvre pour se connecter avec ton compte Anthropic
```

Pour changer de compte plus tard : tape `/login` dans une session en cours.

---

## 2. Initialiser le dépôt du projet

```bash
mkdir cityflow-ai && cd cityflow-ai
git init
mkdir cityflow_backend cityflow_app docs
```

Place les deux documents de cadrage dans `docs/` pour que Claude Code puisse s'y référer à tout moment :

```bash
cp /chemin/vers/CityFlow_AI_CDCFT_Vibeathon_1.docx docs/
cp /chemin/vers/CityFlow_AI_Prompts_Realisation.md docs/
```

---

## 3. Créer le `CLAUDE.md` — le contexte permanent du projet

`CLAUDE.md` est lu par Claude Code au début de **chaque session**. C'est l'endroit où fixer une bonne fois pour toutes les conventions du projet, pour ne pas avoir à les répéter dans chaque prompt.

Lance Claude Code à la racine du projet :

```bash
cd cityflow-ai
claude
```

Puis, dans la session, tape :

```
/init
```

Claude Code génère un premier `CLAUDE.md` à partir de ce qu'il trouve dans le dossier. Complète-le ensuite (directement en langage naturel dans la session, ou en éditant le fichier) pour qu'il contienne au minimum :

```markdown
# CityFlow AI

## Contexte
Backend Django REST Framework + app Flutter, MVP pour un vibeathon d'une semaine.
Le cahier des charges de référence est docs/CityFlow_AI_CDCFT_Vibeathon_1.docx.
La feuille de route détaillée des prompts est docs/CityFlow_AI_Prompts_Realisation.md
— toujours suivre l'ordre de ce fichier, étape par étape.

## Stack
- Backend : Python 3.12, Django + DRF + simplejwt + cors-headers, PostgreSQL
- Frontend citoyen/autorités : Flutter (mobile + web)
- TIME_ZONE = "Africa/Abidjan" partout côté backend

## Commandes
- `python manage.py runserver` démarre le backend
- `python manage.py test` lance les tests
- `flutter run` lance l'app côté cityflow_app

## Conventions
- Toute nouvelle fonctionnalité IA doit rester explicable (facteurs visibles)
- Les données réelles (OSM/HDX, météo) et simulées (trafic, signalements) doivent
  être clairement distinguées dans le code (champs `source`, `source_geometrie`)
- Ne jamais casser la reproductibilité du seed de `seed_demo_data`
```

Commit ce premier état :

```bash
git add . && git commit -m "Initialisation du projet + CLAUDE.md"
```

---

## 4. Exécuter la feuille de route, prompt par prompt

**Principe** : un prompt = une session (ou un tour de session) = une revue = un commit. Ne jamais enchaîner plusieurs prompts sans relire le résultat.

### 4.1 Choisir le mode de permission

Au démarrage d'une session, Claude Code demande une confirmation avant chaque modification de fichier ou commande. Pour un vibeathon, deux approches réalistes :

- **Mode par défaut ("ask")** : recommandé pour les premiers prompts (4.1 à 4.8, le cœur du module IA), pour bien comprendre chaque étape.
- **Mode accéléré** (`claude --dangerously-skip-permissions`) : envisageable une fois à l'aise, pour les prompts plus mécaniques (Flutter, README, CHANGELOG). À utiliser avec un `git status` propre avant de lancer, pour pouvoir tout annuler avec `git checkout -- <fichier>` en cas de dérapage.

### 4.2 Boucle de travail recommandée, étape par étape

Pour chaque prompt du fichier `CityFlow_AI_Prompts_Realisation.md`, dans l'ordre (4.1 → 4.18, puis étapes 5 à 8) :

1. Ouvre une session dans le bon dossier :
   ```bash
   cd cityflow_backend   # ou cityflow_app selon le prompt
   claude
   ```
2. Colle le prompt correspondant tel quel (copié depuis le `.md`).
3. **Relis** le résultat : que Claude Code t'explique ce qu'il a fait si ce n'est pas clair (`explique-moi ce que tu viens de créer et pourquoi`).
4. Lance les vérifications qui s'appliquent à ce stade :
   - après un modèle → `python manage.py makemigrations && python manage.py migrate`
   - après une commande → lance-la avec des petits volumes (`--users 3 --days 5`)
   - après un endpoint → teste-le avec `curl` ou l'explorateur DRF
5. Si tout est bon :
   ```bash
   git add . && git commit -m "Étape 4.X — <résumé>"
   ```
6. Si quelque chose cloche, corrige avant de passer au prompt suivant — **ne saute pas d'étape**, l'ordre du fichier reflète les dépendances réelles entre les briques (ex. 4.4 avant 4.5, car `seed_demo_data` a besoin des segments déjà importés).
7. Toutes les 30 minutes environ, ou entre deux prompts sans lien direct, tape `/clear` pour repartir sur un contexte propre (CLAUDE.md est relu automatiquement).

### 4.3 Cas particulier — étapes 4.11 à 4.17 (Flutter)

Change de dossier de travail avant de lancer Claude Code (`cd cityflow_app`), pour qu'il ne mélange pas le contexte Django et le contexte Flutter dans la même session.

### 4.4 Cas particulier — étape 4.18 (bonus vision par ordinateur)

Ne lance ce prompt que si tu as déjà commité avec succès les étapes 4.1 à 4.17 et qu'il te reste du temps avant l'étape 5. Travaille-le dans un dossier ou une branche Git séparée (`git checkout -b bonus-vision-poc`) pour ne jamais risquer de casser le MVP principal si ça ne marche pas.

---

## 5. Étape 5 — Tests

Colle chaque prompt de tests un par un, puis lance systématiquement :

```bash
python manage.py test
```

avant de committer. Si un test échoue, demande directement à Claude Code de corriger :

```
le test <nom_du_test> échoue avec l'erreur suivante : <colle l'erreur>, corrige le code ou le test selon le cas
```

---

## 6. Étape 6 — CI/CD & revue de code

Après avoir créé `.github/workflows/ci.yml`, pousse sur une branche de test et vérifie que le job passe au vert sur GitHub avant de continuer :

```bash
git push origin ta-branche
```

Pour la revue de code à froid (prompt "auto-revue"), lance-la dans une session **séparée** de celle qui a écrit le code, pour que Claude Code l'examine avec un regard neuf plutôt que de se relire lui-même dans le même fil de contexte.

---

## 7. Étape 7 — Déploiement

1. Colle les prompts Dockerfile/docker-compose, puis teste en local avant tout déploiement réel :
   ```bash
   docker compose up --build
   ```
2. Une fois les instructions Render/Railway générées, déploie **la veille de la démo**, jamais le jour même (voir CDCFT, plan de rollback).
3. Lance dans l'ordre, sur l'environnement de production : `import_osm_segments`, `seed_demo_data --seed <valeur fixe>`, `import_weather_history`, `seed_demo_reports --seed <même valeur>`.
4. Termine par le prompt `check_demo_readiness` (ajouté à la feuille de route) et corrige tout ce qu'il signale en rouge avant de partir te reposer.

---

## 8. Étape 8 — Release & jury

1. Génère `CHANGELOG.md` et `README.md`.
2. Tague la version :
   ```bash
   git tag v0.1.0 && git push --tags
   ```
3. Utilise le prompt bonus pour rédiger le script de démonstration de 5 minutes (scénario Awa), et répète-le au moins une fois en conditions réelles sur l'environnement déployé.

---

## 9. Bonnes pratiques transverses (à garder en tête tout du long)

- **Un commit par prompt réussi.** Ça donne un point de retour en arrière (`git checkout -- <fichier>`) si Claude Code part dans une mauvaise direction sur le prompt suivant.
- **Sois spécifique dans les corrections.** Plutôt que "corrige le bug", dis "dans `mobility/ml/predictor.py`, le score dépasse 100 quand le facteur météo et le bonus signalement se cumulent — plafonne le résultat à 100".
- **`/clear` régulièrement** pour éviter qu'une session très longue ne perde des détails importants du début de la conversation.
- **Ne jamais laisser Claude Code improviser une donnée factuelle sensible** (ex. vraies coordonnées GPS, vrais chiffres météo) sans vérifier la source — demande-lui de citer d'où viennent les fichiers d'import utilisés.
- **Garde le CDCFT et la feuille de route à jour** si le périmètre change en cours de route (ex. si l'étape 4.18 est finalement abandonnée faute de temps) — un prompt rapide à Claude Code suffit : "mets à jour le CHANGELOG et le README pour refléter que l'étape 4.18 n'a pas été réalisée, faute de temps".

---

## Résumé visuel de l'ordre d'exécution

```
4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6 → 4.7 → 4.8 → 4.9 → 4.10
→ 4.11 → 4.12 → 4.13 → 4.14 → 4.15 → 4.16 → 4.17 → (4.18 bonus)
→ Étape 5 (tests) → Étape 6 (CI/CD) → Étape 7 (déploiement)
→ Étape 8 (release) → Script de démo jury
```
