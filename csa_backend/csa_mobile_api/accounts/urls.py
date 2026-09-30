from django.urls import path

from .views import (
    register_user,
    request_otp,
    verify_otp,
    protected_view,
    user_profile,
    request_phone_change,
    confirm_phone_change,
    save_device_token,
    change_password,
    logout,
    send_feedback,
    send_contact_message,
    notification_preferences,
)

urlpatterns = [
    path('register/', register_user, name='register'),
    path('request-otp/', request_otp, name='request_otp'),
    path('verify-otp/', verify_otp, name='verify_otp'),
    path('protected/', protected_view, name='protected'),
    path('profile/', user_profile, name='user_profile'),
    path('profile/request-phone-change/', request_phone_change, name='request_phone_change'),
    path('profile/confirm-phone-change/', confirm_phone_change, name='confirm_phone_change'),
    path('save-device-token/', save_device_token, name='save_device_token'),
    path('change-password/', change_password, name='change_password'),
    path('logout/', logout, name='logout'),
    path('feedback/', send_feedback, name='send_feedback'),
    path('contact/', send_contact_message, name='send_contact_message'),
    path('notification-preferences/', notification_preferences, name='notification_preferences'),
]
