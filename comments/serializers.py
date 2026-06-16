from rest_framework import serializers
from .models import Comment, CommentReaction, Notification, Report
from books.models import Book
from .profanity import clean_text


class ReactionSummarySerializer(serializers.Serializer):
    """Grouped reaction counts: {'❤️': 3, '👍': 1, ...}"""
    emoji = serializers.CharField()
    count = serializers.IntegerField()
    reacted_by_me = serializers.BooleanField()


class CommentSerializer(serializers.ModelSerializer):
    username       = serializers.CharField(source='user.username', read_only=True)
    user_id        = serializers.IntegerField(source='user.id', read_only=True)
    user_avatar    = serializers.SerializerMethodField()
    is_author      = serializers.SerializerMethodField()
    reply_to_user  = serializers.SerializerMethodField()
    reply_preview  = serializers.SerializerMethodField()
    reactions      = serializers.SerializerMethodField()
    replies_count  = serializers.SerializerMethodField()
    display_text   = serializers.SerializerMethodField()
    can_moderate   = serializers.SerializerMethodField()
    reported_by_me = serializers.SerializerMethodField()

    def get_user_avatar(self, obj):
        avatar = getattr(obj.user, 'avatar', None)
        if not avatar:
            return None
        request = self.context.get('request')
        try:
            url = avatar.url
        except ValueError:
            return None
        return request.build_absolute_uri(url) if request else url

    def get_is_author(self, obj):
        """True if comment owner is the book's author."""
        return obj.user_id == obj.book.author_id

    def get_reply_to_user(self, obj):
        if obj.parent:
            return obj.parent.user.username
        return None

    def get_reply_preview(self, obj):
        if obj.parent:
            if obj.parent.is_deleted:
                return '🗑 Ujumbe umefutwa'
            return obj.parent.text[:80] + ('…' if len(obj.parent.text) > 80 else '')
        return None

    def get_reactions(self, obj):
        """Return grouped reactions with my-reaction flag."""
        request = self.context.get('request')
        me_id   = request.user.id if request and request.user.is_authenticated else None
        from collections import Counter
        all_reactions = list(obj.reactions.values_list('emoji', 'user_id'))
        counter = Counter(e for e, _ in all_reactions)
        result = []
        for emoji, count in sorted(counter.items(), key=lambda x: -x[1]):
            reacted = me_id and any(uid == me_id and em == emoji
                                     for em, uid in all_reactions)
            result.append({'emoji': emoji, 'count': count,
                           'reacted_by_me': bool(reacted)})
        return result

    def get_replies_count(self, obj):
        return obj.replies.count()

    def get_display_text(self, obj):
        if obj.is_deleted:
            if obj.removed_by_author:
                return '🚫 Ujumbe umeondolewa na mwandishi kwa kukiuka kanuni'
            return '🗑 Ujumbe huu umefutwa'
        if obj.is_flagged:
            return clean_text(obj.text)
        return obj.text

    def get_can_moderate(self, obj):
        """True if the requesting user is the book's author (can remove/manage)."""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return request.user.id == obj.book.author_id

    def get_reported_by_me(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return obj.reports.filter(reporter=request.user).exists()

    class Meta:
        model  = Comment
        fields = [
            'id', 'book', 'user_id', 'username', 'user_avatar', 'is_author',
            'text', 'display_text', 'is_deleted',
            'parent', 'reply_to_user', 'reply_preview',
            'reactions', 'replies_count',
            'is_flagged', 'can_moderate', 'reported_by_me',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'user_id', 'username', 'user_avatar', 'is_author',
            'reply_to_user', 'reply_preview',
            'reactions', 'replies_count',
            'is_flagged', 'can_moderate', 'reported_by_me',
            'created_at', 'updated_at', 'display_text',
        ]
        extra_kwargs = {'book': {'required': False}}


class NotificationSerializer(serializers.ModelSerializer):
    sender_username = serializers.CharField(source='sender.username', read_only=True, default=None)
    book_title      = serializers.CharField(source='book.title', read_only=True, default=None)

    class Meta:
        model  = Notification
        fields = [
            'id', 'sender', 'sender_username', 'book', 'book_title',
            'comment', 'notif_type', 'message', 'is_read', 'created_at',
        ]
        read_only_fields = fields


class ReportSerializer(serializers.ModelSerializer):
    reporter_username = serializers.CharField(source='reporter.username', read_only=True)

    class Meta:
        model  = Report
        fields = [
            'id', 'comment', 'reporter', 'reporter_username',
            'reason', 'details', 'status', 'created_at', 'reviewed_at',
        ]
        read_only_fields = ['id', 'reporter', 'reporter_username', 'status', 'created_at', 'reviewed_at']
