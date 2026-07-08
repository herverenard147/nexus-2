from rest_framework.throttling import UserRateThrottle


class PredictionsReadThrottle(UserRateThrottle):
    scope = 'predictions_read'
