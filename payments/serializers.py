from rest_framework import serializers
from .models import Purchase, CartItem

class PurchaseSerializer(serializers.ModelSerializer):
    book_title = serializers.CharField(source='book.title', read_only=True)
    class Meta:
        model = Purchase
        fields = ['id', 'book', 'book_title', 'amount', 'purchased_at']


class CartItemSerializer(serializers.ModelSerializer):
    book_id     = serializers.IntegerField(source='book.id', read_only=True)
    title       = serializers.CharField(source='book.title', read_only=True)
    author_name = serializers.CharField(source='book.author.username', read_only=True)
    price       = serializers.DecimalField(source='book.price', max_digits=10,
                        decimal_places=2, read_only=True)
    is_free     = serializers.BooleanField(source='book.is_free', read_only=True)
    cover_image = serializers.SerializerMethodField()

    def get_cover_image(self, obj):
        request = self.context.get('request')
        if obj.book.cover_image and request:
            return request.build_absolute_uri(obj.book.cover_image.url)
        return None

    class Meta:
        model = CartItem
        fields = ['id', 'book_id', 'title', 'author_name', 'price',
                  'is_free', 'cover_image', 'added_at']