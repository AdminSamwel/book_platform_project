from django.urls import path
from .views import PlanListView, SubscribeView, ActiveSubscriptionView

urlpatterns = [
    path('plans/', PlanListView.as_view(), name='plans'),
    path('subscribe/<int:plan_id>/', SubscribeView.as_view(), name='subscribe'),
    path('active/', ActiveSubscriptionView.as_view(), name='active-subscription'),
]