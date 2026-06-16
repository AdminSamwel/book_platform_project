from django.contrib import admin
from django.utils import timezone
from .models import Comment, CommentReaction, Notification, Report


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display  = ('id', 'user', 'book', 'is_flagged', 'is_deleted', 'removed_by_author', 'created_at')
    list_filter   = ('is_flagged', 'is_deleted', 'removed_by_author')
    search_fields = ('text', 'user__username', 'book__title')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display  = ('id', 'recipient', 'sender', 'notif_type', 'message', 'is_read', 'created_at')
    list_filter   = ('notif_type', 'is_read')
    search_fields = ('recipient__username', 'message')


def ban_reported_user(modeladmin, request, queryset):
    """Fungia akaunti za watumiaji walioripotiwa kwenye ripoti zilizochaguliwa."""
    count = 0
    for report in queryset:
        user = report.comment.user
        if not user.is_banned:
            user.is_banned  = True
            user.ban_reason = f"Kuripotiwa mara kwa mara: {report.get_reason_display()}"
            user.banned_at  = timezone.now()
            user.save(update_fields=['is_banned', 'ban_reason', 'banned_at'])
            count += 1
        report.status = 'actioned'
        report.reviewed_at = timezone.now()
        report.save(update_fields=['status', 'reviewed_at'])
    modeladmin.message_user(request, f"Watumiaji {count} wamefungiwa.")


ban_reported_user.short_description = "Fungia akaunti ya mtumiaji aliyeripotiwa"


def dismiss_report(modeladmin, request, queryset):
    queryset.update(status='dismissed', reviewed_at=timezone.now())


dismiss_report.short_description = "Ondoa ripoti (hakuna hatua)"


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display  = ('id', 'comment', 'reporter', 'reason', 'status', 'created_at')
    list_filter   = ('reason', 'status')
    search_fields = ('comment__text', 'reporter__username')
    actions = [ban_reported_user, dismiss_report]


admin.site.register(CommentReaction)
