import re
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
    # Free-text place / street address the reporter typed or picked on
    # the map (not a fixed administrative region). Paired with the
    # optional lat/long pin below.
    location = models.CharField(max_length=100, blank=True)
    # Exact pin coordinates from the mobile app's map-based location
    # picker. Optional — a report submitted without ever opening the
    # picker (or where the reporter denied location + typed a plain
    # address) simply has these left blank.
    latitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(
        max_digits=9, decimal_places=6, null=True, blank=True)
    reporter_name = models.CharField(max_length=200, blank=True)
    reporter_phone = models.CharField(max_length=20, blank=True)
    reporting_for_someone = models.BooleanField(default=False)
    relationship_to_victim = models.CharField(max_length=100, blank=True)
    evidence_description = models.TextField(blank=True)
    # The actual photo/video a reporter attaches, if any. Previously
    # the app only ever sent this field's *filename* as text here —
    # the real file was picked on-device but never uploaded, so CERT
    # had no way to see it. Generic FileField (not ImageField): a
    # reporter can attach either a photo or a short video.
    evidence_file = models.FileField(
        upload_to='incident_evidence/', null=True, blank=True)
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='PENDING'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.reference_number:
            # Reporter's phone in Ghana MSISDN form + a running count of
            # reports from that number, e.g. 0534559830's first report
            # becomes "233534559830-001", the next "...-002".
            # (NOTE: this exposes the reporter's phone number to anyone
            # who sees a reference — kept per product decision.)
            digits = re.sub(r'\D', '', self.reporter_phone or '')
            if digits.startswith('0'):
                digits = '233' + digits[1:]
            elif digits and not digits.startswith('233'):
                digits = '233' + digits
            if digits:
                sequence = Incident.objects.filter(
                    reporter_phone=self.reporter_phone
                ).count() + 1
                self.reference_number = f"{digits}-{sequence:03d}"
            else:
                self.reference_number = f"CSA-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.reference_number} - {self.incident_type}"


class IncidentStatusOption(models.Model):
    """The set of statuses a report can be in, and the order CERT
    wants them shown in (timelines, dropdowns). Deliberately a table
    CERT can add to via the admin UI rather than a hardcoded Python
    choices list — adding e.g. "Proposal" between Pending and Under
    Review is then a data change, not a code deploy. `key` is what's
    actually stored on Incident.status; `label`/`color` are display
    only and safe to edit without touching stored report data."""

    key = models.CharField(max_length=20, unique=True)
    label = models.CharField(max_length=50)
    # Hex color, e.g. "#D97706" — used for the status dot/badge on both
    # admin web and the mobile app, so a newly added status gets a
    # sensible color everywhere without either app needing a code
    # change to recognize it.
    color = models.CharField(max_length=7, default='#6B7280')
    # Sort order for timelines/dropdowns. Not required to be contiguous
    # — insertion renumbers neighbors as needed (see
    # admin_incident_statuses in csa_admin_api).
    position = models.IntegerField()

    class Meta:
        ordering = ['position']

    def __str__(self):
        return self.label


def status_label(key):
    """Display label for a status key, falling back to the raw key if
    it's somehow not in the table (should not normally happen, but a
    report should never fail to render over a lookup miss)."""
    option = IncidentStatusOption.objects.filter(key=key).first()
    return option.label if option else key


def status_color(key):
    """Hex color for a status key, falling back to a neutral gray."""
    option = IncidentStatusOption.objects.filter(key=key).first()
    return option.color if option else '#6B7280'


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
    # Optional: lets LECO link a certificate to the citizen account that
    # should be notified when it's approved/issued. Not a ForeignKey —
    # most certificates are entered directly by LECO with no citizen
    # account behind them, so this stays a plain, optional text field
    # matched against auth_user.email at notify-time rather than a
    # relation that would need backfilling.
    holder_email = models.EmailField(blank=True)
    issue_date = models.DateField()
    expiry_date = models.DateField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.certificate_number} - {self.holder_name}"