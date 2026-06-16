from rest_framework import generics, permissions, status
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from .models import SubscriptionPlan, UserSubscription
from .serializers import PlanSerializer, UserSubscriptionSerializer
from wallet.models import Wallet, Transaction
from royalties.services import add_subscription_revenue

class PlanListView(generics.ListAPIView):
    queryset = SubscriptionPlan.objects.all()
    serializer_class = PlanSerializer
    permission_classes = [permissions.AllowAny]

class SubscribeView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = UserSubscriptionSerializer

    def post(self, request, plan_id):
        plan = generics.get_object_or_404(SubscriptionPlan, pk=plan_id)
        wallet = generics.get_object_or_404(Wallet, user=request.user)
        if wallet.balance < plan.price:
            return Response({"detail": "Mizania haitoshi kwa usajili huu."}, status=status.HTTP_400_BAD_REQUEST)
        wallet.balance -= plan.price
        wallet.save()
        Transaction.objects.create(wallet=wallet, amount=plan.price, transaction_type='debit', description=f"Usajili: {plan.name}")
        # Mapato ya usajili huingia kwenye kasha la mwezi - yatagawanywa kwa
        # waandishi mwishoni mwa mwezi kulingana na uwiano wa usomaji.
        if plan.price > 0:
            add_subscription_revenue(plan.price)
        # Deactivate previous active subscription
        UserSubscription.objects.filter(user=request.user, is_active=True).update(is_active=False)
        end_date = timezone.now() + timedelta(days=plan.duration_days)
        sub = UserSubscription.objects.create(user=request.user, plan=plan, end_date=end_date, is_active=True)
        serializer = self.get_serializer(sub)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class ActiveSubscriptionView(generics.RetrieveAPIView):
    serializer_class = UserSubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        sub = UserSubscription.objects.filter(user=self.request.user, is_active=True, end_date__gt=timezone.now()).first()
        return sub