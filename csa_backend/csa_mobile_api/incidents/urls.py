from django.urls import path
from .views import (
    submit_report, my_reports, verify_certificate, list_statuses,
)

urlpatterns = [
    path('submit/', submit_report, name='submit_report'),
    path('my-reports/', my_reports, name='my_reports'),
    path('statuses/', list_statuses, name='list_statuses'),
    path('verify-certificate/', verify_certificate, name='verify_certificate'),
]
