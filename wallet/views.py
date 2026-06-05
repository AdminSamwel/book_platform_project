from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from decimal import Decimal
from .models import Wallet, Transaction
from .serializers import WalletSerializer

class WalletDetailView(generics.RetrieveAPIView):
    serializer_class = WalletSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        wallet, _ = Wallet.objects.get_or_create(user=self.request.user)
        return wallet


class WalletTopUpView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        if not amount:
            return Response({'detail': 'Thamani ya pesa inahitajika.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            amount = Decimal(str(amount))
            if amount <= 0:
                raise ValueError
        except (ValueError, Exception):
            return Response({'detail': 'Thamani ya pesa si sahihi.'}, status=status.HTTP_400_BAD_REQUEST)

        wallet, _ = Wallet.objects.get_or_create(user=request.user)
        wallet.balance += amount
        wallet.save()
        Transaction.objects.create(
            wallet=wallet,
            amount=amount,
            transaction_type='credit',
            description=f'Ameweka TZS {amount}',
        )
        return Response({'detail': 'Pesa imeongezwa.', 'balance': str(wallet.balance)}, status=status.HTTP_200_OK)