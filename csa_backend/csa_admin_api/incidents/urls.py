from django.urls import path
from .admin_views import (
    admin_certificate_detail,
    admin_certificates,
    admin_cert_dashboard,
    admin_certificates_dashboard,
    admin_incidents,
    admin_incident_status,
    admin_incident_statuses,
)

urlpatterns = [
    path('admin/reports/', admin_incidents, name='admin_incidents'),
    # A distinct path segment ("report-statuses", not "reports/...") —
    # no ordering hazard with the <str:reference_number> pattern below.
    path('admin/report-statuses/', admin_incident_statuses, name='admin_incident_statuses'),
    path('admin/reports/<str:reference_number>/', admin_incident_status, name='admin_incident_status'),
    path('admin/certificates/', admin_certificates, name='admin_certificates'),
    path('admin/certificates/<int:certificate_id>/', admin_certificate_detail, name='admin_certificate_detail'),
    path('admin/dashboard/certificates/', admin_certificates_dashboard, name='admin_certificates_dashboard'),
    path('admin/dashboard/cert/', admin_cert_dashboard, name='admin_cert_dashboard'),
]
