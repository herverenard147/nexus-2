import os
import subprocess
import traceback
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.db import connection
from django.views.decorators.csrf import csrf_exempt

_SEED_TOKEN = os.environ.get('SEED_TOKEN', '')


def health(request):
    try:
        with connection.cursor() as c:
            c.execute("SELECT 1")
        from django.conf import settings
        from mobility.models import RoadSegment, Prediction
        from environment.models import WeatherEvent
        return JsonResponse({
            'status': 'ok',
            'db_engine': settings.DATABASES['default']['ENGINE'],
            'db_name': str(settings.DATABASES['default'].get('NAME', '')),
            'segments': RoadSegment.objects.count(),
            'predictions': Prediction.objects.count(),
            'weather_events': WeatherEvent.objects.count(),
        })
    except Exception as e:
        return JsonResponse({'status': 'error', 'detail': str(e),
                             'trace': traceback.format_exc()}, status=500)


@csrf_exempt
def seed(request):
    """Déclenche le pipeline de données. Protégé par SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN or request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)

    from mobility.models import RoadSegment
    if RoadSegment.objects.exists():
        return JsonResponse({'status': 'skip', 'message': 'Données déjà présentes'})

    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    geojson = '/app/docs/data/grand_abidjan.geojson'
    meteo = '/app/docs/data/meteo_abidjan.json'

    # Étapes rapides (< 2 min au total) — le gros historique est lancé en arrière-plan
    quick_steps = [
        ['python', 'manage.py', 'import_osm_segments', '--fichier', geojson],
        ['python', 'manage.py', 'import_weather_history', '--fichier', meteo],
        ['python', 'manage.py', 'seed_demo_reports', '--seed', '42'],
        ['python', 'manage.py', 'recompute_predictions'],
    ]
    log = []
    for cmd in quick_steps:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=base, timeout=110)
            log.append({'cmd': ' '.join(cmd[2:]), 'ok': result.returncode == 0,
                        'out': result.stdout[-500:], 'err': result.stderr[-200:]})
            if result.returncode != 0:
                return JsonResponse({'status': 'error', 'step': cmd[2], 'log': log}, status=500)
        except Exception as e:
            return JsonResponse({'status': 'error', 'step': cmd[2], 'detail': str(e), 'log': log}, status=500)

    # Historique trafic (3M lignes) en arrière-plan — n'attend pas la fin
    subprocess.Popen(
        ['python', 'manage.py', 'seed_demo_data', '--users', '100', '--days', '30', '--seed', '42'],
        cwd=base, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    log.append({'cmd': 'seed_demo_data (lancé en arrière-plan)', 'ok': True, 'out': '', 'err': ''})

    return JsonResponse({'status': 'ok', 'log': log})


urlpatterns = [
    path('health/', health),
    path('seed/', seed),
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/', include('mobility.urls')),
    path('api/weather/', include('environment.urls')),
    path('api/reports/', include('reports.urls')),
    path('api/dashboard/', include('dashboard.urls')),
]
