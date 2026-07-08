from rest_framework.throttling import UserRateThrottle


class ReportCreateThrottle(UserRateThrottle):
    """5 signalements par utilisateur par fenêtre de 10 minutes."""
    scope = 'reports'

    def parse_rate(self, rate):
        # 5 requêtes par fenêtre de 10 minutes (600 secondes)
        return 5, 600
