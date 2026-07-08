# CityFlow AI — Analyse stratégique, budget prévisionnel et stratégie commerciale

*Note : je ne suis ni conseiller financier ni juriste. Les chiffres ci-dessous sont des ordres de grandeur construits à partir de données de marché ivoiriennes disponibles publiquement (Glassdoor, Jobivoire, Grey Search Africa), à faire valider par un expert-comptable/juriste avant toute décision d'engagement financier ou de levée de fonds.*

---

## 1. Points forts

| Point fort | Pourquoi ça compte |
|---|---|
| **Ancrage local réel** | Le lien pluie/inondation → congestion est spécifique à Abidjan, pas une fonctionnalité générique copiée sur Google Maps/Waze. C'est la vraie barrière à l'entrée face aux géants. |
| **Double clientèle (B2C + B2G)** | Peu de startups mobilité africaines ont un produit *et* un client institutionnel dès le MVP. Ça ouvre deux modèles de revenus distincts (voir section 4). |
| **IA explicable** | Chaque prédiction expose ses facteurs. Argument de vente fort face à des clients institutionnels (autorités, assureurs) qui se méfient des boîtes noires. |
| **Rigueur méthodologique démontrée** | Distinction rigoureuse données réelles/simulées, reproductibilité (seed), tests, CI/CD, plan de rollback. C'est le genre de discipline qu'un investisseur ou un acheteur B2G regarde pour évaluer le risque d'exécution d'une équipe. |
| **Vision d'extensibilité déjà posée** | Digital twin, détection caméra, IA comportementale sont déjà identifiés comme feuille de route V2 — utile pour un pitch investisseur qui veut voir un chemin de croissance, pas juste un MVP figé. |
| **Coût d'infrastructure très faible au démarrage** | Stack Django + PostgreSQL + Flutter, pas de Redis/PostGIS/Kubernetes — un MVP qui peut tourner sur un hébergement à quelques dizaines de milliers de FCFA/mois. |

## 2. Points faibles

| Point faible | Risque associé | Ce qu'il faudrait pour l'atténuer |
|---|---|---|
| **Cœur du produit (trafic) reste simulé** | Un client B2G ou B2B paiera difficilement cher pour une prédiction dont l'historique d'apprentissage est fabriqué, même calibré. C'est acceptable pour un MVP de compétition, pas pour une vente commerciale. | Accord de données avec un partenaire ayant un vrai flux (opérateur télécom pour la densité de mobiles, assureur, ou le STI lui-même) — c'est un prérequis avant toute commercialisation sérieuse, pas un détail technique. |
| **Échelle très réduite (15-30 segments, 100 utilisateurs)** | Aucune valeur commerciale prouvée à l'échelle d'une vraie ville de 6+ millions d'habitants. | Feuille de route d'échelle explicite avant toute negociation commerciale : combien de segments/communes couverts à V1 commerciale réelle ? |
| **Dépendance à un accès STI hypothétique** | La vision caméra dépend d'un accès à un système contrôlé par le ministère de l'Intérieur — hors de contrôle de l'équipe, cycle de négociation potentiellement long (mois, voire années). | Ne jamais présenter cet accès comme acquis dans un pitch ; le traiter comme un partenariat à négocier, avec un plan B (signalement citoyen seul) qui fonctionne sans lui. |
| **Modèle de monétisation non testé** | Aucun client payant à ce stade, aucune validation de volonté de payer (côté citoyen, la concurrence gratuite — Google Maps, Waze — est un obstacle réel). | Valider la volonté de payer côté B2G *avant* d'investir dans le B2C : un seul contrat pilote avec une mairie ou le Ministère des Transports vaut plus, à ce stade, que 10 000 téléchargements citoyens. |
| **Cadre légal des données non traité** | La Côte d'Ivoire a une autorité de protection des données (ARTCI) et un cadre légal sur les données personnelles ; vendre des données de trafic liées à des utilisateurs identifiables est un risque juridique et réputationnel. | Ne jamais vendre de données individuelles ou identifiables — uniquement des agrégats anonymisés (voir section 4). Faire valider le modèle par un juriste local avant toute vente de données. |
| **Petite équipe, cycle de vente B2G lent** | Les marchés publics et partenariats institutionnels prennent souvent 6 à 18 mois (appels d'offres, validation administrative), ce qui ne colle pas avec un rythme de startup pressée de générer du revenu. | Prévoir une trésorerie tampon de 12-18 mois avant le premier contrat B2G signé, ou chercher des revenus B2B plus rapides en parallèle (logistique, assurance). |
| **Sécurité traitée au niveau technique du MVP, pas encore au niveau entreprise** | Le CDCFT couvre la sécurité applicative de base (JWT, rôles, HTTPS, throttling) — suffisant pour un MVP de compétition, mais un client B2G ou un assureur demandera des garanties supplémentaires (audit de sécurité, plan de réponse à incident, hébergement des données conforme, assurance cyber) avant de signer un vrai contrat. | Prévoir un budget et un plan de montée en maturité sécurité avant la première négociation B2G sérieuse — voir section 3.6 bis et section 6. |

---

## 3. Budget prévisionnel (12 premiers mois post-vibeathon)

Estimations basées sur les grilles de salaires observées à Abidjan en 2026 (Glassdoor, Jobivoire, Grey Search Africa) — à ajuster selon le profil réel de vos recrutements.

### 3.1 Équipe (poste le plus lourd du budget)

| Poste | Profil | Salaire mensuel estimé (FCFA) | Coût annuel estimé |
|---|---|---|---|
| Lead backend Django | confirmé | 500 000 – 900 000 | 6 000 000 – 10 800 000 |
| Développeur Flutter | junior/confirmé | 300 000 – 700 000 | 3 600 000 – 8 400 000 |
| Data/ML (temps partiel ou freelance) | confirmé | 400 000 – 800 000 (souvent en mission partielle) | 2 400 000 – 4 800 000 (à 50%) |
| Chargé(e) de business development (B2G/B2B) | junior/confirmé | 300 000 – 700 000 | 3 600 000 – 8 400 000 |
| Fondateur(s) / gestion projet | souvent non rémunéré ou salaire minimal la 1ère année | — | — |
| **Sous-total équipe (4 profils, hors fondateurs)** | | | **≈ 15 600 000 – 32 400 000 FCFA/an** |

*(soit environ 24 000 – 50 000 € ou 26 000 – 54 000 $ par an — ordre de grandeur, taux de change à vérifier au moment du calcul)*

### 3.2 Infrastructure technique

| Poste | Estimation mensuelle | Estimation annuelle |
|---|---|---|
| Hébergement backend + PostgreSQL (Render/Railway, puis migration vers un fournisseur plus robuste si trafic augmente) | 15 000 – 80 000 FCFA | 180 000 – 960 000 FCFA |
| API météo historique/temps réel (au-delà du tier gratuit) | 0 – 50 000 FCFA | 0 – 600 000 FCFA |
| Nom de domaine, certificats, monitoring | 5 000 – 15 000 FCFA | 60 000 – 180 000 FCFA |
| Stockage/CDN pour tuiles cartographiques OSM | 0 – 30 000 FCFA | 0 – 360 000 FCFA |
| **Sous-total infrastructure** | | **≈ 240 000 – 2 100 000 FCFA/an** |

### 3.3 Juridique, conformité et administratif

| Poste | Estimation |
|---|---|
| Enregistrement de l'entreprise (Guichet Unique CI) | ≈ 50 000 – 150 000 FCFA (frais + accompagnement) |
| Déclaration/conformité auprès de l'ARTCI (protection des données) | à budgétiser avec un juriste local — variable |
| Rédaction CGU/politique de confidentialité, contrat-type B2G/B2B | 300 000 – 1 000 000 FCFA (honoraires d'avocat, one-shot) |
| **Sous-total juridique** | **≈ 350 000 – 1 150 000 FCFA (surtout la première année)** |

### 3.4 Marketing et acquisition (si lancement B2C actif)

| Poste | Estimation annuelle |
|---|---|
| Réseaux sociaux, contenu, événements locaux | 500 000 – 2 000 000 FCFA |
| Partenariats visibilité (universités, radios locales type FER FM) | 200 000 – 800 000 FCFA |
| **Sous-total marketing** | **≈ 700 000 – 2 800 000 FCFA/an** |

### 3.5 Pilote matériel (si vision V2 caméras poursuivie)

| Poste | Estimation |
|---|---|
| Caméra + boîtier de calcul embarqué (type Jetson Nano ou équivalent) par carrefour pilote | ≈ 150 000 – 400 000 FCFA par unité |
| Installation/maintenance (2-3 carrefours pilotes) | 500 000 – 1 500 000 FCFA (one-shot) |

*(à ne budgétiser qu'après un premier contrat B2G confirmé — ne pas anticiper cette dépense sans client, vu l'incertitude d'accès au STI mentionnée en section 2)*

### 3.6 Sécurité et conformité (au-delà du MVP technique)

Le CDCFT couvre déjà la sécurité applicative de base (authentification JWT, rôles, HTTPS, throttling, anonymisation des identifiants). Ce qui n'est **pas encore budgété**, et qui devient nécessaire dès le premier client institutionnel ou assureur :

| Poste | Estimation | Quand le budgétiser |
|---|---|---|
| Audit de sécurité / test d'intrusion externe (pentest léger) | 500 000 – 2 000 000 FCFA (prestataire local ou régional) | Avant signature du premier contrat B2G ou avec un assureur |
| Sauvegardes automatisées + plan de reprise après incident | 0 – 100 000 FCFA/mois (souvent inclus dans l'hébergement géré) | Dès la mise en production réelle (au-delà de la démo) |
| Assurance cyber-risque / responsabilité civile professionnelle | variable, à négocier avec un assureur local | Avant toute manipulation de données de citoyens à grande échelle |
| Mise en conformité ARTCI (registre des traitements, politique de confidentialité opposable) | inclus dans le poste juridique (section 3.3), mais à relier explicitement à un plan de sécurité documenté | Avant toute collecte de données citoyennes au-delà du MVP de démo |
| **Sous-total sécurité/conformité (hors juridique déjà compté)** | | **≈ 500 000 – 2 100 000 FCFA (surtout en amont du 1er contrat)** |

Ce n'est pas une dépense à faire dès le lancement du MVP — mais un budget à réserver **avant toute négociation avec un client institutionnel ou un assureur**, qui demandera presque systématiquement une preuve de sérieux sur ce plan.

### 3.7 Total indicatif, première année

| Catégorie | Bas de fourchette | Haut de fourchette |
|---|---|---|
| Équipe | 15 600 000 | 32 400 000 |
| Infrastructure | 240 000 | 2 100 000 |
| Juridique | 350 000 | 1 150 000 |
| Marketing | 700 000 | 2 800 000 |
| Sécurité/conformité (si négociation B2G engagée dans l'année) | 0 | 2 100 000 |
| **Total (hors pilote caméras)** | **≈ 16 900 000 FCFA** | **≈ 40 550 000 FCFA** |

Soit, en ordre de grandeur, **entre 26 000 € et 62 000 €** (≈ 28 000 $ – 67 000 $) pour la première année complète — sans compter la rémunération des fondateurs ni un éventuel pilote caméras. C'est un budget de type "pré-amorçage" (pre-seed), cohérent avec une recherche de subvention ou de petit ticket d'investissement providentiel plutôt qu'une levée de série A.

---

## 4. Stratégie commerciale et modèle de revenus

### 4.1 Ce qu'on peut vendre — et ce qu'on ne doit pas vendre

Un point de vigilance avant tout : **on ne vend pas des données personnelles identifiables**. Ce qui a de la valeur commerciale et qui reste défendable légalement (à faire valider par un juriste), c'est :
- des **agrégats anonymisés** (ex. "score de congestion moyen par segment et par heure", pas "l'historique de déplacement de l'utilisateur X")
- des **indicateurs dérivés** (indice de congestion façon TomTom Traffic Index, mais hyper-local à Abidjan)
- un **accès API** aux prédictions, pas aux données brutes des utilisateurs

### 4.1 bis — La sécurité comme argument de vente, pas seulement comme coût

Face à un client B2G ou un assureur, la sécurité n'est pas qu'une ligne de dépense (section 3.6) — c'est un argument différenciant à mettre en avant activement dans le pitch commercial :
- **Explicabilité + traçabilité des sources** (déjà dans le CDCFT) rassure un acheteur institutionnel méfiant des boîtes noires importées.
- **Séparation claire des rôles et permissions** (citoyen/autorité) montre que les données sensibles (signalements, position) ne sont pas exposées sans contrôle.
- Être capable de dire concrètement *"voici notre politique de conservation des données, voici qui a accès à quoi, voici notre plan en cas d'incident"* est souvent ce qui débloque une signature côté administration publique, plus que le prix.
- À l'inverse, ne jamais promettre un niveau de sécurité (certification, audit) qui n'a pas réellement été fait — un audit annoncé mais non réalisé est un risque réputationnel plus grave que l'absence d'audit assumée.

### 4.2 Sources de revenus possibles

| Modèle | Description | Client type |
|---|---|---|
| **Licence SaaS B2G** | Abonnement pour le dashboard autorités (par ville, par district, ou par nombre de segments couverts) | Ministère des Transports CI, District Autonome d'Abidjan, mairies |
| **API B2B de prédiction** | Accès à `predict_congestion` en marque blanche, facturé à l'usage (par appel API ou par abonnement mensuel) | Logistique, livraison, VTC |
| **Licence de données agrégées / indice de congestion** | Un "indice CityFlow" vendu comme un TomTom Traffic Index local, utile pour la recherche, l'urbanisme, les études d'impact | Assureurs, promoteurs immobiliers, bureaux d'études urbanisme, ONG/bailleurs |
| **Freemium citoyen** | App gratuite de base, fonctionnalités premium payantes une fois construites (itinéraire optimisé, alertes prioritaires, historique personnel) | Citoyens à fort usage (chauffeurs VTC, livreurs indépendants) |
| **Publicité locale géolocalisée** | Bannière/notification sponsorisée non intrusive côté app citoyenne (ex. un commerce signalé sur un trajet alternatif en cas de bouchon) | Commerces locaux, enseignes |
| **Subventions et financements non dilutifs** | Appels à projets villes intelligentes, transition numérique, résilience climatique | AFD, Banque Mondiale, PNUD, ONU-Habitat, ministère du Numérique |
| **Licence en marque blanche pour d'autres villes** | Réplication du modèle (Bouaké, Yamoussoukro, puis Dakar, Cotonou, Lomé) une fois la preuve de concept validée à Abidjan | Autres municipalités ouest-africaines |

### 4.3 Clients potentiels concrets (à prioriser dans cet ordre pour un premier contrat)

1. **District Autonome d'Abidjan / Ministère des Transports** — déjà propriétaire du STI existant ; un partenariat (même non exclusif) donnerait accès à de vraies données trafic et de la légitimité institutionnelle. C'est le client le plus stratégique, mais le cycle de vente le plus long.
2. **Assureurs locaux (NSIA, SUNU Assurances, Allianz CI, SAHAM)** — la cartographie du risque d'inondation par segment est directement exploitable pour la tarification de produits d'assurance auto/habitation en zone à risque.
3. **Plateformes de VTC/livraison actives à Abidjan (Yango, Gozem, Jumia Food)** — client B2B au cycle de vente plus court, avec un besoin direct de prédiction de congestion pour optimiser leurs flottes.
4. **Opérateurs télécoms (Orange CI, MTN CI)** — partenariat possible pour la diffusion d'alertes par SMS en zones sans smartphone/internet, ou échange de données de densité de trafic mobile contre visibilité.
5. **Bailleurs internationaux (AFD, Banque Mondiale, PNUD)** — pas un "client" au sens commercial, mais une source de financement non dilutif crédible pour un projet à impact social + climatique, qui peut aussi ouvrir des portes institutionnelles.
6. **Universités et centres de recherche (INP-HB, Université Félix Houphouët-Boigny)** — partenariat data/recherche à faible revenu direct, mais utile pour la crédibilité scientifique du modèle IA.

### 4.4 Recommandation de séquencement

Plutôt que d'attaquer les 6 segments en même temps :

1. **Court terme (0-6 mois)** : décrocher un pilote gratuit ou à très faible coût avec **une seule autorité locale** (mairie d'arrondissement plutôt que le ministère directement, cycle plus court) pour obtenir une référence et des retours d'usage réels.
2. **Moyen terme (6-12 mois)** : approcher un ou deux clients B2B (VTC/logistique) en parallèle, qui ont un cycle de décision plus rapide et peuvent générer du revenu pendant que la négociation institutionnelle avance.
3. **Long terme (12+ mois)** : une fois une référence B2G obtenue, utiliser cette preuve sociale pour candidater à des financements bailleurs (AFD, Banque Mondiale) et envisager la réplication vers d'autres villes.

---

## 5. Comment obtenir des données réelles sans (forcément) payer

C'est la faiblesse la plus critique identifiée en section 2 (trafic simulé), et la bonne nouvelle est qu'il existe plusieurs voies d'accès à des données réelles qui ne passent pas par un chèque :

### 5.1 Le troc plutôt que l'achat

La plupart des acteurs qui détiennent une vraie donnée trafic n'ont pas besoin d'argent — ils ont besoin de **service ou de visibilité** :
- **Plateformes VTC/livraison (Yango, Gozem, Jumia Food)** : proposez-leur un accès gratuit à l'API de prédiction en échange de données agrégées et anonymisées de durée de trajet sur leurs courses passées. Elles y gagnent une fonctionnalité, vous y gagnez un vrai historique de congestion sans négociation financière.
- **Opérateurs télécom (Orange CI, MTN CI)** : ils publient parfois des données de densité de population/mobilité agrégées (issues des antennes-relais) dans le cadre de programmes "Data for Good" ou de partenariats académiques/humanitaires — à solliciter directement via leurs fondations ou directions RSE, pas leurs services commerciaux.
- **Le STI lui-même (Ministère des Transports)** : plutôt que de demander un accès direct au flux vidéo (sensible), proposez un échange plus simple à accepter : votre dashboard de visualisation en échange d'un export agrégé et anonymisé de leurs statistiques de circulation déjà traitées par leurs agents à Treichville.

### 5.2 Les données ouvertes et communautaires (déjà en partie exploitées)

- **OpenStreetMap / HDX** (déjà utilisé pour la géométrie) : la communauté OSM locale (via HOT — Humanitarian OpenStreetMap Team) organise parfois des "mapathons" ; s'y associer permet d'améliorer gratuitement la précision des données géographiques, avec l'aide de cartographes locaux.
- **API météo historique gratuites** (déjà utilisées) : suffisantes tant que le volume reste faible ; à ne payer que si vous dépassez les quotas gratuits en production.
- **Portails open data institutionnels** (ex. données du Ministère du Numérique, de l'INS - Institut National de la Statistique) : à vérifier régulièrement, ces portails s'enrichissent progressivement en Côte d'Ivoire et peuvent publier des données de mobilité ou d'infrastructure exploitables sans coût.

### 5.3 Faire générer la donnée réelle par vos propres utilisateurs (le signalement, mais en mieux)

Le signalement citoyen (déjà dans le MVP) *est* une source de donnée réelle — le problème n'est pas son existence, mais son volume trop faible pour remplacer un historique de trafic. Pour l'augmenter sans payer :
- **Programme d'ambassadeurs communautaires non rémunérés** : recruter des utilisateurs power (chauffeurs de VTC, conducteurs de gbaka/wôrô-wôrô, associations de quartier) qui signalent en échange de reconnaissance (badge, statut, mise en avant) plutôt que d'argent.
- **Partenariats universitaires** (INP-HB, Université Félix Houphouët-Boigny) : proposer un projet de collecte de données de mobilité comme sujet de mémoire ou de projet étudiant encadré — les étudiants ont besoin de sujets concrets, vous avez besoin de bras pour la collecte.
- **Gamification légère** : un classement des contributeurs les plus actifs (sans récompense monétaire), qui coûte du développement mais pas de budget récurrent.

### 5.4 Les financements non dilutifs comme détour pour financer l'accès aux données

Si l'accès reste payant dans certains cas (ex. une API commerciale de trafic tierce), une subvention (AFD, Banque Mondiale, PNUD — déjà mentionnées en section 4.2) peut financer spécifiquement ce poste sans diluer le capital de la startup ni sortir de trésorerie propre. C'est souvent plus réaliste de présenter "financer l'accès à une donnée réelle de trafic" comme objet précis d'une subvention villes intelligentes, plutôt que de chercher à payer cet accès sur fonds propres dès la première année.

### 5.5 Ce qu'il ne faut pas faire

Éviter la tentation de scraper des données tierces sans autorisation (ex. extraire discrètement les temps de trajet de Google Maps ou Waze via leurs APIs publiques à des fins autres que celles prévues dans leurs conditions d'utilisation) : c'est risqué juridiquement (violation des CGU, possible blocage), et fragile techniquement (dépendance à un concurrent direct qui peut couper l'accès à tout moment).

---

## 6. Sécurité — état des lieux et ce qu'il reste à faire

**Oui, la sécurité a été intégrée**, mais à deux niveaux différents qu'il faut distinguer :

- **Niveau applicatif (déjà couvert dans le CDCFT et la feuille de route de prompts)** : authentification JWT, rôles citoyen/autorité, HTTPS en production, anonymisation basique des identifiants dans les données simulées, throttling anti-abus sur les signalements, traçabilité des sources de données (licence OSM, provenance météo). C'est suffisant pour un MVP de compétition.
- **Niveau entreprise (pas encore couvert avant cette section)** : audit de sécurité externe, plan de reprise après incident, assurance cyber, conformité ARTCI documentée au-delà d'une simple mention. Ce niveau n'est pas nécessaire pour gagner le vibeathon, mais devient nécessaire dès la première négociation avec un client institutionnel ou un assureur — je l'ai donc ajouté au budget (section 3.6) et à la stratégie commerciale (section 4.1 bis) dans cette mise à jour.

**Ce qui resterait à faire, dans l'ordre, si le projet devient une vraie startup :**
1. Documenter une politique de sécurité et de confidentialité simple mais réelle (pas un template générique copié).
2. Réaliser un audit de sécurité léger dès qu'un premier client institutionnel est en négociation sérieuse (pas avant, pour ne pas dépenser inutilement).
3. Souscrire une assurance cyber-risque uniquement une fois des données citoyennes réelles (au-delà de la démo) sont collectées à un volume significatif.

---

## Résumé exécutif

CityFlow AI a une vraie pertinence locale et une rigueur d'exécution rare pour un projet de cette taille, mais son modèle économique reste entièrement à valider : le produit actuel est une preuve de concept technique, pas encore une preuve de traction commerciale. Le budget de la première année (≈ 17 à 40 millions FCFA hors pilote caméras) est cohérent avec un stade pré-amorçage. La priorité stratégique n'est pas d'ajouter des fonctionnalités, mais de sécuriser **un premier partenariat de référence** — institutionnel ou B2B — qui validera à la fois la donnée réelle de trafic (aujourd'hui absente, mais accessible par le troc et les partenariats plutôt que par l'achat, voir section 5) et la volonté de payer. La sécurité applicative de base est déjà en place ; sa montée en maturité (audit, assurance cyber) doit être planifiée juste avant la première négociation institutionnelle, pas avant.
