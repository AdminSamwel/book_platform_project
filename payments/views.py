from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone
from datetime import timedelta
from books.models import Book
from wallet.models import Wallet, Transaction
from royalties.services import record_purchase_earning
from .models import Purchase, CartItem
from .serializers import PurchaseSerializer, CartItemSerializer


def _check_and_auto_upgrade(user):
    """Kama mtumiaji amenunua vitabu 5+, mpa Pro plan bila malipo (mara moja)."""
    from subscriptions.models import SubscriptionPlan, UserSubscription

    total = Purchase.objects.filter(user=user, book__is_free=False).count()
    if total < 5:
        return None

    active = UserSubscription.objects.filter(
        user=user, is_active=True, end_date__gt=timezone.now()
    ).select_related('plan').first()
    if active and active.plan and active.plan.level >= 2:
        return None  # Tayari ana Pro au zaidi

    pro_plan = SubscriptionPlan.objects.filter(level=2).first()
    if not pro_plan:
        return None

    UserSubscription.objects.filter(user=user, is_active=True).update(is_active=False)
    end_date = timezone.now() + timedelta(days=30)
    UserSubscription.objects.create(
        user=user, plan=pro_plan, end_date=end_date, is_active=True)
    return pro_plan.name

class PurchaseBookView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = PurchaseSerializer

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id, is_published=True)
        user = request.user

        if Purchase.objects.filter(user=user, book=book).exists():
            return Response({"detail": "Tayari umeshakinunua kitabu hiki."}, status=status.HTTP_400_BAD_REQUEST)
        if book.is_free:
            amount = 0.00
        else:
            amount = book.price
        if amount > 0:
            wallet = get_object_or_404(Wallet, user=user)
            if wallet.balance < amount:
                return Response({"detail": "Mizania haitoshi."}, status=status.HTTP_400_BAD_REQUEST)
            wallet.balance -= amount
            wallet.save()
            Transaction.objects.create(wallet=wallet, amount=amount, transaction_type='debit', description=f"Ununuzi: {book.title}")
            # Gawa mapato kati ya mwandishi na mfumo (commission)
            record_purchase_earning(book, amount)

        Purchase.objects.create(user=user, book=book, amount=amount, payment_id="mock_txn_123")
        CartItem.objects.filter(user=user, book=book).delete()
        upgraded_plan = _check_and_auto_upgrade(user)
        detail = "Umefanikiwa kununua kitabu."
        if upgraded_plan:
            detail += f" Hongera! Umepandishwa kiotomatiki kwenye mpango wa {upgraded_plan}."
        return Response({"detail": detail, "auto_upgraded": bool(upgraded_plan)},
                        status=status.HTTP_201_CREATED)

class MyLibraryView(generics.ListAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Purchase.objects.filter(user=self.request.user)


# ====================================================================
# CART (Kikapu cha Ununuzi) na BILL (Bili ya Vitabu Vingi)
# ====================================================================

class CartView(APIView):
    """Pata vitu vyote kwenye kikapu, pamoja na jumla ya bei (bill)"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        items = CartItem.objects.filter(user=request.user).select_related('book')
        serializer = CartItemSerializer(items, many=True, context={'request': request})
        total = sum(
            (0 if it.book.is_free else it.book.price) for it in items
        )
        return Response({
            'items': serializer.data,
            'count': items.count(),
            'total': str(total),
        })


class CartAddView(APIView):
    """Ongeza au toa kitabu kwenye kikapu"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id, is_published=True)
        user = request.user

        if Purchase.objects.filter(user=user, book=book).exists():
            return Response({"detail": "Tayari umeshakinunua kitabu hiki."},
                            status=status.HTTP_400_BAD_REQUEST)

        _, created = CartItem.objects.get_or_create(user=user, book=book)
        if created:
            return Response({"detail": "Kitabu kimeongezwa kwenye kikapu.",
                             "in_cart": True}, status=status.HTTP_201_CREATED)
        return Response({"detail": "Kitabu kipo tayari kwenye kikapu chako.",
                         "in_cart": True}, status=status.HTTP_200_OK)

    def delete(self, request, book_id):
        deleted, _ = CartItem.objects.filter(user=request.user, book_id=book_id).delete()
        if deleted:
            return Response({"detail": "Kitabu kimetolewa kwenye kikapu.",
                             "in_cart": False})
        return Response({"detail": "Kitabu hakikuwepo kwenye kikapu chako."},
                        status=status.HTTP_404_NOT_FOUND)


class CartCheckoutView(APIView):
    """
    Lipia vitabu vilivyo kwenye kikapu.
    Mwili wa ombi (body) unaweza kuwa na 'book_ids': [list ya id za vitabu
    vinavyotakiwa kulipiwa sasa]. Kama haijatolewa, vitabu VYOTE kwenye
    kikapu vitalipiwa (bill ya jumla).
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        book_ids = request.data.get('book_ids')

        qs = CartItem.objects.filter(user=user).select_related('book')
        if book_ids is not None:
            qs = qs.filter(book_id__in=book_ids)

        items = list(qs)
        if not items:
            return Response({"detail": "Hakuna vitabu vilivyochaguliwa kwenye kikapu."},
                            status=status.HTTP_400_BAD_REQUEST)

        # Ondoa vitabu ambavyo tayari vimenunuliwa (kama vipo)
        already_purchased_ids = set(
            Purchase.objects.filter(user=user, book_id__in=[it.book_id for it in items])
            .values_list('book_id', flat=True)
        )
        items = [it for it in items if it.book_id not in already_purchased_ids]
        if not items:
            return Response({"detail": "Vitabu vyote vilivyochaguliwa tayari vimenunuliwa."},
                            status=status.HTTP_400_BAD_REQUEST)

        total = sum((0 if it.book.is_free else it.book.price) for it in items)

        if total > 0:
            wallet = get_object_or_404(Wallet, user=user)
            if wallet.balance < total:
                return Response({
                    "detail": "Mizania haitoshi kulipia vitabu hivi.",
                    "total": str(total),
                    "balance": str(wallet.balance),
                }, status=status.HTTP_400_BAD_REQUEST)
            wallet.balance -= total
            wallet.save()
            Transaction.objects.create(
                wallet=wallet, amount=total, transaction_type='debit',
                description=f"Ununuzi wa vitabu {len(items)}",
            )

        purchased_titles = []
        for it in items:
            book = it.book
            amount = 0 if book.is_free else book.price
            if amount > 0:
                record_purchase_earning(book, amount)
            Purchase.objects.create(user=user, book=book, amount=amount, payment_id="mock_txn_cart")
            purchased_titles.append(book.title)

        CartItem.objects.filter(user=user, book_id__in=[it.book_id for it in items]).delete()
        upgraded_plan = _check_and_auto_upgrade(user)

        resp = {
            "detail": "Malipo yamefanikiwa.",
            "purchased": purchased_titles,
            "total_paid": str(total),
            "auto_upgraded": bool(upgraded_plan),
        }
        if upgraded_plan:
            resp["upgrade_message"] = (
                f"Hongera! Umenunua vitabu zaidi ya 5 — umepandishwa kiotomatiki "
                f"kwenye mpango wa {upgraded_plan} kwa siku 30 bila malipo."
            )
        return Response(resp, status=status.HTTP_201_CREATED)


# ====================================================================
# WASOMAJI WA MWANDISHI (Author Readers Stats)
# ====================================================================

class AuthorReadersStatsView(APIView):
    """
    Idadi ya wasomaji (waliokinunua au wenye usajili hai) kwa kila kitabu
    cha mwandishi, pamoja na jumla ya wasomaji wa kipekee (unique) wa
    vitabu vyote vya mwandishi.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from subscriptions.models import UserSubscription

        books = Book.objects.filter(author=request.user)
        sub_ids = set(
            UserSubscription.objects.filter(
                is_active=True, end_date__gte=timezone.now()
            ).values_list('user_id', flat=True)
        )

        all_readers = set()
        book_data = []
        for b in books:
            buyer_ids = set(Purchase.objects.filter(book=b).values_list('user_id', flat=True))
            reader_ids = buyer_ids | sub_ids
            all_readers |= reader_ids
            book_data.append({
                'book_id': b.id,
                'title': b.title,
                'cover_image': request.build_absolute_uri(b.cover_image.url) if b.cover_image else None,
                'buyers': len(buyer_ids),
                'readers': len(reader_ids),
            })

        book_data.sort(key=lambda x: x['readers'], reverse=True)

        return Response({
            'total_readers': len(all_readers),
            'books': book_data,
        })
