from django.db import models
from django.conf import settings
from books.models import Book


class Comment(models.Model):
    book       = models.ForeignKey(Book, on_delete=models.CASCADE,
                                   related_name='comments')
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                                   on_delete=models.CASCADE)
    text       = models.TextField()
    parent     = models.ForeignKey('self', null=True, blank=True,
                                   on_delete=models.CASCADE,
                                   related_name='replies')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    # ====== USIMAMIZI WA MAUDHUI / MODERATION ======
    is_flagged        = models.BooleanField(default=False, verbose_name='Imeashiriwa (Lugha Chafu)')
    flagged_words     = models.CharField(max_length=255, blank=True, default='', verbose_name='Maneno Yaliyogunduliwa')
    removed_by_author = models.BooleanField(default=False, verbose_name='Imeondolewa na Mwandishi')

    class Meta:
        ordering = ['created_at']   # oldest first → chat-style scroll

    def __str__(self):
        return f"{self.user.username}: {self.text[:40]}"


class CommentReaction(models.Model):
    """One emoji reaction per user per comment."""
    comment  = models.ForeignKey(Comment, on_delete=models.CASCADE,
                                  related_name='reactions')
    user     = models.ForeignKey(settings.AUTH_USER_MODEL,
                                  on_delete=models.CASCADE)
    emoji    = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('comment', 'user')

    def __str__(self):
        return f"{self.user.username} {self.emoji} → comment#{self.comment_id}"


class Notification(models.Model):
    """Arifa za mfumo wa maoni/chati - mfano: ujumbe mpya, jibu, mwitikio, ripoti."""

    TYPE_CHOICES = (
        ('comment',        'Maoni Mapya'),
        ('reply',          'Jibu Jipya'),
        ('reaction',       'Mwitikio Mpya'),
        ('flagged',        'Ujumbe Umeashiriwa'),
        ('removed',        'Ujumbe Umeondolewa'),
        ('report',         'Ripoti Mpya'),
        ('moderation',     'Taarifa ya Usimamizi'),
        ('author_message', 'Ujumbe kutoka kwa Mwandishi'),
    )

    recipient  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    sender     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='+')
    book       = models.ForeignKey(Book, on_delete=models.CASCADE, null=True, blank=True, related_name='+')
    comment    = models.ForeignKey(Comment, on_delete=models.CASCADE, null=True, blank=True, related_name='+')
    notif_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='comment')
    message    = models.CharField(max_length=255)
    is_read    = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"-> {self.recipient.username}: {self.message[:40]}"


class Report(models.Model):
    """Ripoti ya mtumiaji kuhusu ujumbe wenye lugha chafu/unyanyasaji."""

    REASON_CHOICES = (
        ('profanity',  'Lugha Chafu / Matusi'),
        ('spam',       'Spam'),
        ('harassment', 'Unyanyasaji'),
        ('other',      'Nyingine'),
    )
    STATUS_CHOICES = (
        ('pending',   'Inasubiri Ukaguzi'),
        ('reviewed',  'Imepitiwa'),
        ('dismissed', 'Imeondolewa - Hakuna Hatua'),
        ('actioned',  'Hatua Imechukuliwa'),
    )

    comment     = models.ForeignKey(Comment, on_delete=models.CASCADE, related_name='reports')
    reporter    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reports_made')
    reason      = models.CharField(max_length=20, choices=REASON_CHOICES, default='other')
    details     = models.TextField(blank=True, default='')
    status      = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at  = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ('comment', 'reporter')

    def __str__(self):
        return f"Ripoti #{self.id} - comment#{self.comment_id} ({self.reason})"
