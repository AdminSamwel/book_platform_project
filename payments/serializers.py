from rest_framework import serializers
from .models import Purchase

class PurchaseSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)
    class Meta:
        model = Purchase
        fields = ['id', 'book', 'book_title', 'amount', 'purchased_at']