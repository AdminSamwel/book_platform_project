from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from books.models import Book
from wallet.models import Wallet, Transaction
from .models import Purchase
from .serializers import PurchaseSerializer

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
            # Lipia mwandishi (author)
            author_wallet, _ = Wallet.objects.get_or_create(user=book.author)
            author_wallet.balance += amount
            author_wallet.save()
            Transaction.objects.create(wallet=author_wallet, amount=amount, transaction_type='credit', description=f"Mauzo: {book.title}")

        Purchase.objects.create(user=user, book=book, amount=amount, payment_id="mock_txn_123")
        return Response({"detail": "Umefanikiwa kununua kitabu."}, status=status.HTTP_201_CREATED)

class MyLibraryView(generics.ListAPIView):
    serializer_class = PurchaseSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Purchase.objects.filter(user=self.request.user)