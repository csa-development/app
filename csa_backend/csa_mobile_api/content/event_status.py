from django.utils import timezone

# The server's clock decides, never the phone's — a phone with a wrong date
# can't re-open an ended event, and an old app version is held to the same
# rule on the registration endpoints.
#
# "Ended" means the whole last day has passed (not the start time), so a
# same-day event stays open until the day is over.


def event_has_ended(event):
    last_day = event.end_date or event.event_date
    return timezone.localdate() > last_day


def campaign_has_ended(campaign):
    # With no end date a campaign is treated as a one-day campaign (it
    # ends after its start date) — the same rule the app already used.
    # Multi-day campaigns need their end date set in the admin console.
    last_day = campaign.end_date or campaign.start_date
    return timezone.localdate() > last_day
