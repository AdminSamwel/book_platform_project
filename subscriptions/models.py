from django.db import models
from django.conf import settings


class SubscriptionPlan(models.Model):
    LEVEL_CHOICES = [
        (0, 'Bure (Free)'),
        (1, 'Basic'),
        (2, 'Pro'),
        (3, 'Premium'),
    ]

    name = models.CharField(max_length=50)
    price = models.DecimalField(max_digits=8, decimal_places=2)
    duration_days = models.IntegerField()
    max_books = models.IntegerField(default=-1)  # -1 = unlimited
    level = models.PositiveSmallIntegerField(
        default=0, choices=LEVEL_CHOICES,
        help_text='Kiwango cha mpango: kadiri kinavyopanda ndivyo unavyopata vitabu zaidi')
    features = models.JSONField(
        default=list, blank=True,
        help_text='Orodha ya faida za mpango huu (zinazoonekana kwa mtumiaji)')

    class Meta:
        ordering = ['level']

    def __str__(self):
        return self.name


class UserSubscription(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True)
    start_date = models.DateTimeField(auto_now_add=True)
    end_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.user.username} - {self.plan.name if self.plan else 'N/A'}"


class SystemSettings(models.Model):
    """Mipangilio ya mfumo inayoweza kubadilishwa na msimamizi (singleton)."""
    basic_book_limit = models.PositiveIntegerField(
        default=5,
        verbose_name='Idadi ya vitabu vya Basic',
        help_text='Idadi ya vitabu vya kulipa ambavyo msomaji wa Basic anaweza kusoma kwa kipindi')
    pro_audio_limit = models.PositiveIntegerField(
        default=5,
        verbose_name='Idadi ya vitabu vya sauti vya Pro',
        help_text='Idadi ya juu ya vitabu vya sauti ambavyo msomaji wa Pro anaweza kufungua')

    class Meta:
        verbose_name = 'Mipangilio ya Mfumo'
        verbose_name_plural = 'Mipangilio ya Mfumo'

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    @classmethod
    def get(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj

    def __str__(self):
        return f'Mipangilio (Basic: {self.basic_book_limit}, Sauti Pro: {self.pro_audio_limit})'


class FreeBookSelection(models.Model):
    """Hifadhi kitabu kimoja cha kulipa ambacho msomaji wa mpango wa bure amechagua (mara moja tu)."""
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='free_book_selection'
    )
    book = models.ForeignKey(
        'books.Book',
        on_delete=models.CASCADE,
        related_name='free_selections'
    )
    selected_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.username} → {self.book.title}'


class SubscriptionBookAccess(models.Model):
    """Rekodi ya vitabu vilivyofunguliwa kupitia usajili katika kipindi cha usajili."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='subscription_accesses'
    )
    book = models.ForeignKey(
        'books.Book',
        on_delete=models.CASCADE,
        related_name='subscription_accesses'
    )
    subscription = models.ForeignKey(
        UserSubscription,
        on_delete=models.CASCADE,
        related_name='book_accesses'
    )
    first_accessed = models.DateTimeField(auto_now_add=True)
    is_audio = models.BooleanField(default=False)

    class Meta:
        unique_together = ('user', 'book', 'subscription')

    def __str__(self):
        return f'{self.user.username} → {self.book.title}'
