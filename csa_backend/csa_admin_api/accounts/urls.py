from django.urls import path

from .cookie_auth import admin_logout, admin_refresh
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
    path('admin/login/', admin_login, name='admin_login'),
    path('admin/refresh/', admin_refresh, name='admin_refresh'),
    path('admin/logout/', admin_logout, name='admin_logout'),
    path('admin/dashboard/', admin_dashboard, name='admin_dashboard'),
    path('admin/users/', admin_users, name='admin_users'),
    path('admin/users/<int:user_id>/', admin_user_detail, name='admin_user_detail'),
    path('admin/feedback/', admin_feedback, name='admin_feedback'),
    path('admin/messages/', admin_contact_messages, name='admin_contact_messages'),
    path('admin/dashboard/it/', admin_it_dashboard, name='admin_it_dashboard'),
    path('admin/staff/', admin_staff_collection, name='admin_staff_collection'),
    path('admin/staff/<int:user_id>/', admin_staff_detail, name='admin_staff_detail'),
]
