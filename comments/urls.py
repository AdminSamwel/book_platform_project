from django.urls import path
from .views import (
    CommentListCreateView, CommentDeleteView, CommentReactionView,
    ReportCommentView, NotificationListView, NotificationUnreadCountView,
    NotificationMarkReadView, AuthorBroadcastView,
)

urlpatterns = [
    path('<int:book_id>/',
         CommentListCreateView.as_view(), name='comment-list'),
    path('<int:book_id>/<int:comment_id>/delete/',
         CommentDeleteView.as_view(), name='comment-delete'),
    path('<int:book_id>/<int:comment_id>/react/',
         CommentReactionView.as_view(), name='comment-react'),
    path('<int:book_id>/<int:comment_id>/report/',
         ReportCommentView.as_view(), name='comment-report'),
    path('<int:book_id>/broadcast/',
         AuthorBroadcastView.as_view(), name='author-broadcast'),

    # ====== ARIFA / NOTIFICATIONS ======
    path('notifications/', NotificationListView.as_view(), name='notification-list'),
    path('notifications/unread-count/', NotificationUnreadCountView.as_view(), name='notification-unread-count'),
    path('notifications/read-all/', NotificationMarkReadView.as_view(), name='notification-read-all'),
    path('notifications/<int:notif_id>/read/', NotificationMarkReadView.as_view(), name='notification-read'),
]
