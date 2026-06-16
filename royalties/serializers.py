from rest_framework import serializers
from .models import PlatformSettings, AuthorEarning, SubscriptionRevenuePool


class PlatformSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model = PlatformSettings
        fields = ['purchase_commission_percent', 'subscription_commission_percent']


class AuthorEarningSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)

    class Meta:
        model = AuthorEarning
        fields = ['id', 'book', 'book_title', 'source', 'amount', 'year', 'month',
                  'reads', 'share_percent', 'created_at']


class SubscriptionRevenuePoolSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionRevenuePool
        fields = ['year', 'month', 'total_revenue', 'distributed', 'distributed_at']
