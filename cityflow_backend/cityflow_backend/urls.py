import traceback
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.db import connection


def health(request):
    try:
        with connection.cursor() as c:
            c.execute("SELECT 1")
        from django.conf import settings
        return JsonResponse({
            'status': 'ok',
            'db_engine': settings.DATABASES['default']['ENGINE'],
            'db_name': str(settings.DATABASES['default'].get('NAME', '')),
        })
    except Exception as e:
        return JsonResponse({'status': 'error', 'detail': str(e),
                             'trace': traceback.format_exc()}, status=500)


urlpatterns = [
    path('health/', health),
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/', include('mobility.urls')),
    path('api/weather/', include('environment.urls')),
    path('api/reports/', include('reports.urls')),
    path('api/dashboard/', include('dashboard.urls')),
]
