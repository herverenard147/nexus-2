import os
import subprocess
import traceback
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.db import connection
from django.views.decorators.csrf import csrf_exempt

_SEED_TOKEN = os.environ.get('SEED_TOKEN')


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
    """Déclenche le pipeline de données (idempotent). Protégé par SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN:
        return JsonResponse(
            {'error': "Variable d'environnement SEED_TOKEN non configurée sur le serveur."},
            status=500,
        )
    if request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)

    from mobility.models import RoadSegment, Prediction, TrafficRecord
    from environment.models import WeatherEvent
    from reports.models import Report
    from accounts.models import User

    segments_exist = RoadSegment.objects.exists()
    weather_exist = WeatherEvent.objects.exists()
    citizens_exist = User.objects.filter(role='citoyen').exists()
    reports_exist = Report.objects.exists()
    predictions_exist = Prediction.objects.exists()
    history_exist = TrafficRecord.objects.exists()

    if segments_exist and weather_exist and citizens_exist and reports_exist and predictions_exist:
        return JsonResponse({'status': 'skip', 'message': 'Données déjà présentes',
                             'segments': RoadSegment.objects.count(),
                             'predictions': Prediction.objects.count()})

    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    geojson = '/app/docs/data/grand_abidjan.geojson'
    meteo = '/app/docs/data/meteo_abidjan.json'
    log = []

    # 1. Comptes (admin + citoyens) — nécessaires pour seed_demo_reports
    if not User.objects.filter(role='autorite').exists():
        admin_pwd = os.environ.get('ADMIN_PASSWORD')
        if not admin_pwd:
            return JsonResponse(
                {'status': 'error',
                 'detail': "Variable d'environnement ADMIN_PASSWORD manquante."},
                status=500,
            )
        User.objects.create_superuser('admin', 'admin@cityflow.ci', admin_pwd, role='autorite')
        log.append({'cmd': 'create admin', 'ok': True, 'out': 'admin créé', 'err': ''})
    if not citizens_exist:
        for i in range(5):
            User.objects.create_user(f'citoyen{i}', f'c{i}@cityflow.ci',
                                     f'Cf!{i}xB9@qZ', role='citoyen')
        log.append({'cmd': 'create citoyens', 'ok': True, 'out': '5 citoyens créés', 'err': ''})

    # 2. Segments OSM si absent
    steps = []
    if not segments_exist:
        steps.append(['python', 'manage.py', 'import_osm_segments', '--fichier', geojson])
    if not weather_exist:
        steps.append(['python', 'manage.py', 'import_weather_history', '--fichier', meteo])
    if not reports_exist:
        steps.append(['python', 'manage.py', 'seed_demo_reports', '--seed', '42'])
    if not predictions_exist:
        steps.append(['python', 'manage.py', 'recompute_predictions'])

    for cmd in steps:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=base, timeout=110)
            log.append({'cmd': ' '.join(cmd[2:]), 'ok': result.returncode == 0,
                        'out': result.stdout[-500:], 'err': result.stderr[-200:]})
            if result.returncode != 0:
                return JsonResponse({'status': 'error', 'step': cmd[2], 'log': log}, status=500)
        except Exception as e:
            return JsonResponse({'status': 'error', 'step': cmd[2], 'detail': str(e), 'log': log}, status=500)

    # 3. Historique trafic léger en arrière-plan — n'attend pas la fin
    if not history_exist:
        subprocess.Popen(
            ['python', 'manage.py', 'seed_traffic_minimal', '--seed', '42'],
            cwd=base, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        log.append({'cmd': 'seed_traffic_minimal (arrière-plan)', 'ok': True, 'out': '', 'err': ''})

    return JsonResponse({'status': 'ok', 'log': log})


@csrf_exempt
def seed_traffic(request):
    """Lance seed_traffic_minimal + recompute_predictions en arrière-plan. Protégé SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN or request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.Popen(
        ['python', 'manage.py', 'seed_traffic_minimal', '--clear', '--seed', '42'],
        cwd=base, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
    )
    return JsonResponse({
        'status': 'ok',
        'message': (
            'seed_traffic_minimal lancé en arrière-plan (~60 s). '
            'Appelez ensuite /recompute/ pour rafraîchir les prédictions.'
        ),
    })


@csrf_exempt
def recompute(request):
    """Recalcule toutes les prédictions en arrière-plan (~3 min). Protégé SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN or request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.Popen(
        ['python', 'manage.py', 'recompute_predictions'],
        cwd=base, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return JsonResponse({
        'status': 'ok',
        'message': 'recompute_predictions lancé en arrière-plan (~3 min pour 4206 segments).',
    })


@csrf_exempt
def seed_and_recompute(request):
    """Chaîne seed_traffic_minimal + recompute_predictions en arrière-plan. Protégé SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN or request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.Popen(
        ['bash', '-c',
         'python manage.py seed_traffic_minimal --clear --seed 42 '
         '&& python manage.py recompute_predictions'],
        cwd=base, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    return JsonResponse({
        'status': 'ok',
        'message': (
            'Pipeline lancé en arrière-plan : seed (~60 s) puis recompute (~3 min). '
            'Vérifiez /api/predictions/ dans 5 min.'
        ),
    })



@csrf_exempt
def fix_zones(request):
    """Corrige zone=nom_de_rue → commune. Synchrone (~5 s). Protégé SEED_TOKEN."""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST requis'}, status=405)
    if not _SEED_TOKEN or request.headers.get('X-Seed-Token') != _SEED_TOKEN:
        return JsonResponse({'error': 'Token invalide'}, status=403)
    base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    try:
        result = subprocess.run(
            ['python', 'manage.py', 'fix_zones'],
            capture_output=True, text=True, cwd=base, timeout=60,
        )
        return JsonResponse({
            'status': 'ok' if result.returncode == 0 else 'error',
            'stdout': result.stdout[-2000:],
            'stderr': result.stderr[-300:],
        }, status=200 if result.returncode == 0 else 500)
    except Exception as e:
        return JsonResponse({'status': 'error', 'detail': str(e)}, status=500)


urlpatterns = [
    path('health/', health),
    path('seed/', seed),
    path('seed-traffic/', seed_traffic),
    path('recompute/', recompute),
    path('seed-and-recompute/', seed_and_recompute),
    path('fix-zones/', fix_zones),
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/', include('mobility.urls')),
    path('api/weather/', include('environment.urls')),
    path('api/reports/', include('reports.urls')),
    path('api/dashboard/', include('dashboard.urls')),
]
