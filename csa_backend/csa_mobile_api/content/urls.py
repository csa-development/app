from django.urls import path

from .views import (
    get_news,
    get_news_detail,
    get_alerts,
    get_breaking_news,
    get_events,
    get_event_detail,
    get_campaigns,
    get_campaign_detail,
    get_press_releases,
    get_press_release_detail,
    register_event_interest,
    unregister_event_interest,
    check_event_registration,
    get_my_event_registrations,
    register_campaign_interest,
    unregister_campaign_interest,
    check_campaign_registration,
    get_my_campaign_registrations,
    get_about_page,
    get_contact_page,
)

urlpatterns = [
    path('news/', get_news, name='get_news'),
    path('news/<int:news_id>/', get_news_detail, name='get_news_detail'),
    path('alerts/', get_alerts, name='get_alerts'),
    path(
        'breaking-news/', get_breaking_news, name='get_breaking_news'
    ),
    path('events/', get_events, name='get_events'),
    path(
        'events/<int:event_id>/',
        get_event_detail,
        name='get_event_detail',
    ),
    path('campaigns/', get_campaigns, name='get_campaigns'),
    path(
        'campaigns/<int:campaign_id>/',
        get_campaign_detail,
        name='get_campaign_detail',
    ),
    path(
        'press-releases/', get_press_releases, name='get_press_releases'
    ),
    path(
        'press-releases/<int:release_id>/',
        get_press_release_detail,
        name='get_press_release_detail',
    ),
    path(
        'events/<int:event_id>/register/',
        register_event_interest,
        name='register_event_interest',
    ),
    path(
        'events/<int:event_id>/unregister/',
        unregister_event_interest,
        name='unregister_event_interest',
    ),
    path(
        'events/<int:event_id>/check-registration/',
        check_event_registration,
        name='check_event_registration',
    ),
    path(
        'events/my-registrations/',
        get_my_event_registrations,
        name='get_my_event_registrations',
    ),
    path(
        'campaigns/<int:campaign_id>/register/',
        register_campaign_interest,
        name='register_campaign_interest',
    ),
    path(
        'campaigns/<int:campaign_id>/unregister/',
        unregister_campaign_interest,
        name='unregister_campaign_interest',
    ),
    path(
        'campaigns/<int:campaign_id>/check-registration/',
        check_campaign_registration,
        name='check_campaign_registration',
    ),
    path(
        'campaigns/my-registrations/',
        get_my_campaign_registrations,
        name='get_my_campaign_registrations',
    ),
    path('about/', get_about_page, name='get_about_page'),
    path('contact/', get_contact_page, name='get_contact_page'),
]
