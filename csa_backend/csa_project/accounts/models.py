from django.db import models
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta


class VerificationCode(models.Model):
    PURPOSE_CHOICES = [
        ('LOGIN', 'Login'),
        ('REGISTER', 'Register'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='verification_codes'
    )
    code = models.CharField(max_length=6)
    purpose = models.CharField(max_length=50, choices=PURPOSE_CHOICES)
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(minutes=10)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.code} ({self.purpose}) for {self.user.username}"


class UserProfile(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='profile'
    )
    phone = models.CharField(max_length=20, blank=True)
    national_id = models.CharField(max_length=50, blank=True)

    def __str__(self):
        return f"Profile of {self.user.username}"


class DeviceToken(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='device_tokens'
    )
    token = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Token for {self.user.username}"


class Feedback(models.Model):
    CATEGORY_CHOICES = [
        ('BUG_REPORT', 'Bug Report'),
        ('SUGGESTION', 'Suggestion'),
        ('QUESTION', 'Question'),
        ('COMPLIMENT', 'Compliment'),
    ]
    STATUS_CHOICES = [
        ('NEW', 'New'),
        ('IN_REVIEW', 'In Review'),
        ('RESOLVED', 'Resolved'),
        ('ARCHIVED', 'Archived'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='feedback'
    )
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    message = models.TextField()
    status = models.CharField(
        max_length=20, choices=STATUS_CHOICES, default='NEW')
    admin_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.category} from {self.user}"


class ContactMessage(models.Model):
    STATUS_CHOICES = [
        ('NEW', 'New'),
        ('IN_REVIEW', 'In Review'),
        ('RESOLVED', 'Resolved'),
        ('ARCHIVED', 'Archived'),
    ]

    name = models.CharField(max_length=200)
    phone = models.CharField(max_length=20, blank=True)
    email = models.EmailField()
    message = models.TextField()
    status = models.CharField(
        max_length=20, choices=STATUS_CHOICES, default='NEW')
    admin_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Message from {self.name} - {self.created_at.strftime('%B %d, %Y')}"


class LoginActivity(models.Model):
    SOURCE_CHOICES = [
        ('MOBILE', 'Mobile App'),
        ('ADMIN_WEB', 'Admin Web'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='login_activities'
    )
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)
    identifier = models.CharField(max_length=200, blank=True)
    ip_address = models.GenericIPAddressField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} via {self.source} on {self.created_at:%Y-%m-%d %H:%M}"


class NotificationPreference(models.Model):
    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='notification_preferences'
    )
    alerts = models.BooleanField(default=True)
    advisories = models.BooleanField(default=True)
    news = models.BooleanField(default=False)
    events = models.BooleanField(default=False)
    report_updates = models.BooleanField(default=True)
    email_notifications = models.BooleanField(default=False)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.username} notification preferences"