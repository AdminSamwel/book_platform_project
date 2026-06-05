from rest_framework import generics, permissions
from .models import Comment
from .serializers import CommentSerializer

class CommentListCreateView(generics.ListCreateAPIView):
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        book_id = self.kwargs['book_id']
        return Comment.objects.filter(book_id=book_id).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(user=self.request.user, book_id=self.kwargs['book_id'])