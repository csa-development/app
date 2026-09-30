from django.contrib import admin
from csa_shared_models.content.models import (
    NewsArticle,
    Event,
    Campaign,
    CampaignGallery,
    CampaignSchedule,
    CampaignSpeaker,
    CampaignNews,
    PressRelease,
)


@admin.register(NewsArticle)
class NewsArticleAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'category',
        'date_published',
        'is_published',
        'is_breaking',
    )
    list_filter = ('category', 'is_published', 'is_breaking')
    search_fields = ('title', 'body')
    list_editable = ('is_published', 'is_breaking')


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'event_date',
        'end_date',
        'location',
        'is_published',
    )
    list_filter = ('is_published',)
    search_fields = ('title', 'description')
    list_editable = ('is_published',)


class CampaignGalleryInline(admin.TabularInline):
    model = CampaignGallery
    extra = 3


class CampaignScheduleInline(admin.TabularInline):
    model = CampaignSchedule
    extra = 3


class CampaignSpeakerInline(admin.TabularInline):
    model = CampaignSpeaker
    extra = 2


class CampaignNewsInline(admin.TabularInline):
    model = CampaignNews
    extra = 2


@admin.register(Campaign)
class CampaignAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'category',
        'start_date',
        'end_date',
        'is_published',
    )
    list_filter = ('category', 'is_published')
    search_fields = ('title', 'description')
    list_editable = ('is_published',)
    inlines = [
        CampaignGalleryInline,
        CampaignScheduleInline,
        CampaignSpeakerInline,
        CampaignNewsInline,
    ]


@admin.register(PressRelease)
class PressReleaseAdmin(admin.ModelAdmin):
    list_display = (
        'title',
        'date_published',
        'is_published',
    )
    list_filter = ('is_published',)
    search_fields = ('title', 'body')
    list_editable = ('is_published',)