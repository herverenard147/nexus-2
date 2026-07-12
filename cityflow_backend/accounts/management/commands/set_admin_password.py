import os
from django.core.management.base import BaseCommand, CommandError
from accounts.models import User


class Command(BaseCommand):
    help = "Set the admin user password from ADMIN_PASSWORD env var"

    def handle(self, *args, **options):
        pwd = os.environ.get('ADMIN_PASSWORD')
        if not pwd:
            raise CommandError("ADMIN_PASSWORD env var is not set.")
        try:
            user = User.objects.get(username='admin')
        except User.DoesNotExist:
            raise CommandError("No user with username='admin' found.")
        user.set_password(pwd)
        user.save()
        self.stdout.write(self.style.SUCCESS(f"Password updated for user '{user.username}'."))
