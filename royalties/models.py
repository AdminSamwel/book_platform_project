from django.db import models
from django.conf import settings
from django.utils import timezone
from books.models import Book


class PlatformSettings(models.Model):
    """Mipangilio ya jumla ya ugawanyaji wa mapato (singleton - rekodi moja tu)."""
    purchase_commission_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=15,
        help_text='Asilimia ya mfumo (admin) kutoka kwa mauzo ya moja kwa moja ya '
                   'vitabu (mtumiaji ananunua kitabu maisha yote)')
    subscription_commission_percent = models.DecimalField(
        max_digits=5, decimal_places=2, default=30,
        help_text='Asilimia ya mfumo (admin) kutoka kwa mapato yote ya usajili wa '
                   'kila mwezi, kabla ya kugawanywa kwa waandishi kulingana na usomaji')

    class Meta:
        verbose_name = 'Mipangilio ya Mapato'
        verbose_name_plural = 'Mipangilio ya Mapato'

    def __str__(self):
        return 'Mipangilio ya Ugawanyaji wa Mapato'

    @classmethod
    def load(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class SubscriptionRevenuePool(models.Model):
    """Kasha la mapato ya usajili kwa mwezi husika - litakalogawanywa kwa
    waandishi kulingana na uwiano wa usomaji wa vitabu vyao na watumiaji
    wenye usajili hai."""
    year = models.PositiveIntegerField()
    month = models.PositiveSmallIntegerField()
    total_revenue = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    distributed = models.BooleanField(default=False)
    distributed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ('year', 'month')
        ordering = ['-year', '-month']
        verbose_name = 'Kasha la Mapato ya Usajili'
        verbose_name_plural = 'Makasha ya Mapato ya Usajili'

    def __str__(self):
        return f'{self.year}-{self.month:02d}: TZS {self.total_revenue}'

    @classmethod
    def add_revenue(cls, amount):
        now = timezone.now()
        pool, _ = cls.objects.get_or_create(year=now.year, month=now.month)
        pool.total_revenue += amount
        pool.save(update_fields=['total_revenue'])
        return pool


class ReadingEvent(models.Model):
    """Rekodi inayoonyesha kuwa msomaji mwenye usajili hai (siyo mnunuzi wa
    moja kwa moja) amesoma/kusikiliza kitabu fulani ndani ya mwezi husika.
    Hutumika kupima uwiano wa usomaji wa kila kitabu kwa lengo la kugawanya
    mapato ya kasha la usajili (SubscriptionRevenuePool) kwa waandishi."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name='reading_events')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='reading_events')
    year = models.PositiveIntegerField()
    month = models.PositiveSmallIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book', 'year', 'month')
        verbose_name = 'Tukio la Usomaji'
        verbose_name_plural = 'Matukio ya Usomaji'

    def __str__(self):
        return f'{self.user.username} - {self.book.title} ({self.year}-{self.month:02d})'

    @classmethod
    def record(cls, user, book):
        """Andika tukio la usomaji mara moja tu kwa mtumiaji/kitabu/mwezi husika."""
        now = timezone.now()
        _, created = cls.objects.get_or_create(
            user=user, book=book, year=now.year, month=now.month)
        return created


class AuthorEarning(models.Model):
    """Kumbukumbu ya mapato aliyolipwa mwandishi - chanzo: mauzo ya moja kwa
    moja (purchase) au mgao wa kasha la usajili (subscription)."""
    SOURCE_CHOICES = (
        ('purchase', 'Mauzo ya Moja kwa Moja'),
        ('subscription', 'Mgao wa Usajili'),
    )
    author = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                                related_name='earnings')
    book = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='earnings')
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    year = models.PositiveIntegerField(null=True, blank=True)
    month = models.PositiveSmallIntegerField(null=True, blank=True)
    reads = models.PositiveIntegerField(
        null=True, blank=True,
        help_text='Idadi ya wasomaji wenye usajili waliosoma kitabu hiki mwezi huu')
    share_percent = models.DecimalField(max_digits=6, decimal_places=3, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Mapato ya Mwandishi'
        verbose_name_plural = 'Mapato ya Waandishi'

    def __str__(self):
        return f'{self.author.username} - {self.book.title}: TZS {self.amount}'
