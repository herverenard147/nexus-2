"""
Corridors emblématiques d'Abidjan — segments réels issus de la DB OSM.

Les IDs de segments ont été vérifiés sur la DB locale (SQLite) et en prod
(PostgreSQL, 4206 segments importés via import_osm_segments).

Impact temps : qualification qualitative dérivée du score de congestion.
Aucune durée en minutes n'est produite — nous ne disposons pas des distances
ni des vitesses réelles par tronçon.
"""

CORRIDORS = {
    'cocody_plateau': {
        'nom': 'Cocody → Plateau',
        'depart': 'Cocody (Boulevard Latrille)',
        'arrivee': 'Plateau (Centre Administratif)',
        'description': 'Boulevard Latrille → Boulevard de France → Pont Félix Houphouët-Boigny',
        'alternative': 'Via Boulevard de France sud et Pont Général de Gaulle',
        'segments': [7, 8, 270, 34, 145, 15, 16],
    },
    'adjame_plateau': {
        'nom': 'Adjamé → Plateau',
        'depart': 'Adjamé (Autoroute du Nord)',
        'arrivee': 'Plateau (Centre Administratif)',
        'description': 'Autoroute du Nord → Boulevard Lagunaire → Plateau',
        'alternative': 'Via Boulevard de la Paix (Adjamé marché)',
        'segments': [19, 47, 48, 25, 40, 122],
    },
    'plateau_treichville': {
        'nom': 'Plateau → Treichville',
        'depart': 'Plateau (Centre Administratif)',
        'arrivee': 'Treichville (CHU)',
        'description': 'Pont Général de Gaulle → Rond-Point du CHU de Treichville',
        'alternative': 'Via Pont Félix Houphouët-Boigny (souvent moins chargé)',
        'segments': [762, 1016, 744],
    },
    'yopougon_plateau': {
        'nom': 'Yopougon → Plateau',
        'depart': "Yopougon (Route de Prison, N'Dotré)",
        'arrivee': 'Plateau (Centre Administratif)',
        'description': "Route de Prison → Boulevard Hortense Aka Anghui → Boulevard Lagunaire → Pont FHB",
        'alternative': "Via Autoroute du Nord (Adjamé) — plus direct aux heures creuses",
        'segments': [74, 1809, 1, 12, 25, 15],
    },
}

_ETAT_LABELS = [
    (85, 'très congestionné'),
    (70, 'congestionné'),
    (50, 'ralenti'),
    (30, 'légèrement ralenti'),
    (0,  'fluide'),
]

_IMPACT_TEMPS = {
    'fluide':             'temps de parcours normal',
    'légèrement ralenti': 'trajet légèrement rallongé',
    'ralenti':            'trajet sensiblement rallongé',
    'congestionné':       'trajet fortement rallongé par la congestion',
    'très congestionné':  'trajet très fortement rallongé — forte congestion',
}


def _etat_from_score(score):
    for seuil, label in _ETAT_LABELS:
        if score >= seuil:
            return label
    return 'fluide'


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
        etat = _etat_from_score(score)
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
            'nom': conf['nom'],
            'depart': conf['depart'],
            'arrivee': conf['arrivee'],
            'description': conf['description'],
            'etat_global': 'inconnu',
            'score_moyen': 0,
            'impact_temps': 'données insuffisantes',
            'conseil': f"Données insuffisantes pour le corridor {conf['nom']}.",
            'points_ralentissement': [],
            'impact_meteo': None,
            'alternative': conf['alternative'],
            'segments': [],
            'genere_a': timezone.now().isoformat(),
        }

    score_moyen = round(sum(scores) / len(scores))
    etat_global = _etat_from_score(score_moyen)
    impact_temps = _IMPACT_TEMPS[etat_global]

    points = [r['nom'] for r in resultats if r['score'] >= 55]
    impact_meteo = impacts_meteo[0] if impacts_meteo else None

    # ── Construction du texte de conseil ──────────────────────────────────────
    parties = []

    # État global + impact temps
    if etat_global == 'fluide':
        parties.append(
            f"Trajet {conf['nom']} : circulation fluide (score {score_moyen}/100) — {impact_temps}."
        )
    elif etat_global == 'légèrement ralenti':
        parties.append(
            f"Trajet {conf['nom']} : légèrement ralenti (score {score_moyen}/100) — {impact_temps}."
        )
    elif etat_global == 'ralenti':
        parties.append(
            f"Trajet {conf['nom']} : conditions ralenties (score {score_moyen}/100) — {impact_temps}."
        )
    elif etat_global == 'congestionné':
        parties.append(
            f"Trajet {conf['nom']} : fort trafic signalé (score {score_moyen}/100) — {impact_temps}."
        )
    else:
        parties.append(
            f"Trajet {conf['nom']} : trafic très dense (score {score_moyen}/100) — {impact_temps}."
        )

    # Points de ralentissement
    if points:
        noms_str = ', '.join(dict.fromkeys(points))
        parties.append(f"Ralentissements détectés sur : {noms_str}.")

    # Impact météo
    if impact_meteo == 'fort':
        parties.append(
            "Pluie forte active sur des zones inondables — prudence, chaussée glissante."
        )
    elif impact_meteo == 'modéré':
        parties.append("Pluie modérée en cours — temps de parcours allongé.")

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
        'impact_temps': impact_temps,
        'conseil': conseil_texte,
        'points_ralentissement': list(dict.fromkeys(points)),
        'impact_meteo': impact_meteo,
        'alternative': conf['alternative'],
        'segments': resultats,
        'genere_a': timezone.now().isoformat(),
    }
