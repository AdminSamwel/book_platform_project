from rest_framework import generics, permissions, filters
from django_filters.rest_framework import DjangoFilterBackend
from .models import Book, Category
from .serializers import BookListSerializer, BookDetailSerializer, CategorySerializer
from .permissions import IsAuthorOrReadOnly  # tutatengeneza muda si mrefu

class BookListView(generics.ListAPIView):
    queryset = Book.objects.filter(is_published=True)
    serializer_class = BookListSerializer
    permission_classes = [permissions.AllowAny]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['category__slug', 'is_free']
    search_fields = ['title', 'author__username']
    ordering_fields = ['price', 'created_at']

class BookDetailView(generics.RetrieveAPIView):
    queryset = Book.objects.filter(is_published=True)
    serializer_class = BookDetailSerializer
    permission_classes = [permissions.AllowAny]

class BookCreateView(generics.CreateAPIView):
    serializer_class = BookDetailSerializer
    permission_classes = [permissions.IsAuthenticated]  # Kwa sasa, anayeruhusiwa anaweza kutengeneza
    def perform_create(self, serializer):
        book = serializer.save(author=self.request.user)
        book.encrypt_content()
        book.save()

class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]
    
from django.http import StreamingHttpResponse, HttpResponseForbidden
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Book
from payments.models import Purchase
from subscriptions.models import UserSubscription
from django.utils import timezone

class BookContentView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        try:
            book = Book.objects.get(pk=book_id, is_published=True)
        except Book.DoesNotExist:
            return Response({"detail": "Hakuna kitabu hiki."}, status=404)

        # Angalia ruhusa
        has_access = False
        if book.is_free:
            has_access = True
        elif Purchase.objects.filter(user=request.user, book=book).exists():
            has_access = True
        elif UserSubscription.objects.filter(user=request.user, is_active=True, end_date__gt=timezone.now()).exists():
            has_access = True
        elif request.user == book.author:
            has_access = True
        if not has_access:
            return HttpResponseForbidden("Haujaidhinishwa kusoma kitabu hiki.")

        # Soma maudhui yaliyosimbwa
        try:
            decrypted = book.decrypt_content()
        except Exception as e:
            return Response({"detail": "Hitilafu ya kusoma faili."}, status=500)

        response = StreamingHttpResponse(
            iter([decrypted]),
            content_type='text/plain; charset=utf-8'
        )
        response['Content-Disposition'] = 'inline'  # isiwe attachment
        return response