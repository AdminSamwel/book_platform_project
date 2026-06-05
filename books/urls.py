from django.urls import path
from .views import BookContentView, BookListView, BookDetailView, BookCreateView, CategoryListView

urlpatterns = [
    path('', BookListView.as_view(), name='book-list'),
    path('<int:pk>/', BookDetailView.as_view(), name='book-detail'),
    path('create/', BookCreateView.as_view(), name='book-create'),
    path('categories/', CategoryListView.as_view(), name='category-list'),
    path('<int:book_id>/content/', BookContentView.as_view(), name='book-content'),
]