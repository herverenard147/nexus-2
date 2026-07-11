"""
Corridors emblématiques d'Abidjan — segments réels issus de la DB OSM.

Chaque corridor définit un itinéraire ordonné par des IDs de RoadSegment
présents en production. Les IDs ont été vérifiés sur la DB locale (SQLite)
et en prod (PostgreSQL, 4206 segments importés via import_osm_segments).

Ajustement temps : score moyen → multiplicateur de durée
  < 30  : x1.0  (fluide)
  30-49 : x1.3  (légèrement ralenti)
  50-69 : x1.7  (ralenti)
  70-84 : x2.2  (congestionné)
  85+   : x3.0  (très congestionné)
"""

CORRIDORS = {
    'cocody_plateau': {
        'nom': 'Cocody → Plateau',
        'depart': 'Cocody (Boulevard Latrille)',
        'arrivee': 'Plateau (Centre Administratif)',
        'description': 'Boulevard Latrille → Boulevard de France → Pont Félix Houphouët-Boigny',
        'alternative': 'Via Boulevard de France sud et Pont Général de Gaulle',
        'duree_base_min': 20,
        'segments': [7, 8, 270, 34, 145, 15, 16],
    },
    'adjame_plateau': {
        'nom': 'Adjamé → Plateau',
        'depart': 'Adjamé (Autoroute du Nord)',
        'arrivee': 'Plateau (Centre Administratif)',
        'description': 'Autoroute du Nord → Boulevard Lagunaire → Plateau',
        'alternative': 'Via Boulevard de la Paix (Adjamé marché)',
        'duree_base_min': 15,
        'segments': [19, 47, 48, 25, 40, 122],
    },
    'plateau_treichville': {
        'nom': 'Plateau → Treichville',
        'depart': 'Plateau (Centre Administratif)',
        'arrivee': 'Treichville (CHU)',
        'description': 'Pont Général de Gaulle → Rond-Point du CHU de Treichville',
        'alternative': 'Via Pont Félix Houphouët-Boigny (plus long, souvent moins chargé)',
        'duree_base_min': 10,
        'segments': [762, 1016, 744],
    },
    'yopougon_plateau': {
        'nom': 'Yopougon → Plateau',
        'depart': "Yopougon (Route de Prison, N'Dotré)",
        'arrivee': 'Plateau (Centre Administratif)',
        'description': "Route de Prison → Boulevard Hortense Aka Anghui → Boulevard Lagunaire → Pont FHB",
        'alternative': "Via Autoroute du Nord (Adjamé) — plus court aux heures creuses",
        'duree_base_min': 35,
        'segments': [74, 1809, 1, 12, 25, 15],
    },
}

_ETAT_LABELS = [
    (85, 'très congestionné', 3.0),
    (70, 'congestionné',      2.2),
    (50, 'ralenti',           1.7),
    (30, 'légèrement ralenti', 1.3),
    (0,  'fluide',            1.0),
]


def _etat_from_score(score):
    for seuil, label, mult in _ETAT_LABELS:
        if score >= seuil:
            return label, mult
    return 'fluide', 1.0


def generer_conseil(corridor_key):
    """
    Appelle predict_congestion() pour chaque segment du corridor,
    puis génère un texte de conseil en français (règles pures, pas de LLM).

    Retourne un dict prêt à sérialiser en JSON.
    """
    from mobility.ml.predictor import predict_congestion
    from mobility.models import RoadSegment
    from django.utils import timezone

    if corridor_key not in CORRIDORS:
        return None

    conf = CORRIDORS[corridor_key]
    segment_ids = conf['segments']

    # Récupérer les noms en une seule requête
    noms = {
        s.id: s.nom
        for s in RoadSegment.objects.filter(id__in=segment_ids).only('id', 'nom')
    }

    resultats = []
    scores = []
    impacts_meteo = []

    for seg_id in segment_ids:
        try:
            pred = predict_congestion(seg_id)
        except ValueError:
            continue
        score = pred['score']
        facteurs = pred['facteurs']
        etat, _ = _etat_from_score(score)
        resultats.append({
            'id': seg_id,
            'nom': noms.get(seg_id, f'Segment {seg_id}'),
            'score': score,
            'etat': etat,
        })
        scores.append(score)
        if facteurs.get('effet_meteo') not in ('aucun', None):
            impacts_meteo.append(facteurs['effet_meteo'])

    if not scores:
        return {
            'corridor': corridor_key,
            **conf,
            'etat_global': 'inconnu',
            'score_moyen': 0,
            'conseil': f"Données insuffisantes pour le corridor {conf['nom']}.",
            'points_ralentissement': [],
            'impact_meteo': None,
            'duree_estimee_min': conf['duree_base_min'],
            'segments': [],
            'genere_a': timezone.now().isoformat(),
        }

    score_moyen = round(sum(scores) / len(scores))
    etat_global, mult = _etat_from_score(score_moyen)
    duree = round(conf['duree_base_min'] * mult)

    points = [r['nom'] for r in resultats if r['score'] >= 55]
    impact_meteo = impacts_meteo[0] if impacts_meteo else None

    # ── Construction du texte de conseil ──────────────────────────────────────
    parties = []

    # État global
    if etat_global == 'fluide':
        parties.append(
            f"Trajet {conf['nom']} : circulation fluide en ce moment (score {score_moyen}/100)."
        )
    elif etat_global == 'légèrement ralenti':
        parties.append(
            f"Trajet {conf['nom']} : légèrement ralenti (score {score_moyen}/100)."
        )
    elif etat_global == 'ralenti':
        parties.append(
            f"Trajet {conf['nom']} : conditions ralenties (score {score_moyen}/100)."
        )
    elif etat_global == 'congestionné':
        parties.append(
            f"Trajet {conf['nom']} : fort trafic signalé (score {score_moyen}/100)."
        )
    else:
        parties.append(
            f"Trajet {conf['nom']} : trafic très dense (score {score_moyen}/100)."
        )

    # Points de ralentissement
    if points:
        noms_str = ', '.join(dict.fromkeys(points))  # déduplique en gardant l'ordre
        parties.append(f"Ralentissements détectés sur : {noms_str}.")

    # Impact météo
    if impact_meteo == 'fort':
        parties.append(
            "Pluie forte active sur des zones inondables — prudence, chaussée glissante."
        )
    elif impact_meteo == 'modéré':
        parties.append("Pluie modérée en cours — temps de parcours allongé.")

    # Durée estimée
    if etat_global == 'fluide':
        parties.append(f"Durée estimée : {duree} min.")
    else:
        parties.append(
            f"Durée estimée : ~{duree} min (contre {conf['duree_base_min']} min sans trafic)."
        )

    # Alternative
    if etat_global in ('congestionné', 'très congestionné', 'ralenti'):
        parties.append(f"Alternative recommandée : {conf['alternative']}.")

    conseil_texte = ' '.join(parties)

    return {
        'corridor': corridor_key,
        'nom': conf['nom'],
        'depart': conf['depart'],
        'arrivee': conf['arrivee'],
        'description': conf['description'],
        'etat_global': etat_global,
        'score_moyen': score_moyen,
        'conseil': conseil_texte,
        'points_ralentissement': list(dict.fromkeys(points)),
        'impact_meteo': impact_meteo,
        'duree_estimee_min': duree,
        'duree_base_min': conf['duree_base_min'],
        'alternative': conf['alternative'],
        'segments': resultats,
        'genere_a': timezone.now().isoformat(),
    }
