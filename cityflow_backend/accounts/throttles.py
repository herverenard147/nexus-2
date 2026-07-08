from rest_framework.throttling import AnonRateThrottle


class LoginRateThrottle(AnonRateThrottle):
    """5 tentatives de connexion par fenêtre de 5 minutes par IP."""
    scope = 'login'
    rate = '5/m'
    THROTTLE_RATES = {'login': '5/m'}

    def parse_rate(self, rate):
        # 5 requêtes par fenêtre de 5 minutes (300 secondes)
        return 5, 300
