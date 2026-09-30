from django.urls import path
from .views import submit_report, my_reports, verify_certificate, update_report_status
from .admin_views import (
    admin_certificate_detail,
    admin_certificates,
    admin_cert_dashboard,
    admin_incidents,
    admin_incident_status,
    admin_leco_dashboard,
)

urlpatterns = [
    path('submit/', submit_report, name='submit_report'),
    path('my-reports/', my_reports, name='my_reports'),
    path('verify-certificate/', verify_certificate, name='verify_certificate'),
    path('update-status/<str:reference_number>/', update_report_status, name='update_report_status'),
    path('admin/reports/', admin_incidents, name='admin_incidents'),
    path('admin/reports/<str:reference_number>/', admin_incident_status, name='admin_incident_status'),
    path('admin/certificates/', admin_certificates, name='admin_certificates'),
    path('admin/certificates/<int:certificate_id>/', admin_certificate_detail, name='admin_certificate_detail'),
    path('admin/dashboard/leco/', admin_leco_dashboard, name='admin_leco_dashboard'),
    path('admin/dashboard/cert/', admin_cert_dashboard, name='admin_cert_dashboard'),
]
