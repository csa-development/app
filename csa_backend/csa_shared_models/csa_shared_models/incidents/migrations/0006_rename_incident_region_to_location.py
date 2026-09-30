from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('incidents', '0005_incident_latitude_incident_longitude'),
    ]

    operations = [
        migrations.RenameField(
            model_name='incident',
            old_name='region',
            new_name='location',
        ),
    ]
