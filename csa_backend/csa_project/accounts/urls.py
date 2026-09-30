from django.urls import path

from .views import (
    register_user,
    request_otp,
    verify_otp,
    protected_view,
    user_profile,
    save_device_token,
    change_password,
    send_feedback,
    send_contact_message,
    notification_preferences,
)
from .admin_views import (
    admin_contact_messages,
    admin_dashboard,
    admin_feedback,
    admin_it_dashboard,
    admin_login,
    admin_staff_collection,
    admin_staff_detail,
    admin_user_detail,
    admin_users,
)

urlpatterns = [
    path('register/', register_user, name='register'),
    path('request-otp/', request_otp, name='request_otp'),
    path('verify-otp/', verify_otp, name='verify_otp'),
    path('protected/', protected_view, name='protected'),
    path('profile/', user_profile, name='user_profile'),
    path('save-device-token/', save_device_token, name='save_device_token'),
    path('change-password/', change_password, name='change_password'),
    path('feedback/', send_feedback, name='send_feedback'),
    path('contact/', send_contact_message, name='send_contact_message'),
    path('notification-preferences/', notification_preferences, name='notification_preferences'),
    path('admin/login/', admin_login, name='admin_login'),
    path('admin/dashboard/', admin_dashboard, name='admin_dashboard'),
    path('admin/users/', admin_users, name='admin_users'),
    path('admin/users/<int:user_id>/', admin_user_detail, name='admin_user_detail'),
    path('admin/feedback/', admin_feedback, name='admin_feedback'),
    path('admin/messages/', admin_contact_messages, name='admin_contact_messages'),
    path('admin/dashboard/it/', admin_it_dashboard, name='admin_it_dashboard'),
    path('admin/staff/', admin_staff_collection, name='admin_staff_collection'),
    path('admin/staff/<int:user_id>/', admin_staff_detail, name='admin_staff_detail'),
]