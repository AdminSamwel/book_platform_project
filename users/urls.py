from django.urls import path
from .views import (
    RegisterView, ProfileView, FavoriteCategoriesView, ChangePasswordView,
    VerifyOTPView, ResendOTPView, GoogleAuthView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('verify-otp/', VerifyOTPView.as_view(), name='verify-otp'),
    path('resend-otp/', ResendOTPView.as_view(), name='resend-otp'),
    path('google-auth/', GoogleAuthView.as_view(), name='google-auth'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('favorite-categories/', FavoriteCategoriesView.as_view(), name='favorite-categories'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
]
