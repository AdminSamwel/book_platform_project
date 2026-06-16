"""Mantiki ya kugawanya mapato kati ya waandishi na mfumo (admin/platform).

Vyanzo viwili vya mapato:
1. Mauzo ya moja kwa moja (Purchase) - mtumiaji ananunua kitabu maisha yote.
   Mapato yanagawanywa papo hapo: asilimia kwa mwandishi, asilimia kwa mfumo
   (PlatformSettings.purchase_commission_percent).
2. Usajili wa kila mwezi (SubscriptionPlan) - fedha za usajili huingia kwenye
   "kasha" (SubscriptionRevenuePool) la mwezi husika. Mwisho wa mwezi, admin
   anagawanya kasha hilo kwa waandishi kulingana na uwiano wa usomaji
   (ReadingEvent) wa vitabu vyao na watumiaji wenye usajili hai, baada ya
   kutoa asilimia ya mfumo (PlatformSettings.subscription_commission_percent).
"""
from decimal import Decimal, ROUND_HALF_UP
from django.utils import timezone
from django.db.models import Count
from users.models import User
from wallet.models import Wallet, Transaction
from .models import PlatformSettings, SubscriptionRevenuePool, ReadingEvent, AuthorEarning


def _q2(amount):
    return Decimal(amount).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def get_platform_user():
    """Mtumiaji wa kwanza mwenye is_superuser - 'mmiliki' wa mfumo anayepokea
    asilimia ya kibiashara (commission)."""
    return User.objects.filter(is_superuser=True).order_by('id').first()


def credit_wallet(user, amount, description):
    if user is None or amount <= 0:
        return
    wallet, _ = Wallet.objects.get_or_create(user=user)
    wallet.balance += amount
    wallet.save(update_fields=['balance'])
    Transaction.objects.create(
        wallet=wallet, amount=amount, transaction_type='credit', description=description)


def record_purchase_earning(book, amount):
    """Gawa mapato ya ununuzi wa moja kwa moja kati ya mwandishi na mfumo,
    kisha rekodi mapato ya mwandishi (AuthorEarning, source='purchase')."""
    amount = Decimal(amount)
    if amount <= 0:
        return Decimal('0'), Decimal('0')

    settings_obj = PlatformSettings.load()
    commission_pct = settings_obj.purchase_commission_percent / Decimal('100')
    platform_amount = _q2(amount * commission_pct)
    author_amount = _q2(amount - platform_amount)

    credit_wallet(book.author, author_amount, f"Mauzo: {book.title}")
    platform_user = get_platform_user()
    if platform_user and platform_user != book.author:
        credit_wallet(platform_user, platform_amount,
                       f"Tume ya mauzo ({settings_obj.purchase_commission_percent}%): {book.title}")

    AuthorEarning.objects.create(
        author=book.author, book=book, source='purchase', amount=author_amount)

    return author_amount, platform_amount


def add_subscription_revenue(amount):
    """Ongeza mapato ya usajili kwenye kasha la mwezi wa sasa."""
    amount = Decimal(amount)
    if amount <= 0:
        return None
    return SubscriptionRevenuePool.add_revenue(amount)


def record_reading_event(user, book):
    """Rekodi kuwa msomaji mwenye usajili amesoma kitabu hiki mwezi huu."""
    return ReadingEvent.record(user, book)


def _reads_breakdown(year, month):
    """Rudisha {book_id: reads_count} kwa mwezi husika."""
    qs = (ReadingEvent.objects
          .filter(year=year, month=month)
          .values('book_id')
          .annotate(reads=Count('id')))
    return {row['book_id']: row['reads'] for row in qs}


def preview_subscription_distribution(year, month):
    """Onyesha jinsi kasha la mwezi husika litakavyogawanywa, bila kuhifadhi
    chochote (kwa ajili ya admin kuona kabla ya kugawa)."""
    settings_obj = PlatformSettings.load()
    pool = SubscriptionRevenuePool.objects.filter(year=year, month=month).first()
    total_revenue = pool.total_revenue if pool else Decimal('0')

    commission_pct = settings_obj.subscription_commission_percent / Decimal('100')
    platform_amount = _q2(total_revenue * commission_pct)
    author_pool = total_revenue - platform_amount

    reads_by_book = _reads_breakdown(year, month)
    total_reads = sum(reads_by_book.values())

    breakdown = []
    if total_reads > 0:
        from books.models import Book
        books = Book.objects.filter(id__in=reads_by_book.keys()).select_related('author')
        for b in books:
            reads = reads_by_book[b.id]
            share = Decimal(reads) / Decimal(total_reads)
            payout = _q2(author_pool * share)
            breakdown.append({
                'book_id': b.id,
                'title': b.title,
                'author': b.author.username,
                'reads': reads,
                'share_percent': float(_q2(share * 100)),
                'payout': str(payout),
            })
        breakdown.sort(key=lambda x: x['reads'], reverse=True)

    return {
        'year': year,
        'month': month,
        'total_revenue': str(total_revenue),
        'platform_commission_percent': float(settings_obj.subscription_commission_percent),
        'platform_amount': str(platform_amount),
        'author_pool': str(author_pool),
        'total_reads': total_reads,
        'distributed': pool.distributed if pool else False,
        'breakdown': breakdown,
    }


def distribute_subscription_pool(year, month):
    """Gawa kasha la mwezi husika kwa waandishi kulingana na uwiano wa
    usomaji, kisha lipa tume ya mfumo. Inaweza kuendeshwa mara moja tu kwa
    kila mwezi (pool.distributed)."""
    pool = SubscriptionRevenuePool.objects.filter(year=year, month=month).first()
    if pool is None:
        raise ValueError('Hakuna mapato ya usajili kwa mwezi huu.')
    if pool.distributed:
        raise ValueError('Mapato ya mwezi huu tayari yamegawanywa.')

    preview = preview_subscription_distribution(year, month)
    platform_amount = Decimal(preview['platform_amount'])
    author_pool = Decimal(preview['author_pool'])
    total_revenue = Decimal(preview['total_revenue'])

    if total_revenue <= 0:
        pool.distributed = True
        pool.distributed_at = timezone.now()
        pool.save(update_fields=['distributed', 'distributed_at'])
        return preview

    from books.models import Book

    if preview['total_reads'] == 0:
        # Hakuna usomaji wowote uliorekodiwa - mfumo unapokea kasha lote.
        platform_amount = total_revenue
        author_pool = Decimal('0')

    platform_user = get_platform_user()
    credit_wallet(platform_user, platform_amount,
                   f"Tume ya usajili ({preview['platform_commission_percent']}%) - "
                   f"{year}-{month:02d}")

    for row in preview['breakdown']:
        book = Book.objects.select_related('author').get(id=row['book_id'])
        payout = Decimal(row['payout'])
        credit_wallet(book.author, payout,
                       f"Mgao wa usajili {year}-{month:02d}: {book.title} "
                       f"({row['share_percent']}% ya usomaji)")
        AuthorEarning.objects.create(
            author=book.author, book=book, source='subscription', amount=payout,
            year=year, month=month, reads=row['reads'],
            share_percent=row['share_percent'])

    pool.distributed = True
    pool.distributed_at = timezone.now()
    pool.save(update_fields=['distributed', 'distributed_at'])

    return preview
