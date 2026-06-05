from django.urls import path
from .views import CommentListCreateView

urlpatterns = [
    path('<int:book_id>/', CommentListCreateView.as_view(), name='comment-list'),
]