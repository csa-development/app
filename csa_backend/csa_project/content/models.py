from django.db import models
from django.contrib.auth.models import User


class NewsArticle(models.Model):
    CATEGORY_CHOICES = [
        ('NEWS', 'News'),
        ('ALERT', 'Alert'),
        ('ADVISORY', 'Advisory'),
        ('NOTICE', 'Notice'),
    ]

    title = models.CharField(max_length=300)
    body = models.TextField()
    category = models.CharField(
        max_length=20,
        choices=CATEGORY_CHOICES,
        default='NEWS'
    )
    image = models.ImageField(upload_to='news/', blank=True, null=True)
    date_published = models.DateField(auto_now_add=True)
    is_published = models.BooleanField(default=True)
    is_breaking = models.BooleanField(default=False)

    class Meta:
        ordering = ['-date_published']

    def __str__(self):
        return f"[{self.category}] {self.title}"


class Event(models.Model):
    title = models.CharField(max_length=300)
    description = models.TextField()
    location = models.CharField(max_length=200, blank=True)
    event_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)
    image = models.ImageField(upload_to='events/', blank=True, null=True)
    is_published = models.BooleanField(default=True)

    class Meta:
        ordering = ['-event_date']

    def __str__(self):
        return self.title


class Campaign(models.Model):
    CATEGORY_CHOICES = [
        ('AWARENESS', 'Awareness Creation'),
        ('NCSAM', 'NCSAM'),
        ('CHALLENGE', 'Cybersecurity Challenge'),
        ('WORKSHOP', 'Workshop'),
        ('TRAINING', 'Training'),
        ('SENSITISATION', 'Sensitisation'),
        ('CYBER_HYGIENE', 'Cyber Hygiene'),
        ('OUTREACH', 'Outreach'),
        ('OTHER', 'Other'),
    ]

    title = models.CharField(max_length=300)
    description = models.TextField()
    start_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)
    image = models.ImageField(upload_to='campaigns/', blank=True, null=True)
    target_audience = models.CharField(max_length=200, blank=True)
    category = models.CharField(
        max_length=20,
        choices=CATEGORY_CHOICES,
        default='OTHER'
    )
    is_published = models.BooleanField(default=True)

    class Meta:
        ordering = ['-start_date']

    def __str__(self):
        return self.title


class CampaignGallery(models.Model):
    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='gallery'
    )
    image = models.ImageField(upload_to='campaign_gallery/')
    caption = models.CharField(max_length=200, blank=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"Gallery image for {self.campaign.title}"


class CampaignSchedule(models.Model):
    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='schedule'
    )
    week_number = models.PositiveIntegerField(default=1)
    day = models.CharField(max_length=100, blank=True)
    start_time = models.TimeField()
    end_time = models.TimeField(blank=True, null=True)
    session_title = models.CharField(max_length=300)
    speaker = models.CharField(max_length=200, blank=True)
    venue = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ['week_number', 'start_time']

    def __str__(self):
        return f"Week {self.week_number} - {self.session_title}"


class CampaignSpeaker(models.Model):
    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='speakers'
    )
    name = models.CharField(max_length=200)
    title = models.CharField(max_length=200, blank=True)
    organisation = models.CharField(max_length=200, blank=True)
    bio = models.TextField(blank=True)
    photo = models.ImageField(
        upload_to='campaign_speakers/',
        blank=True,
        null=True
    )
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"{self.name} - {self.campaign.title}"


class CampaignNews(models.Model):
    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='related_news'
    )
    article = models.ForeignKey(
        NewsArticle,
        on_delete=models.CASCADE,
    )

    def __str__(self):
        return f"{self.article.title} - {self.campaign.title}"


class PressRelease(models.Model):
    title = models.CharField(max_length=300)
    body = models.TextField()
    image = models.ImageField(upload_to='press/', blank=True, null=True)
    date_published = models.DateField(auto_now_add=True)
    is_published = models.BooleanField(default=True)

    class Meta:
        ordering = ['-date_published']

    def __str__(self):
        return self.title


class EventRegistration(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='event_registrations'
    )
    event = models.ForeignKey(
        Event,
        on_delete=models.CASCADE,
        related_name='registrations'
    )
    registered_at = models.DateTimeField(auto_now_add=True)
    check_in_code = models.CharField(
        max_length=20, unique=True, blank=True, null=True
    )
    checked_in = models.BooleanField(default=False)
    checked_in_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        unique_together = ('user', 'event')
        ordering = ['-registered_at']

    def __str__(self):
        return f"{self.user.username} - {self.event.title}"