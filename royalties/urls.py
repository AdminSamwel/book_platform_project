from django.urls import path
from . import views

urlpatterns = [
    path('my-earnings/', views.MyEarningsView.as_view(), name='my-earnings'),
    path('admin/settings/', views.PlatformSettingsView.as_view(), name='royalty-settings'),
    path('admin/pool/', views.RevenuePoolView.as_view(), name='royalty-pool'),
    path('admin/pool/history/', views.RevenuePoolHistoryView.as_view(), name='royalty-pool-history'),
    path('admin/distribute/', views.DistributeRevenueView.as_view(), name='royalty-distribute'),
]
