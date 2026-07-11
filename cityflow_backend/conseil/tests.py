from unittest.mock import patch
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from mobility.models import RoadSegment
from .corridors import CORRIDORS, generer_conseil


def _make_segment(id_=None, nom='Test', zone='Test', inondable=False):
    kwargs = dict(nom=nom, latitude=5.3, longitude=-3.9, zone=zone,
                  zone_inondable=inondable, source_geometrie='osm')
    if id_ is not None:
        kwargs['id'] = id_
    return RoadSegment.objects.create(**kwargs)


class ConseilCorrridorsUnitTests(TestCase):
    """Tests unitaires du générateur de conseils (pas de réseau)."""

    def setUp(self):
        # Créer les segments réels utilisés par les corridors
        for seg_id in [7, 8, 270, 34, 145, 15, 16]:
            _make_segment(id_=seg_id, nom=f'Segment {seg_id}', zone='TestZone')

    def test_liste_corridors_non_vide(self):
        self.assertGreater(len(CORRIDORS), 0)

    def test_corridors_ont_champs_requis(self):
        for key, conf in CORRIDORS.items():
            for champ in ('nom', 'depart', 'arrivee', 'segments', 'alternative'):
                self.assertIn(champ, conf, f'Corridor {key} manque le champ {champ}')

    def test_conseil_corridor_valide(self):
        result = generer_conseil('cocody_plateau')
        self.assertIsNotNone(result)
        self.assertEqual(result['corridor'], 'cocody_plateau')

    def test_conseil_champs_obligatoires(self):
        result = generer_conseil('cocody_plateau')
        for champ in ('conseil', 'etat_global', 'score_moyen', 'impact_temps',
                      'segments', 'points_ralentissement', 'genere_a'):
            self.assertIn(champ, result, f'Champ manquant : {champ}')

    def test_conseil_corridor_inconnu_retourne_none(self):
        result = generer_conseil('trajet_inexistant')
        self.assertIsNone(result)

    def test_score_moyen_dans_plage(self):
        result = generer_conseil('cocody_plateau')
        self.assertGreaterEqual(result['score_moyen'], 0)
        self.assertLessEqual(result['score_moyen'], 100)

    def test_impact_temps_est_qualificatif(self):
        """impact_temps doit être une chaîne qualitative, sans chiffre."""
        result = generer_conseil('cocody_plateau')
        impact = result['impact_temps']
        self.assertIsInstance(impact, str)
        self.assertGreater(len(impact), 0)
        # Ne doit contenir aucun chiffre (pas de minutes inventées)
        self.assertFalse(any(c.isdigit() for c in impact), f'Chiffre trouvé dans impact_temps : {impact}')

    def test_conseil_congestion_inclut_alternative(self):
        """Quand congestionné → le texte de conseil mentionne une alternative."""
        for seg_id in [7, 8, 270, 34, 145, 15, 16]:
            RoadSegment.objects.filter(id=seg_id).update(zone_inondable=False)

        # Forcer un score élevé en patchant le predictor
        from mobility.ml import predictor as pred_mod
        import numpy as np
        original = pred_mod._lookup
        # Lookup table tous à 80 → congestionné
        pred_mod._lookup = np.full((24, 7), 80.0, dtype=np.float32)
        try:
            result = generer_conseil('cocody_plateau')
            self.assertIn('Alternative', result['conseil'])
        finally:
            pred_mod._lookup = original

    def test_segments_list_contient_score_et_etat(self):
        result = generer_conseil('cocody_plateau')
        for seg in result['segments']:
            self.assertIn('id', seg)
            self.assertIn('score', seg)
            self.assertIn('etat', seg)
            self.assertIn('nom', seg)


class ConseilAPITests(APITestCase):
    """Tests de l'endpoint GET /api/conseil/."""

    def setUp(self):
        # Créer les segments des 4 corridors pour éviter les ValueError
        all_ids = set()
        for conf in CORRIDORS.values():
            all_ids.update(conf['segments'])
        for seg_id in all_ids:
            _make_segment(id_=seg_id, nom=f'Seg {seg_id}', zone='TestZone')

    def test_liste_corridors(self):
        res = self.client.get('/api/conseil/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertIn('corridors', res.data)
        self.assertEqual(len(res.data['corridors']), len(CORRIDORS))

    def test_liste_corridors_champs(self):
        res = self.client.get('/api/conseil/')
        premier = res.data['corridors'][0]
        for champ in ('key', 'nom', 'depart', 'arrivee', 'description'):
            self.assertIn(champ, premier)

    def test_conseil_corridor_valide(self):
        res = self.client.get('/api/conseil/?corridor=cocody_plateau')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.assertEqual(res.data['corridor'], 'cocody_plateau')
        self.assertIn('conseil', res.data)
        self.assertIn('score_moyen', res.data)

    def test_conseil_corridor_inconnu_404(self):
        res = self.client.get('/api/conseil/?corridor=axe_inexistant')
        self.assertEqual(res.status_code, status.HTTP_404_NOT_FOUND)
        self.assertIn('corridors_valides', res.data)

    def test_tous_corridors_retournent_200(self):
        for key in CORRIDORS:
            res = self.client.get(f'/api/conseil/?corridor={key}')
            self.assertEqual(res.status_code, status.HTTP_200_OK,
                             f'Corridor {key} a retourné {res.status_code}')
