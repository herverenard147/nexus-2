from rest_framework.throttling import UserRateThrottle


class PredictionsReadThrottle(UserRateThrottle):
    """200 lectures par heure par utilisateur."""
    scope = 'predictions_read'

    def parse_rate(self, rate):
        return 200, 3600
