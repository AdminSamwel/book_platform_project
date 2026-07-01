from rest_framework import serializers
from django.conf import settings
from django.db.models import Avg
from django.utils import timezone
from .models import Book, Category, Rating
from subscriptions.models import SubscriptionPlan, UserSubscription


def _user_plan_level(request):
    """Kiwango cha mpango wa mtumiaji aliyeingia (0 = Bure/hana usajili)."""
    if not request or not request.user.is_authenticated:
        return 0
    sub = UserSubscription.objects.filter(
        user=request.user, is_active=True, end_date__gt=timezone.now()
    ).select_related('plan').first()
    return sub.plan.level if sub and sub.plan else 0


class DownloadAccessMixin:
    """Sehemu ya pamoja ya 'is_purchased'/'can_download' — inaonyesha kama
    mtumiaji amenunua kitabu moja kwa moja (hivyo anaweza kukipakua na
    kukisoma nje ya mtandao). Wasomaji wa usajili wa kila mwezi tu (bila
    ununuzi wa moja kwa moja) hawapewi ruhusa ya kupakua — lazima wasome
    wakiwa mtandaoni."""

    def get_is_purchased(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        if request.user == obj.author:
            return True
        from payments.models import Purchase
        return Purchase.objects.filter(user=request.user, book=obj).exists()

    def get_can_download(self, obj):
        # Vitabu vya bure na vilivyonunuliwa moja kwa moja pekee ndivyo
        # vinavyoweza kupakuliwa kwa ajili ya usomaji nje ya mtandao.
        return bool(obj.is_free) or self.get_is_purchased(obj)


class PlanLevelMixin:
    """Sehemu za pamoja za min_plan_level/is_locked/required_plan_name."""

    def get_is_locked(self, obj):
        if obj.is_free or obj.min_plan_level == 0:
            return False
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            if request.user == obj.author:
                return False
            from payments.models import Purchase
            if Purchase.objects.filter(user=request.user, book=obj).exists():
                return False
        return _user_plan_level(request) < obj.min_plan_level

    def get_required_plan_name(self, obj):
        if obj.min_plan_level == 0:
            return None
        plan = SubscriptionPlan.objects.filter(
            level=obj.min_plan_level).order_by('price').first()
        return plan.name if plan else None

class CategorySerializer(serializers.ModelSerializer):
    book_count    = serializers.SerializerMethodField()
    cover_images  = serializers.SerializerMethodField()

    def get_book_count(self, obj):
        return obj.book_set.filter(is_published=True).count()

    def get_cover_images(self, obj):
        # Rudisha picha 4 za kwanza za vitabu vya kategoria hii
        request = self.context.get('request')
        books   = obj.book_set.filter(is_published=True, cover_image__isnull=False).exclude(cover_image='')[:4]
        if request:
            return [request.build_absolute_uri(b.cover_image.url) for b in books if b.cover_image]
        return []

    class Meta:
        model  = Category
        fields = ['id', 'name', 'slug', 'book_count', 'cover_images']


class AgeRestrictionMixin:
    """Sehemu ya pamoja ya 'is_age_restricted' — inaangalia kama mtumiaji
    aliyeingia hajafikia umri wa chini unaohitajika kusoma/kusikiliza kitabu."""

    def get_is_age_restricted(self, obj):
        if not obj.min_age:
            return False
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return True
        if request.user == obj.author:
            return False
        age = request.user.age
        if age is None:
            return True
        return age < obj.min_age


class RatingMixin:
    """Sehemu za pamoja za tathmini (rating) kwa BookListSerializer/BookDetailSerializer."""

    def get_avg_rating(self, obj):
        avg = obj.ratings.aggregate(avg=Avg('score'))['avg']
        return round(avg, 1) if avg else 0.0

    def get_ratings_count(self, obj):
        return obj.ratings.count()

    def get_purchases_count(self, obj):
        return obj.purchase_set.count()


class BookListSerializer(RatingMixin, PlanLevelMixin, AgeRestrictionMixin, DownloadAccessMixin, serializers.ModelSerializer):
    author_name    = serializers.CharField(source='author.username', read_only=True)
    category_name  = serializers.CharField(source='category.name', read_only=True)
    has_audio      = serializers.SerializerMethodField(read_only=True)
    has_text       = serializers.SerializerMethodField(read_only=True)
    avg_rating     = serializers.SerializerMethodField(read_only=True)
    ratings_count  = serializers.SerializerMethodField(read_only=True)
    purchases_count = serializers.SerializerMethodField(read_only=True)
    is_locked        = serializers.SerializerMethodField(read_only=True)
    required_plan_name = serializers.SerializerMethodField(read_only=True)
    is_age_restricted = serializers.SerializerMethodField(read_only=True)
    is_purchased      = serializers.SerializerMethodField(read_only=True)
    can_download      = serializers.SerializerMethodField(read_only=True)

    def get_has_audio(self, obj):
        return bool(obj.audio_file or obj.encrypted_audio)

    def get_has_text(self, obj):
        return bool(obj.raw_file or obj.encrypted_file)

    class Meta:
        model  = Book
        fields = ['id', 'title', 'author_name', 'price', 'is_free',
                  'cover_image', 'category', 'category_name', 'created_at',
                  'has_audio', 'has_text',
                  'avg_rating', 'ratings_count', 'purchases_count',
                  'min_plan_level', 'is_locked', 'required_plan_name',
                  'min_age', 'is_age_restricted',
                  'is_purchased', 'can_download']

class BookDetailSerializer(RatingMixin, PlanLevelMixin, AgeRestrictionMixin, DownloadAccessMixin, serializers.ModelSerializer):
    author_name    = serializers.CharField(source='author.username', read_only=True)
    category_name  = serializers.CharField(source='category.name', read_only=True)
    file_type      = serializers.SerializerMethodField(read_only=True)
    has_audio      = serializers.SerializerMethodField(read_only=True)
    has_text       = serializers.SerializerMethodField(read_only=True)
    avg_rating     = serializers.SerializerMethodField(read_only=True)
    ratings_count  = serializers.SerializerMethodField(read_only=True)
    purchases_count = serializers.SerializerMethodField(read_only=True)
    is_locked        = serializers.SerializerMethodField(read_only=True)
    required_plan_name = serializers.SerializerMethodField(read_only=True)
    is_age_restricted = serializers.SerializerMethodField(read_only=True)
    is_purchased      = serializers.SerializerMethodField(read_only=True)
    can_download      = serializers.SerializerMethodField(read_only=True)
    share_url        = serializers.SerializerMethodField(read_only=True)

    def get_share_url(self, obj):
        return f'{settings.SITE_URL}/share/book/{obj.id}/'

    def get_file_type(self, obj):
        if obj.raw_file:
            name = obj.raw_file.name.lower()
            if name.endswith('.pdf'):  return 'pdf'
            if name.endswith('.epub'): return 'epub'
        return 'txt'

    def get_has_audio(self, obj):
        return obj.has_audio

    def get_has_text(self, obj):
        return obj.has_text

    class Meta:
        model  = Book
        fields = ['id', 'title', 'author_name', 'description', 'cover_image',
                  'category', 'category_name', 'price', 'is_free',
                  'min_plan_level', 'is_locked', 'required_plan_name',
                  'min_age', 'is_age_restricted',
                  'raw_file', 'audio_file', 'is_published', 'created_at',
                  'file_type', 'has_audio', 'has_text',
                  'avg_rating', 'ratings_count', 'purchases_count',
                  'is_purchased', 'can_download',
                  'share_url',
                  # Library metadata
                  'isbn', 'book_authors', 'publisher', 'year_published',
                  'edition', 'page_count', 'book_language']
        read_only_fields = ['id', 'author_name', 'category_name', 'created_at',
                            'file_type', 'has_audio', 'has_text',
                            'avg_rating', 'ratings_count', 'purchases_count',
                            'is_locked', 'required_plan_name', 'is_age_restricted',
                            'is_purchased', 'can_download',
                            'share_url']
        extra_kwargs = {
            'raw_file':   {'write_only': True, 'required': False},
            'audio_file': {'write_only': True, 'required': False},
            'isbn':           {'required': False},
            'book_authors':   {'required': False},
            'publisher':      {'required': False},
            'year_published': {'required': False},
            'edition':        {'required': False},
            'page_count':     {'required': False},
            'book_language':  {'required': False},
            'min_plan_level': {'required': False},
            'min_age':        {'required': False},
        }


class RatingSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    avatar   = serializers.SerializerMethodField(read_only=True)

    def get_avatar(self, obj):
        request = self.context.get('request')
        if obj.user.avatar and request:
            return request.build_absolute_uri(obj.user.avatar.url)
        return None

    class Meta:
        model = Rating
        fields = ['id', 'user', 'username', 'avatar', 'score', 'comment',
                  'created_at', 'updated_at']
        read_only_fields = ['id', 'user', 'username', 'avatar', 'created_at', 'updated_at']

    def validate_score(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError('Nyota lazima iwe kati ya 1 na 5.')
        return value
