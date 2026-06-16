from django.urls import path
from .views import (
    BookContentView, BookListView, BookDetailView,
    BookCreateView, BookUpdateView, AuthorBooksView,
    CategoryListView, AudioContentView,
    BookRatingsView, RateBookView, BookShareStatsView,
)

urlpatterns = [
    path('', BookListView.as_view(), name='book-list'),
    path('<int:pk>/', BookDetailView.as_view(), name='book-detail'),
    path('create/', BookCreateView.as_view(), name='book-create'),
    path('<int:book_id>/edit/', BookUpdateView.as_view(), name='book-edit'),
    path('my-books/', AuthorBooksView.as_view(), name='author-books'),
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('<int:book_id>/content/', BookContentView.as_view(), name='book-content'),
    path('<int:book_id>/audio/', AudioContentView.as_view(), name='book-audio'),
    path('<int:book_id>/ratings/', BookRatingsView.as_view(), name='book-ratings'),
    path('<int:book_id>/rate/', RateBookView.as_view(), name='book-rate'),
    path('<int:book_id>/share-stats/', BookShareStatsView.as_view(), name='book-share-stats'),
]
