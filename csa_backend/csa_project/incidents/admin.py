from django.contrib import admin
from .models import Incident, Certificate

@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = (
        'reference_number',
        'incident_type',
        'reporter_name',
        'platform',
        'region',
        'status',
        'created_at',
    )
    list_filter = ('status', 'incident_type')
    search_fields = ('reference_number', 'reporter_name', 'incident_type')
    ordering = ('-created_at',)

@admin.register(Certificate)
class CertificateAdmin(admin.ModelAdmin):
    list_display = (
        'certificate_number',
        'certificate_type',
        'holder_name',
        'organisation',
        'issue_date',
        'expiry_date',
        'is_active',
    )
    list_filter = ('certificate_type', 'is_active')
    search_fields = ('certificate_number', 'holder_name')