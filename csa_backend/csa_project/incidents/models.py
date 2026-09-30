import uuid
from django.db import models
from django.contrib.auth.models import User

class Incident(models.Model):
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('UNDER_REVIEW', 'Under Review'),
        ('RESOLVED', 'Resolved'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='incidents'
    )
    reference_number = models.CharField(max_length=30, unique=True)
    incident_type = models.CharField(max_length=100)
    platform = models.CharField(max_length=100, blank=True)
    description = models.TextField()
    date_of_incident = models.DateField(null=True, blank=True)
    region = models.CharField(max_length=100, blank=True)
    reporter_name = models.CharField(max_length=200, blank=True)
    reporter_phone = models.CharField(max_length=20, blank=True)
    reporting_for_someone = models.BooleanField(default=False)
    relationship_to_victim = models.CharField(max_length=100, blank=True)
    evidence_description = models.TextField(blank=True)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.reference_number:
            self.reference_number = f"CSA-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.reference_number} - {self.incident_type}"


class Certificate(models.Model):
    CERTIFICATE_TYPES = [
        ('CSP', 'Cybersecurity Service Provider'),
        ('CE', 'Cybersecurity Establishment'),
        ('CP', 'Cybersecurity Professional'),
    ]

    certificate_number = models.CharField(max_length=100, unique=True)
    certificate_type = models.CharField(max_length=10, choices=CERTIFICATE_TYPES)
    holder_name = models.CharField(max_length=200)
    organisation = models.CharField(max_length=200, blank=True)
    issue_date = models.DateField()
    expiry_date = models.DateField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.certificate_number} - {self.holder_name}"