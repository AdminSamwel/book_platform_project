from django.urls import path
from . import views

urlpatterns = [
    path('stats/', views.AdminStatsView.as_view(), name='admin-stats'),
    path('users/', views.AdminUserListView.as_view(), name='admin-users'),
    path('users/<int:user_id>/ban/', views.AdminUserBanView.as_view(), name='admin-user-ban'),
    path('books/', views.AdminBookListView.as_view(), name='admin-books'),
    path('books/<int:book_id>/toggle/', views.AdminBookToggleView.as_view(), name='admin-book-toggle'),
    path('books/<int:book_id>/delete/', views.AdminBookDeleteView.as_view(), name='admin-book-delete'),
    path('plans/', views.AdminPlanListCreateView.as_view(), name='admin-plans'),
    path('plans/<int:pk>/', views.AdminPlanDetailView.as_view(), name='admin-plan-detail'),
]
