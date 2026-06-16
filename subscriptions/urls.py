from django.urls import path
from .views import (
    PlanListView, SubscribeView, ActiveSubscriptionView,
    SystemSettingsView, FreeBookSelectionView, SubscriptionUsageView,
)

urlpatterns = [
    path('plans/',                  PlanListView.as_view(),           name='plans'),
    path('subscribe/<int:plan_id>/', SubscribeView.as_view(),         name='subscribe'),
    path('active/',                 ActiveSubscriptionView.as_view(), name='active-subscription'),
    path('settings/',               SystemSettingsView.as_view(),     name='system-settings'),
    path('free-book-selection/',    FreeBookSelectionView.as_view(),  name='free-book-selection'),
    path('usage/',                  SubscriptionUsageView.as_view(),  name='subscription-usage'),
]
