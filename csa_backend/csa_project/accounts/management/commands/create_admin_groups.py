from django.contrib.auth.models import Group, User
from django.core.management.base import BaseCommand

from accounts.permissions import ALL_ROLES, SUPERADMIN


class Command(BaseCommand):
    help = (
        'Creates the SUPERADMIN/LECO/CERT/COMMS/IT groups if they do not '
        'already exist, and adds any existing superuser/staff account to '
        'SUPERADMIN so it keeps full access after roles are introduced.'
    )

    def handle(self, *args, **options):
        for name in ALL_ROLES:
            group, created = Group.objects.get_or_create(name=name)
            if created:
                self.stdout.write(f'Created group: {name}')
            else:
                self.stdout.write(f'Group already exists: {name}')

        superadmin_group = Group.objects.get(name=SUPERADMIN)
        existing_admins = User.objects.filter(is_superuser=True) | User.objects.filter(is_staff=True)
        for user in existing_admins.distinct():
            if not user.groups.filter(name=SUPERADMIN).exists():
                user.groups.add(superadmin_group)
                self.stdout.write(f'Added {user.username} to SUPERADMIN')

        self.stdout.write(self.style.SUCCESS('Admin groups are set up.'))
