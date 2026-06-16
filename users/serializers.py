import re
from datetime import timedelta

from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email
from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from books.models import Category, Book
from .models import User, OTPCode
from .otp import generate_otp_for_user, send_otp


PHONE_RE = re.compile(r'^\+?\d{9,15}$')


def identify_contact(value):
    """Rudisha 'email' au 'phone' kulingana na muundo wa thamani, au None kama si sahihi."""
    try:
        validate_email(value)
        return 'email'
    except DjangoValidationError:
        pass
    if PHONE_RE.match(value):
        return 'phone'
    return None


class FavoriteCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name', 'slug']


class UserSerializer(serializers.ModelSerializer):
    favorite_categories = FavoriteCategorySerializer(many=True, read_only=True)
    age = serializers.ReadOnlyField()

    class Meta:
        model = User
        fields = ['id', 'username', 'role', 'bio', 'avatar', 'is_banned', 'ban_reason',
                  'favorite_categories', 'is_staff', 'is_superuser',
                  'date_of_birth', 'age', 'email', 'phone_number']
        read_only_fields = ['id', 'is_banned', 'ban_reason', 'favorite_categories',
                             'is_staff', 'is_superuser', 'age', 'email', 'phone_number']


class FavoriteCategoriesUpdateSerializer(serializers.ModelSerializer):
    """Inaruhusu msomaji kuongeza/kubadilisha makundi anayopenda kutoka dashibodi yake.
    Hakuna ukomo wa idadi hapa - ukomo wa makundi 3 unatumika wakati wa usajili tu."""
    category_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Category.objects.all(), source='favorite_categories',
        required=True)
    favorite_categories = FavoriteCategorySerializer(many=True, read_only=True)

    class Meta:
        model = User
        fields = ['category_ids', 'favorite_categories']

    def update(self, instance, validated_data):
        categories = validated_data.pop('favorite_categories', None)
        if categories is not None:
            instance.favorite_categories.set(categories)
        return instance


class ChangePasswordSerializer(serializers.Serializer):
    """Inaruhusu mtumiaji aliyeingia kubadilisha nenosiri lake mwenyewe,
    kwa kuthibitisha nenosiri la zamani kwanza."""
    old_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, required=True, min_length=6)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Nenosiri la zamani si sahihi.')
        return value

    def save(self, **kwargs):
        user = self.context['request'].user
        user.set_password(self.validated_data['new_password'])
        user.save(update_fields=['password'])
        return user


class BanAwareTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Zuia watumiaji waliofungiwa wasiingie kwenye mfumo, na waeleze
    watumiaji wasiothibitisha akaunti yao (OTP) sababu sahihi."""

    def validate(self, attrs):
        try:
            data = super().validate(attrs)
        except AuthenticationFailed:
            username = attrs.get(self.username_field)
            user = User.objects.filter(username=username).first()
            if user and not user.is_active and not user.is_banned:
                raise AuthenticationFailed(
                    'Akaunti yako bado haijathibitishwa. Tumia nambari ya OTP '
                    'iliyotumwa kwenye barua pepe yako kuthibitisha akaunti.',
                    'account_not_verified',
                )
            raise

        if getattr(self.user, 'is_banned', False):
            reason = self.user.ban_reason or 'Umevunja kanuni za jamii.'
            raise AuthenticationFailed(
                f'Akaunti yako imefungiwa. Sababu: {reason}',
                'account_banned',
            )
        return data


class RegisterSerializer(serializers.ModelSerializer):
    """Usajili mpya - mtumiaji anaweka email AU namba ya simu kama 'identifier'
    (itahifadhiwa kama username), kisha akaunti inathibitishwa kwa OTP."""
    identifier = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True, min_length=6)
    category_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Category.objects.all(), source='favorite_categories',
        required=False, write_only=True)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    referred_by_book_id = serializers.PrimaryKeyRelatedField(
        queryset=Book.objects.all(), source='referred_by_book',
        required=False, allow_null=True, write_only=True)

    class Meta:
        model = User
        fields = ['identifier', 'password', 'role', 'category_ids',
                  'date_of_birth', 'referred_by_book_id']

    def validate_category_ids(self, value):
        if len(value) > 3:
            raise serializers.ValidationError(
                'Chagua makundi yasiyozidi matatu (3) ya vitabu unavyopenda.')
        return value

    def validate_identifier(self, value):
        value = value.strip()
        kind = identify_contact(value)
        if kind is None:
            raise serializers.ValidationError(
                'Tafadhali weka barua pepe sahihi au namba ya simu sahihi '
                '(mfano: +255712345678).')
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Tayari kuna akaunti na taarifa hizi.')
        if kind == 'email' and User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Barua pepe hii tayari imesajiliwa.')
        if kind == 'phone' and User.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError('Namba hii ya simu tayari imesajiliwa.')
        return value

    def create(self, validated_data):
        identifier = validated_data.pop('identifier')
        categories = validated_data.pop('favorite_categories', [])
        kind = identify_contact(identifier)

        validated_data['username'] = identifier
        if kind == 'email':
            validated_data['email'] = identifier
        else:
            validated_data['phone_number'] = identifier

        password = validated_data.pop('password')
        user = User.objects.create_user(password=password, is_active=False, **validated_data)
        if categories:
            user.favorite_categories.set(categories)

        otp = generate_otp_for_user(user, purpose='register')
        send_otp(user, otp)
        return user


class VerifyOTPSerializer(serializers.Serializer):
    """Thibitisha akaunti mpya kwa kutumia nambari ya OTP iliyotumwa wakati wa usajili."""
    identifier = serializers.CharField()
    code = serializers.CharField()

    def validate(self, attrs):
        identifier = attrs['identifier'].strip()
        code = attrs['code'].strip()

        user = User.objects.filter(
            Q(username=identifier) | Q(email__iexact=identifier) | Q(phone_number=identifier)
        ).first()
        if not user:
            raise serializers.ValidationError('Akaunti haipatikani.')
        if user.is_active:
            raise serializers.ValidationError('Akaunti hii tayari imethibitishwa.')

        otp = OTPCode.objects.filter(
            user=user, purpose='register', code=code).order_by('-created_at').first()
        if not otp or not otp.is_valid():
            raise serializers.ValidationError(
                'Nambari ya OTP si sahihi au imeisha muda wake. Omba nambari mpya.')

        attrs['user'] = user
        attrs['otp'] = otp
        return attrs

    def save(self, **kwargs):
        user = self.validated_data['user']
        otp = self.validated_data['otp']
        otp.is_used = True
        otp.save(update_fields=['is_used'])
        user.is_active = True
        user.save(update_fields=['is_active'])
        return user


class ResendOTPSerializer(serializers.Serializer):
    """Tuma tena nambari ya OTP kwa akaunti isiyothibitishwa bado."""
    identifier = serializers.CharField()

    RESEND_COOLDOWN_SECONDS = 60

    def validate(self, attrs):
        identifier = attrs['identifier'].strip()

        user = User.objects.filter(
            Q(username=identifier) | Q(email__iexact=identifier) | Q(phone_number=identifier)
        ).first()
        if not user:
            raise serializers.ValidationError('Akaunti haipatikani.')
        if user.is_active:
            raise serializers.ValidationError('Akaunti hii tayari imethibitishwa.')

        last_otp = OTPCode.objects.filter(
            user=user, purpose='register').order_by('-created_at').first()
        if last_otp and timezone.now() - last_otp.created_at < timedelta(
                seconds=self.RESEND_COOLDOWN_SECONDS):
            raise serializers.ValidationError(
                'Subiri kidogo kabla ya kuomba nambari mpya.')

        attrs['user'] = user
        return attrs

    def save(self, **kwargs):
        user = self.validated_data['user']
        otp = generate_otp_for_user(user, purpose='register')
        send_otp(user, otp)
        return user


class GoogleAuthSerializer(serializers.Serializer):
    """Ingia/Jisajili kwa akaunti ya Google (ID token kutoka Google Sign-In)."""
    id_token = serializers.CharField(write_only=True)
    referred_by_book_id = serializers.PrimaryKeyRelatedField(
        queryset=Book.objects.all(), source='referred_by_book',
        required=False, allow_null=True, write_only=True)

    def validate_id_token(self, value):
        from google.oauth2 import id_token as google_id_token
        import google.auth.transport.requests

        if not settings.GOOGLE_OAUTH_CLIENT_ID:
            raise serializers.ValidationError('Google haijasanidiwa kwenye mfumo.')
        try:
            idinfo = google_id_token.verify_oauth2_token(
                value, google.auth.transport.requests.Request(),
                audience=settings.GOOGLE_OAUTH_CLIENT_ID)
        except ValueError:
            raise serializers.ValidationError(
                'Imeshindwa kuthibitisha akaunti ya Google. Jaribu tena.')
        if not idinfo.get('email_verified'):
            raise serializers.ValidationError('Barua pepe ya Google haijathibitishwa.')
        return idinfo

    def validate(self, attrs):
        idinfo = attrs['id_token']
        email = idinfo['email']
        user = User.objects.filter(email__iexact=email).first()
        if user and user.is_banned:
            reason = user.ban_reason or 'Umevunja kanuni za jamii.'
            raise serializers.ValidationError(f'Akaunti yako imefungiwa. Sababu: {reason}')
        attrs['user'] = user
        attrs['email'] = email
        return attrs

    def save(self, **kwargs):
        user = self.validated_data['user']
        if user:
            if not user.is_active:
                user.is_active = True
                user.save(update_fields=['is_active'])
            return user

        email = self.validated_data['email']
        username = email
        suffix = 1
        while User.objects.filter(username=username).exists():
            suffix += 1
            username = f'{email}_{suffix}'

        return User.objects.create_user(
            username=username, email=email, password=None, is_active=True,
            referred_by_book=self.validated_data.get('referred_by_book'))
