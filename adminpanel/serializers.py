from rest_framework import serializers
from users.models import User
from books.models import Book
from subscriptions.models import SubscriptionPlan


class AdminUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'is_banned', 'ban_reason',
                  'is_staff', 'is_superuser', 'is_active', 'date_joined', 'warning_count']
        read_only_fields = ['id', 'username', 'email', 'role', 'is_staff',
                             'is_superuser', 'date_joined', 'warning_count']


class AdminBookSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)

    class Meta:
        model = Book
        fields = ['id', 'title', 'author_name', 'price', 'is_free', 'min_plan_level',
                  'is_published', 'created_at', 'category']


class AdminPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = SubscriptionPlan
        fields = '__all__'
