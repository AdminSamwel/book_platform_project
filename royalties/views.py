from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from decimal import Decimal

from adminpanel.views import IsSuperAdmin
from .models import PlatformSettings, AuthorEarning, SubscriptionRevenuePool
from .serializers import (PlatformSettingsSerializer, AuthorEarningSerializer,
                           SubscriptionRevenuePoolSerializer)
from . import services


class PlatformSettingsView(generics.RetrieveUpdateAPIView):
    serializer_class = PlatformSettingsSerializer
    permission_classes = [IsSuperAdmin]

    def get_object(self):
        return PlatformSettings.load()


class RevenuePoolView(APIView):
    """Onyesha mapato ya kasha la usajili kwa mwezi husika (default: mwezi
    wa sasa) na mgawanyo unaopendekezwa kwa waandishi (preview)."""
    permission_classes = [IsSuperAdmin]

    def get(self, request):
        now = timezone.now()
        year = int(request.query_params.get('year', now.year))
        month = int(request.query_params.get('month', now.month))
        return Response(services.preview_subscription_distribution(year, month))


class DistributeRevenueView(APIView):
    """Gawa kasha la mwezi husika kwa waandishi kulingana na uwiano wa
    usomaji, kisha lipa tume ya mfumo. Inaweza kufanyika mara moja tu kwa
    kila mwezi."""
    permission_classes = [IsSuperAdmin]

    def post(self, request):
        now = timezone.now()
        year = int(request.data.get('year', now.year))
        month = int(request.data.get('month', now.month))
        try:
            result = services.distribute_subscription_pool(year, month)
        except ValueError as e:
            return Response({'detail': str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(result)


class RevenuePoolHistoryView(generics.ListAPIView):
    """Historia ya makasha ya mapato ya usajili ya miezi yote."""
    queryset = SubscriptionRevenuePool.objects.all()
    serializer_class = SubscriptionRevenuePoolSerializer
    permission_classes = [IsSuperAdmin]


class MyEarningsView(APIView):
    """Mwandishi anaona mchanganuo wa mapato yake - mauzo ya moja kwa moja na
    mgao wa usajili kwa kila kitabu/mwezi, pamoja na jumla."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        earnings = AuthorEarning.objects.filter(author=request.user).select_related('book')
        total_purchase = sum((e.amount for e in earnings if e.source == 'purchase'), Decimal('0'))
        total_subscription = sum((e.amount for e in earnings if e.source == 'subscription'), Decimal('0'))

        return Response({
            'total_purchase': str(total_purchase),
            'total_subscription': str(total_subscription),
            'total': str(total_purchase + total_subscription),
            'entries': AuthorEarningSerializer(earnings[:100], many=True).data,
        })
