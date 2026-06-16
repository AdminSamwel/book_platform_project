from django.contrib import admin
from .models import PlatformSettings, SubscriptionRevenuePool, ReadingEvent, AuthorEarning


@admin.register(PlatformSettings)
class PlatformSettingsAdmin(admin.ModelAdmin):
    list_display = ('purchase_commission_percent', 'subscription_commission_percent')

    def has_add_permission(self, request):
        return not PlatformSettings.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(SubscriptionRevenuePool)
class SubscriptionRevenuePoolAdmin(admin.ModelAdmin):
    list_display = ('year', 'month', 'total_revenue', 'distributed', 'distributed_at')
    list_filter = ('distributed', 'year')


@admin.register(ReadingEvent)
class ReadingEventAdmin(admin.ModelAdmin):
    list_display = ('user', 'book', 'year', 'month', 'created_at')
    list_filter = ('year', 'month')
    search_fields = ('user__username', 'book__title')


@admin.register(AuthorEarning)
class AuthorEarningAdmin(admin.ModelAdmin):
    list_display = ('author', 'book', 'source', 'amount', 'year', 'month', 'created_at')
    list_filter = ('source', 'year', 'month')
    search_fields = ('author__username', 'book__title')
