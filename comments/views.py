from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone
from .models import Comment, CommentReaction, Notification, Report
from .serializers import CommentSerializer, NotificationSerializer, ReportSerializer
from .profanity import contains_profanity, find_bad_words
from books.models import Book
from payments.models import Purchase
from subscriptions.models import UserSubscription


class CommentListCreateView(generics.ListCreateAPIView):
    """GET all comments for a book (flat list, ordered oldest→newest).
       POST creates a new top-level comment or reply (parent field optional)."""
    serializer_class   = CommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        book_id = self.kwargs['book_id']
        # Return ALL comments (including replies) ordered oldest first
        return (Comment.objects
                .filter(book_id=book_id)
                .select_related('user', 'book', 'parent__user')
                .prefetch_related('reactions', 'replies', 'reports')
                .order_by('created_at'))

    def get_serializer_context(self):
        ctx = super().get_serializer_context()
        ctx['request'] = self.request
        return ctx

    def create(self, request, *args, **kwargs):
        if request.user.is_authenticated and getattr(request.user, 'is_banned', False):
            return Response(
                {'detail': 'Akaunti yako imefungiwa kuandika maoni kwa kukiuka kanuni za mfumo.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().create(request, *args, **kwargs)

    def perform_create(self, serializer):
        book   = get_object_or_404(Book, pk=self.kwargs['book_id'])
        parent = serializer.validated_data.pop('parent', None)
        text   = serializer.validated_data.get('text', '')

        # ====== KICHUJIO CHA LUGHA CHAFU ======
        bad_words = find_bad_words(text)
        is_flagged = bool(bad_words)

        comment = serializer.save(
            user=self.request.user,
            book=book,
            parent=parent,
            is_flagged=is_flagged,
            flagged_words=', '.join(bad_words)[:255],
        )

        self._send_notifications(comment, book, parent)

    def _send_notifications(self, comment, book, parent):
        sender = comment.user
        notifs = []

        if parent is not None:
            # Ni jibu - mjulishe mwenye ujumbe aliyojibiwa (kama si yeye mwenyewe)
            if parent.user_id != sender.id:
                notifs.append(Notification(
                    recipient=parent.user, sender=sender, book=book, comment=comment,
                    notif_type='reply',
                    message=f"{sender.username} amejibu ujumbe wako kwenye \"{book.title}\"",
                ))
            # Pia mjulishe mwandishi wa kitabu kama si mwenye ujumbe aliyejibiwa wala mtumaji
            if book.author_id != sender.id and book.author_id != parent.user_id:
                notifs.append(Notification(
                    recipient=book.author, sender=sender, book=book, comment=comment,
                    notif_type='reply',
                    message=f"{sender.username} amejibu ujumbe kwenye mjadala wa \"{book.title}\"",
                ))
        else:
            # Maoni mapya - mjulishe mwandishi wa kitabu (kama si yeye mwenyewe)
            if book.author_id != sender.id:
                notifs.append(Notification(
                    recipient=book.author, sender=sender, book=book, comment=comment,
                    notif_type='comment',
                    message=f"{sender.username} ameacha ujumbe mpya kwenye \"{book.title}\"",
                ))

        # Kama ujumbe una lugha chafu, mjulishe mwandishi wa kitabu kwa ukaguzi
        if comment.is_flagged and book.author_id != sender.id:
            notifs.append(Notification(
                recipient=book.author, sender=sender, book=book, comment=comment,
                notif_type='flagged',
                message=f"⚠️ Ujumbe wenye lugha isiyofaa umegunduliwa kwenye \"{book.title}\" kutoka kwa {sender.username}",
            ))

        if notifs:
            Notification.objects.bulk_create(notifs)


class CommentDeleteView(APIView):
    """Soft-delete own comment. Authors can delete any comment on their book."""
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, book_id, comment_id):
        comment = get_object_or_404(Comment, pk=comment_id, book_id=book_id)
        book    = comment.book
        # Allow: owner of comment OR author of the book
        if request.user != comment.user and request.user != book.author:
            return Response({'detail': 'Huna ruhusa.'},
                            status=status.HTTP_403_FORBIDDEN)

        removed_by_author = (request.user == book.author and request.user != comment.user)

        comment.is_deleted        = True
        comment.removed_by_author = removed_by_author
        comment.text              = ''
        comment.save(update_fields=['is_deleted', 'text', 'removed_by_author'])

        if removed_by_author:
            Notification.objects.create(
                recipient=comment.user, sender=request.user, book=book, comment=comment,
                notif_type='removed',
                message=f"Ujumbe wako kwenye \"{book.title}\" umeondolewa na mwandishi kwa kukiuka kanuni za jamii.",
            )

        return Response(status=status.HTTP_204_NO_CONTENT)


class CommentReactionView(APIView):
    """Toggle an emoji reaction on a comment.
       POST {'emoji': '❤️'} → adds reaction (or updates existing).
       If user already reacted with same emoji → removes it (toggle)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id, comment_id):
        comment = get_object_or_404(Comment, pk=comment_id, book_id=book_id)
        emoji   = request.data.get('emoji', '').strip()
        if not emoji:
            return Response({'detail': 'Toa emoji.'},
                            status=status.HTTP_400_BAD_REQUEST)

        existing = CommentReaction.objects.filter(
            comment=comment, user=request.user).first()

        if existing:
            if existing.emoji == emoji:
                # Same emoji → remove (toggle off)
                existing.delete()
                action = 'removed'
            else:
                # Different emoji → update
                existing.emoji = emoji
                existing.save(update_fields=['emoji'])
                action = 'updated'
        else:
            CommentReaction.objects.create(
                comment=comment, user=request.user, emoji=emoji)
            action = 'added'

            # Mjulishe mwenye ujumbe kuhusu mwitikio mpya (siyo kwake mwenyewe)
            if comment.user_id != request.user.id:
                Notification.objects.create(
                    recipient=comment.user, sender=request.user,
                    book=comment.book, comment=comment,
                    notif_type='reaction',
                    message=f"{request.user.username} amejibu ujumbe wako kwa {emoji}",
                )

        # Return fresh comment data
        serializer = CommentSerializer(comment,
                                       context={'request': request})
        return Response({'action': action, 'reactions': serializer.data['reactions']})


class ReportCommentView(APIView):
    """Ripoti ujumbe kwa mfumo (kwa lugha chafu, unyanyasaji, n.k)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id, comment_id):
        comment = get_object_or_404(Comment, pk=comment_id, book_id=book_id)

        if comment.user_id == request.user.id:
            return Response({'detail': 'Huwezi kuripoti ujumbe wako mwenyewe.'},
                            status=status.HTTP_400_BAD_REQUEST)

        reason  = request.data.get('reason', 'other')
        details = request.data.get('details', '')

        report, created = Report.objects.get_or_create(
            comment=comment, reporter=request.user,
            defaults={'reason': reason, 'details': details},
        )
        if not created:
            return Response({'detail': 'Tayari umeshariport ujumbe huu.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Mjulishe mwandishi wa kitabu kuhusu ripoti
        book = comment.book
        if book.author_id != request.user.id:
            Notification.objects.create(
                recipient=book.author, sender=request.user, book=book, comment=comment,
                notif_type='report',
                message=f"{request.user.username} ameripoti ujumbe wa {comment.user.username} kwenye \"{book.title}\"",
            )

        serializer = ReportSerializer(report)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class AuthorBroadcastView(APIView):
    """Mwandishi anatuma ujumbe kwa wasomaji wote waliosoma kitabu chake
       (wamenunua au wana usajili (subscription) hai). Ujumbe huambatana
       na tag ya jina la kitabu, mfano: '📢 [Jina la Kitabu] ujumbe...'."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id)
        if request.user != book.author:
            return Response({'detail': 'Huna ruhusa kutuma ujumbe kwa kitabu hiki.'},
                            status=status.HTTP_403_FORBIDDEN)

        text = request.data.get('message', '').strip()
        if not text:
            return Response({'detail': 'Andika ujumbe kwanza.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Wasomaji waliosoma kitabu hiki: wamenunua AU wana usajili (subscription) hai
        buyer_ids = set(Purchase.objects.filter(book=book).values_list('user_id', flat=True))
        sub_ids   = set(UserSubscription.objects.filter(
            is_active=True, end_date__gte=timezone.now()
        ).values_list('user_id', flat=True))

        recipient_ids = (buyer_ids | sub_ids) - {request.user.id}

        notifs = [
            Notification(
                recipient_id=uid, sender=request.user, book=book,
                notif_type='author_message',
                message=f"📢 [{book.title}] {text}",
            )
            for uid in recipient_ids
        ]
        Notification.objects.bulk_create(notifs)

        return Response({'sent_to': len(notifs)}, status=status.HTTP_201_CREATED)


class NotificationListView(generics.ListAPIView):
    """Orodha ya arifa za mtumiaji aliyeingia, mpya kwanza."""
    serializer_class   = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user).select_related('sender', 'book')


class NotificationUnreadCountView(APIView):
    """Idadi ya arifa ambazo bado hazijasomwa."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(recipient=request.user, is_read=False).count()
        return Response({'unread_count': count})


class NotificationMarkReadView(APIView):
    """Weka arifa moja (au zote) kama zimesomwa.
       POST /notifications/<id>/read/  -> arifa moja
       POST /notifications/read-all/   -> zote (id=0)"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, notif_id=None):
        if notif_id:
            notif = get_object_or_404(Notification, pk=notif_id, recipient=request.user)
            notif.is_read = True
            notif.save(update_fields=['is_read'])
        else:
            Notification.objects.filter(recipient=request.user, is_read=False).update(is_read=True)
        return Response({'status': 'ok'})
