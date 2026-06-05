from rest_framework import serializers
from .models import SubscriptionPlan, UserSubscription

class PlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = '__all__'

class UserSubscriptionSerializer(serializers.ModelSerializer):
    plan_name = serializers.CharField(source='plan.name', read_only=True)
    class Meta:
        model = UserSubscription
        fields = ['id', 'plan', 'plan_name', 'start_date', 'end_date', 'is_active']