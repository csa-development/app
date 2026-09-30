from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('content', '0009_event_latitude_event_longitude'),
    ]

    operations = [
        migrations.AddField(
            model_name='campaign',
            name='location',
            field=models.CharField(blank=True, max_length=200),
        ),
        migrations.AddField(
            model_name='campaign',
            name='latitude',
            field=models.FloatField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='campaign',
            name='longitude',
            field=models.FloatField(blank=True, null=True),
        ),
    ]
