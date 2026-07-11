from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from mobility.throttles import PredictionsReadThrottle
from .corridors import CORRIDORS, generer_conseil


@api_view(['GET'])
@permission_classes([AllowAny])
@throttle_classes([PredictionsReadThrottle])
def conseil_trajet(request):
    """
    GET /api/conseil/                  — liste des corridors disponibles
    GET /api/conseil/?corridor=<key>   — analyse et conseil pour ce corridor
    """
    corridor_key = request.query_params.get('corridor')

    if not corridor_key:
        # Retourner la liste des corridors sans appel ML
        corridors_list = [
            {
                'key': key,
                'nom': conf['nom'],
                'depart': conf['depart'],
                'arrivee': conf['arrivee'],
                'description': conf['description'],
                'duree_base_min': conf['duree_base_min'],
            }
            for key, conf in CORRIDORS.items()
        ]
        return Response({'corridors': corridors_list})

    if corridor_key not in CORRIDORS:
        return Response(
            {
                'erreur': f"Corridor '{corridor_key}' inconnu.",
                'corridors_valides': list(CORRIDORS.keys()),
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    result = generer_conseil(corridor_key)
    return Response(result)
