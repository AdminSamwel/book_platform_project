from django.utils import timezone
from django.db.models import Sum, Q
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response

from users.models import User
from books.models import Book
from payments.models import Purchase
from wallet.models import Wallet
from subscriptions.models import SubscriptionPlan, UserSubscription
from .serializers import AdminUserSerializer, AdminBookSerializer, AdminPlanSerializer


class IsSuperAdmin(permissions.BasePermission):
    """Inaruhusu tu watumiaji wenye is_staff/is_superuser (admin wa Django)."""

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated
                     and (request.user.is_staff or request.user.is_superuser))


class AdminStatsView(APIView):
    permission_classes = [IsSuperAdmin]

    def get(self, request):
        total_revenue = Purchase.objects.aggregate(total=Sum('amount'))['total'] or 0
        wallet_balance = Wallet.objects.aggregate(total=Sum('balance'))['total'] or 0

        return Response({
            'total_users': User.objects.count(),
            'total_authors': User.objects.filter(role='author').count(),
            'total_readers': User.objects.filter(role='reader').count(),
            'banned_users': User.objects.filter(is_banned=True).count(),
            'total_books': Book.objects.count(),
            'published_books': Book.objects.filter(is_published=True).count(),
            'pending_books': Book.objects.filter(is_published=False).count(),
            'total_purchases': Purchase.objects.count(),
            'total_revenue': total_revenue,
            'active_subscriptions': UserSubscription.objects.filter(
                is_active=True, end_date__gte=timezone.now()).count(),
            'total_wallet_balance': wallet_balance,
            'total_plans': SubscriptionPlan.objects.count(),
        })


class AdminUserListView(generics.ListAPIView):
    serializer_class = AdminUserSerializer
    permission_classes = [IsSuperAdmin]

    def get_queryset(self):
        qs = User.objects.all().order_by('-date_joined')
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(Q(username__icontains=search) | Q(email__icontains=search))
        role = self.request.query_params.get('role')
        if role:
            qs = qs.filter(role=role)
        return qs


class AdminUserBanView(APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, user_id):
        try:
            target = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'Mtumiaji hayupo.'}, status=status.HTTP_404_NOT_FOUND)

        if target.is_superuser:
            return Response({'detail': 'Huwezi kumzuia super admin.'},
                             status=status.HTTP_400_BAD_REQUEST)

        target.is_banned = not target.is_banned
        target.ban_reason = request.data.get('reason', '') if target.is_banned else ''
        target.banned_at = timezone.now() if target.is_banned else None
        target.save(update_fields=['is_banned', 'ban_reason', 'banned_at'])
        return Response(AdminUserSerializer(target).data)


class AdminBookListView(generics.ListAPIView):
    serializer_class = AdminBookSerializer
    permission_classes = [IsSuperAdmin]

    def get_queryset(self):
        qs = Book.objects.all().order_by('-created_at')
        search = self.request.query_params.get('search')
        if search:
            qs = qs.filter(title__icontains=search)
        published = self.request.query_params.get('published')
        if published is not None:
            qs = qs.filter(is_published=(published == 'true'))
        return qs


class AdminBookToggleView(APIView):
    permission_classes = [IsSuperAdmin]

    def post(self, request, book_id):
        try:
            book = Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipo.'}, status=status.HTTP_404_NOT_FOUND)

        book.is_published = not book.is_published
        book.save(update_fields=['is_published'])
        return Response(AdminBookSerializer(book).data)


class AdminBookDeleteView(APIView):
    permission_classes = [IsSuperAdmin]

    def delete(self, request, book_id):
        try:
            book = Book.objects.get(id=book_id)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipo.'}, status=status.HTTP_404_NOT_FOUND)

        book.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AdminPlanListCreateView(generics.ListCreateAPIView):
    queryset = SubscriptionPlan.objects.all()
    serializer_class = AdminPlanSerializer
    permission_classes = [IsSuperAdmin]


class AdminPlanDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = SubscriptionPlan.objects.all()
    serializer_class = AdminPlanSerializer
    permission_classes = [IsSuperAdmin]
