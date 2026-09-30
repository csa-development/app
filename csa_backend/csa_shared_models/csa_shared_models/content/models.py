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
    # Exact pin, set from the map picker in the admin console. Optional —
    # a location can still be a plain typed address with no coordinates.
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)
    event_date = models.DateField()
    end_date = models.DateField(blank=True, null=True)
    start_time = models.TimeField(blank=True, null=True)
    end_time = models.TimeField(blank=True, null=True)
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
    # Optional venue for the campaign (e.g. an NCSAM launch location),
    # with an optional exact pin from the admin map picker.
    location = models.CharField(max_length=200, blank=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)
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


class AboutPageContent(models.Model):
    """Singleton — the "About CSA" page's editable text/image. Always
    exactly one row; the admin API get_or_create's it on first access."""

    intro_paragraph_1 = models.TextField(blank=True)
    intro_paragraph_2 = models.TextField(blank=True)
    image = models.ImageField(upload_to='about/', blank=True, null=True)
    mandate_text = models.TextField(blank=True)
    mission_text = models.TextField(blank=True)
    vision_text = models.TextField(blank=True)

    value_1_title = models.CharField(max_length=100, blank=True)
    value_1_description = models.TextField(blank=True)
    value_2_title = models.CharField(max_length=100, blank=True)
    value_2_description = models.TextField(blank=True)
    value_3_title = models.CharField(max_length=100, blank=True)
    value_3_description = models.TextField(blank=True)
    value_4_title = models.CharField(max_length=100, blank=True)
    value_4_description = models.TextField(blank=True)
    value_5_title = models.CharField(max_length=100, blank=True)
    value_5_description = models.TextField(blank=True)
    value_6_title = models.CharField(max_length=100, blank=True)
    value_6_description = models.TextField(blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return "About CSA Page Content"


class ContactPageContent(models.Model):
    """Singleton — the "Contact CSA" page's editable text. Always
    exactly one row; the admin API get_or_create's it on first access."""

    office_address = models.CharField(max_length=300, blank=True)
    # Google Maps' own pin for the "National Communications Authority"
    # place listing — used only as the get_or_create default for a
    # fresh row, never touched again once CERT/admin edits the real one.
    latitude = models.FloatField(default=5.6037075)
    longitude = models.FloatField(default=-0.1764636)
    phone = models.CharField(max_length=50, blank=True)
    emergency_hotline = models.CharField(max_length=50, blank=True)
    email = models.EmailField(blank=True)
    whatsapp_channel_url = models.URLField(blank=True)
    twitter_url = models.URLField(blank=True)
    instagram_url = models.URLField(blank=True)
    linkedin_url = models.URLField(blank=True)
    facebook_url = models.URLField(blank=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return "Contact CSA Page Content"


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


class CampaignRegistration(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='campaign_registrations'
    )
    campaign = models.ForeignKey(
        Campaign,
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
        unique_together = ('user', 'campaign')
        ordering = ['-registered_at']

    def __str__(self):
        return f"{self.user.username} - {self.campaign.title}"