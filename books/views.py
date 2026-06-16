from rest_framework import generics, permissions, filters, serializers
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status as drf_status
from django.http import StreamingHttpResponse, HttpResponseForbidden
from django.db.models import Count, Avg
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend
from django.utils import timezone
from .models import Book, Category, Rating, BookShareClick
from .serializers import BookListSerializer, BookDetailSerializer, CategorySerializer, RatingSerializer
from payments.models import Purchase
from subscriptions.models import UserSubscription
from royalties.services import record_reading_event

class BookListView(generics.ListAPIView):
    serializer_class = BookListSerializer
    permission_classes = [permissions.AllowAny]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category__slug', 'is_free']
    search_fields = ['title', 'author__username']
    ordering_fields = ['price', 'created_at', 'purchases_count', 'avg_rating']

    def get_queryset(self):
        qs = Book.objects.filter(is_published=True).annotate(
            purchases_count=Count('purchase', distinct=True),
            avg_rating=Avg('ratings__score'),
        )

        # Vitabu vya makundi anayopenda msomaji ("kwa ajili yako")
        for_you = self.request.query_params.get('for_you')
        if for_you in ('1', 'true', 'True') and self.request.user.is_authenticated:
            cat_ids = list(self.request.user.favorite_categories.values_list('id', flat=True))
            if cat_ids:
                qs = qs.filter(category_id__in=cat_ids)

        return qs

class BookDetailView(generics.RetrieveAPIView):
    queryset = Book.objects.filter(is_published=True)
    serializer_class = BookDetailSerializer
    permission_classes = [permissions.AllowAny]

class BookCreateView(generics.CreateAPIView):
    serializer_class   = BookDetailSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        book = serializer.save(author=self.request.user)
        try:
            if book.raw_file:
                book.encrypt_content()
            if book.audio_file:
                book.encrypt_audio()
            book.save()
        except Exception as e:
            book.delete()
            raise serializers.ValidationError(
                {'detail': f'Hitilafu ya kusimba faili: {str(e)}'})

    def create(self, request, *args, **kwargs):
        if request.user.role != 'author':
            from rest_framework.response import Response
            from rest_framework import status
            return Response(
                {'detail': 'Ni mwandishi peke yake anayeweza kupakia vitabu.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().create(request, *args, **kwargs)

class BookUpdateView(APIView):
    """Mwandishi anaweza kuhariri taarifa za kitabu chake"""
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, book_id):
        from rest_framework.response import Response
        from rest_framework import status as drf_status
        from django.core.files.base import ContentFile

        try:
            book = Book.objects.get(pk=book_id, author=request.user)
        except Book.DoesNotExist:
            return Response(
                {'detail': 'Kitabu hakipatikani au huna ruhusa ya kuhariri.'},
                status=drf_status.HTTP_404_NOT_FOUND)

        # Hariri sehemu zilizotumwa tu
        data = request.data

        if 'title' in data:
            book.title = data['title']
        if 'description' in data:
            book.description = data['description']
        if 'price' in data:
            book.price = data['price']
        if 'is_free' in data:
            val = data['is_free']
            book.is_free = val in [True, 'true', '1', 'True'] if not isinstance(val, bool) else val
        if 'category' in data and data['category']:
            try:
                book.category = Category.objects.get(pk=int(data['category']))
            except (Category.DoesNotExist, ValueError):
                pass
        if 'is_published' in data:
            val = data['is_published']
            book.is_published = val in [True, 'true', '1', 'True'] if not isinstance(val, bool) else val
        if 'min_plan_level' in data:
            try:
                level = int(data['min_plan_level'])
                if level in dict(Book.PLAN_LEVEL_CHOICES):
                    book.min_plan_level = level
            except (TypeError, ValueError):
                pass
        if 'min_age' in data:
            try:
                min_age = int(data['min_age'])
                if min_age in dict(Book.MIN_AGE_CHOICES):
                    book.min_age = min_age
            except (TypeError, ValueError):
                pass

        # Picha ya jalada — kama imepelekwa
        if 'cover_image' in request.FILES:
            book.cover_image = request.FILES['cover_image']

        # Faili jipya la kitabu — simba tena
        if 'raw_file' in request.FILES:
            book.raw_file = request.FILES['raw_file']
            try:
                book.encrypt_content()
            except Exception as e:
                return Response(
                    {'detail': f'Hitilafu ya kusimba faili: {str(e)}'},
                    status=drf_status.HTTP_500_INTERNAL_SERVER_ERROR)

        # Faili jipya la sauti — simba tena
        if 'audio_file' in request.FILES:
            book.audio_file = request.FILES['audio_file']
            try:
                book.encrypt_audio()
            except Exception as e:
                return Response(
                    {'detail': f'Hitilafu ya kusimba sauti: {str(e)}'},
                    status=drf_status.HTTP_500_INTERNAL_SERVER_ERROR)

        book.save()

        serializer = BookDetailSerializer(book)
        return Response(serializer.data)

    def get(self, request, book_id):
        """Pata taarifa za kitabu kwa mwandishi (hata kama haijachapishwa)"""
        from rest_framework.response import Response
        from rest_framework import status as drf_status
        try:
            book = Book.objects.get(pk=book_id, author=request.user)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipatikani.'}, status=drf_status.HTTP_404_NOT_FOUND)
        serializer = BookDetailSerializer(book)
        return Response(serializer.data)


class AuthorBooksView(APIView):
    """Vitabu vyote vya mwandishi (pamoja na visivyochapishwa)"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from rest_framework.response import Response
        if request.user.role != 'author':
            return Response({'detail': 'Ruhusa ya mwandishi inahitajika.'}, status=403)
        books = Book.objects.filter(author=request.user).order_by('-created_at')
        serializer = BookDetailSerializer(books, many=True)
        return Response(serializer.data)


class BookShareStatsView(APIView):
    """Mwandishi anaona takwimu za kushare kitabu chake (clicks kwa kila
    mtandao na idadi ya watu walioandikishwa kupitia link hiyo)."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = Book.objects.get(pk=book_id, author=request.user)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipatikani au huna ruhusa.'}, status=404)

        shares = BookShareClick.objects.filter(book=book)
        by_platform = dict(
            shares.values('platform').annotate(count=Count('id'))
                  .values_list('platform', 'count')
        )

        return Response({
            'total_clicks': shares.count(),
            'by_platform': by_platform,
            'signups': book.referred_signups.count(),
        })


class CategoryListView(generics.ListAPIView):
    queryset           = Category.objects.all()
    serializer_class   = CategorySerializer
    permission_classes = [permissions.AllowAny]

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx
    
class BookContentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = Book.objects.get(pk=book_id, is_published=True)
        except Book.DoesNotExist:
            return Response({"detail": "Hakuna kitabu hiki."}, status=404)

        # Angalia ruhusa
        if not _has_book_access(request.user, book):
            if not _meets_min_age(request.user, book.min_age):
                return HttpResponseForbidden(
                    f"Kitabu hiki ni kwa wasomaji wenye umri wa miaka {book.min_age}+.")
            return HttpResponseForbidden("Haujaidhinishwa kusoma kitabu hiki.")

        _track_subscription_read(request.user, book)

        # Soma maudhui yaliyosimbwa
        try:
            decrypted = book.decrypt_content()
        except Exception as e:
            return Response({"detail": f"Hitilafu ya kusoma faili: {str(e)}"}, status=500)

        # Chagua content type kulingana na aina ya faili
        raw_name = book.raw_file.name.lower() if book.raw_file else ''
        if raw_name.endswith('.pdf'):
            content_type = 'application/pdf'
        elif raw_name.endswith('.epub'):
            content_type = 'application/epub+zip'
        else:
            content_type = 'text/plain; charset=utf-8'

        response = StreamingHttpResponse(
            iter([decrypted]),
            content_type=content_type,
        )
        # Zuia download — lazima isomwe ndani ya app tu
        response['Content-Disposition']       = 'inline'
        response['X-Content-Type-Options']    = 'nosniff'
        response['Cache-Control']             = 'no-store, no-cache, must-revalidate, private'
        response['Pragma']                    = 'no-cache'
        response['X-Frame-Options']           = 'SAMEORIGIN'
        response['Access-Control-Allow-Origin'] = 'http://localhost:8000'
        return response


class AudioContentView(APIView):
    """Stream sauti ya kitabu — imesimbwa, haiwezi kupakuliwa"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = Book.objects.get(pk=book_id, is_published=True)
        except Book.DoesNotExist:
            return Response({"detail": "Hakuna kitabu hiki."}, status=404)

        # Angalia kama kuna sauti
        if not book.has_audio:
            return Response({"detail": "Kitabu hiki hakina sauti."}, status=404)

        # Angalia ruhusa — sauti inahitaji is_audio=True ili kupima kikomo cha Pro
        if not _has_book_access(request.user, book, is_audio=True):
            if not _meets_min_age(request.user, book.min_age):
                return HttpResponseForbidden(
                    f"Kitabu hiki ni kwa wasomaji wenye umri wa miaka {book.min_age}+.")
            return HttpResponseForbidden("Haujaidhinishwa kusikiliza kitabu hiki.")

        _track_subscription_read(request.user, book)

        try:
            if book.encrypted_audio:
                audio_data = book.decrypt_audio()
            else:
                # Kama sauti haijasimbwa, soma moja kwa moja
                with book.audio_file.open('rb') as f:
                    audio_data = f.read()
        except Exception as e:
            return Response(
                {"detail": f"Hitilafu ya kusoma sauti: {str(e)}"}, status=500)

        content_type = book.get_audio_content_type()
        response = StreamingHttpResponse(
            iter([audio_data]),
            content_type=content_type,
        )
        response['Content-Disposition']    = 'inline'
        response['X-Content-Type-Options'] = 'nosniff'
        response['Cache-Control']          = 'no-store, no-cache, private'
        response['Pragma']                 = 'no-cache'
        response['Access-Control-Allow-Origin'] = 'http://localhost:8000'
        return response


def _meets_min_age(user, min_age):
    """Angalia kama mtumiaji amefikia umri wa chini unaohitajika."""
    if not min_age:
        return True
    if not user.is_authenticated:
        return False
    age = user.age
    if age is None:
        return False
    return age >= min_age


def _has_book_access(user, book, is_audio=False):
    """Angalia ruhusa ya kusoma/kusikiliza kitabu kulingana na mpango wa usajili."""
    from subscriptions.models import (
        UserSubscription, SystemSettings,
        FreeBookSelection, SubscriptionBookAccess,
    )

    if user.is_authenticated and user == book.author:
        return True
    if not _meets_min_age(user, book.min_age):
        return False
    if book.is_free:
        return True
    if not user.is_authenticated:
        return False
    # Ununuzi wa moja kwa moja — daima unafungua kitabu
    if Purchase.objects.filter(user=user, book=book).exists():
        return True

    # Angalia usajili hai
    sub = UserSubscription.objects.filter(
        user=user, is_active=True, end_date__gt=timezone.now()
    ).select_related('plan').first()
    if not sub or not sub.plan:
        return False

    plan_level = sub.plan.level

    # Premium/Unlimited (level 3) — vitabu vyote
    if plan_level >= 3:
        return True

    # Ikiwa tayari ameshafungua kitabu hiki katika usajili huu — ruhusu
    existing = SubscriptionBookAccess.objects.filter(
        user=user, book=book, subscription=sub).first()
    if existing:
        return True

    s = SystemSettings.get()
    basic_limit = s.basic_book_limit

    # Pro (level 2) — vitabu 2× basic + sauti hadi pro_audio_limit
    if plan_level == 2:
        pro_limit = basic_limit * 2
        if is_audio:
            audio_used = SubscriptionBookAccess.objects.filter(
                user=user, subscription=sub, is_audio=True
            ).values('book').distinct().count()
            if audio_used >= s.pro_audio_limit:
                return False
        total_used = SubscriptionBookAccess.objects.filter(
            user=user, subscription=sub
        ).values('book').distinct().count()
        if total_used >= pro_limit:
            return False
        SubscriptionBookAccess.objects.get_or_create(
            user=user, book=book, subscription=sub,
            defaults={'is_audio': is_audio})
        return True

    # Basic (level 1) — vitabu hadi basic_limit, hakuna sauti
    if plan_level == 1:
        if is_audio or getattr(book, 'has_audio', False) and not book.raw_file:
            return False
        total_used = SubscriptionBookAccess.objects.filter(
            user=user, subscription=sub
        ).values('book').distinct().count()
        if total_used >= basic_limit:
            return False
        SubscriptionBookAccess.objects.get_or_create(
            user=user, book=book, subscription=sub,
            defaults={'is_audio': False})
        return True

    # Free (level 0) — kitabu kimoja kilichochaguliwa tu
    if plan_level == 0:
        try:
            sel = FreeBookSelection.objects.get(user=user)
            return sel.book_id == book.pk
        except FreeBookSelection.DoesNotExist:
            return False

    return False


def _track_subscription_read(user, book):
    """Kama kitabu siyo cha bure na mtumiaji anakipata kwa njia ya usajili wa
    kila mwezi (siyo ununuzi/mwandishi mwenyewe), rekodi ReadingEvent ili
    kitumike kugawanya kasha la mapato ya usajili mwishoni mwa mwezi."""
    if book.is_free or not user.is_authenticated or user == book.author:
        return
    if Purchase.objects.filter(user=user, book=book).exists():
        return
    if UserSubscription.objects.filter(
            user=user, is_active=True, end_date__gt=timezone.now()).exists():
        record_reading_event(user, book)


class BookRatingsView(generics.ListAPIView):
    """Orodha ya tathmini (nyota) na maoni ya wasomaji kuhusu kitabu - hadharani."""
    serializer_class = RatingSerializer
    permission_classes = [permissions.AllowAny]

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx

    def get_queryset(self):
        return Rating.objects.filter(book_id=self.kwargs['book_id']).select_related('user')


class RateBookView(APIView):
    """Msomaji anaweka/anabadilisha tathmini (nyota 1-5) na maoni ya kitabu
    baada ya kuwa na ruhusa ya kukisoma (amenunua/amejiandikisha/kitabu ni bure)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id, is_published=True)

        if not _has_book_access(request.user, book):
            return Response(
                {'detail': 'Lazima usome kitabu kwanza kabla ya kukitathmini.'},
                status=drf_status.HTTP_403_FORBIDDEN)

        score = request.data.get('score')
        comment = request.data.get('comment', '')
        try:
            score = int(score)
        except (TypeError, ValueError):
            return Response({'detail': 'Nyota (score) si sahihi.'}, status=drf_status.HTTP_400_BAD_REQUEST)
        if not (1 <= score <= 5):
            return Response({'detail': 'Nyota lazima iwe kati ya 1 na 5.'}, status=drf_status.HTTP_400_BAD_REQUEST)

        rating, _created = Rating.objects.update_or_create(
            book=book, user=request.user,
            defaults={'score': score, 'comment': comment},
        )
        serializer = RatingSerializer(rating, context={'request': request})
        return Response(serializer.data, status=drf_status.HTTP_200_OK)

    def get(self, request, book_id):
        """Pata tathmini ya mtumiaji mwenyewe kuhusu kitabu hiki (kama ipo)."""
        try:
            rating = Rating.objects.get(book_id=book_id, user=request.user)
        except Rating.DoesNotExist:
            return Response({'detail': 'Hakuna tathmini bado.'}, status=drf_status.HTTP_404_NOT_FOUND)
        serializer = RatingSerializer(rating, context={'request': request})
        return Response(serializer.data)

    def delete(self, request, book_id):
        Rating.objects.filter(book_id=book_id, user=request.user).delete()
        return Response(status=drf_status.HTTP_204_NO_CONTENT)