from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from .models import (
    SubscriptionPlan, UserSubscription,
    SystemSettings, FreeBookSelection, SubscriptionBookAccess,
)
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
            return Response(
                {"detail": "Mizania haitoshi kwa usajili huu."},
                status=status.HTTP_400_BAD_REQUEST)
        wallet.balance -= plan.price
        wallet.save()
        Transaction.objects.create(
            wallet=wallet, amount=plan.price,
            transaction_type='debit', description=f"Usajili: {plan.name}")
        if plan.price > 0:
            add_subscription_revenue(plan.price)
        # Deactivate previous subscriptions
        UserSubscription.objects.filter(user=request.user, is_active=True).update(is_active=False)
        end_date = timezone.now() + timedelta(days=plan.duration_days)
        sub = UserSubscription.objects.create(
            user=request.user, plan=plan, end_date=end_date, is_active=True)
        serializer = self.get_serializer(sub)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class ActiveSubscriptionView(generics.RetrieveAPIView):
    serializer_class = UserSubscriptionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return UserSubscription.objects.filter(
            user=self.request.user, is_active=True,
            end_date__gt=timezone.now()).first()


class SystemSettingsView(APIView):
    """GET: Pata mipangilio (hadharani). PATCH: Badilisha (msimamizi tu)."""

    def get_permissions(self):
        if self.request.method == 'GET':
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    def get(self, request):
        s = SystemSettings.get()
        return Response({
            'basic_book_limit': s.basic_book_limit,
            'pro_audio_limit': s.pro_audio_limit,
        })

    def patch(self, request):
        s = SystemSettings.get()
        errors = {}
        if 'basic_book_limit' in request.data:
            try:
                val = int(request.data['basic_book_limit'])
                if val < 1:
                    errors['basic_book_limit'] = 'Lazima iwe angalau 1.'
                else:
                    s.basic_book_limit = val
            except (ValueError, TypeError):
                errors['basic_book_limit'] = 'Nambari sahihi inahitajika.'
        if 'pro_audio_limit' in request.data:
            try:
                val = int(request.data['pro_audio_limit'])
                if val < 1:
                    errors['pro_audio_limit'] = 'Lazima iwe angalau 1.'
                else:
                    s.pro_audio_limit = val
            except (ValueError, TypeError):
                errors['pro_audio_limit'] = 'Nambari sahihi inahitajika.'
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)
        s.save()
        return Response({
            'basic_book_limit': s.basic_book_limit,
            'pro_audio_limit': s.pro_audio_limit,
        })


class FreeBookSelectionView(APIView):
    """GET: Pata kitabu alichochagua msomaji wa bure. POST: Chagua kitabu (mara moja tu)."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            sel = FreeBookSelection.objects.select_related('book').get(user=request.user)
            cover = None
            if sel.book.cover_image:
                cover = request.build_absolute_uri(sel.book.cover_image.url)
            return Response({
                'selected': True,
                'book_id': sel.book_id,
                'book_title': sel.book.title,
                'book_cover': cover,
                'selected_at': sel.selected_at,
            })
        except FreeBookSelection.DoesNotExist:
            return Response({'selected': False})

    def post(self, request):
        from books.models import Book
        book_id = request.data.get('book_id')
        if not book_id:
            return Response({"detail": "book_id inahitajika."}, status=400)

        if FreeBookSelection.objects.filter(user=request.user).exists():
            return Response(
                {"detail": "Tayari umechagua kitabu chako cha bure. Huwezi kubadilisha."},
                status=400)

        book = generics.get_object_or_404(Book, pk=book_id, is_published=True)
        if book.is_free:
            return Response(
                {"detail": "Chagua kitabu cha kulipa, si cha bure."},
                status=400)
        if getattr(book, 'has_audio', False) and not book.raw_file:
            return Response(
                {"detail": "Vitabu vya sauti vinahitaji mpango wa Pro au zaidi."},
                status=400)

        FreeBookSelection.objects.create(user=request.user, book=book)
        return Response({
            'selected': True,
            'book_id': book.pk,
            'book_title': book.title,
        }, status=201)


class SubscriptionUsageView(APIView):
    """Pata idadi ya vitabu vilivyotumiwa na mtumiaji katika usajili wake wa sasa."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        sub = UserSubscription.objects.filter(
            user=request.user, is_active=True, end_date__gt=timezone.now()
        ).select_related('plan').first()
        if not sub or not sub.plan:
            return Response({'has_subscription': False})

        s = SystemSettings.get()
        plan_level = sub.plan.level
        basic_limit = s.basic_book_limit

        total_used = SubscriptionBookAccess.objects.filter(
            user=request.user, subscription=sub
        ).values('book').distinct().count()
        audio_used = SubscriptionBookAccess.objects.filter(
            user=request.user, subscription=sub, is_audio=True
        ).values('book').distinct().count()

        base = {
            'has_subscription': True,
            'plan_level': plan_level,
            'plan_name': sub.plan.name,
            'end_date': sub.end_date,
            'total_used': total_used,
            'audio_used': audio_used,
        }

        if plan_level == 0:
            try:
                sel = FreeBookSelection.objects.get(user=request.user)
                base.update({
                    'total_limit': 1,
                    'audio_limit': 0,
                    'has_free_selection': True,
                    'free_book_id': sel.book_id,
                    'free_book_title': sel.book.title,
                })
            except FreeBookSelection.DoesNotExist:
                base.update({
                    'total_limit': 1,
                    'audio_limit': 0,
                    'has_free_selection': False,
                    'free_book_id': None,
                    'free_book_title': None,
                })
        elif plan_level == 1:
            base.update({'total_limit': basic_limit, 'audio_limit': 0})
        elif plan_level == 2:
            base.update({
                'total_limit': basic_limit * 2,
                'audio_limit': s.pro_audio_limit,
            })
        else:
            base.update({'total_limit': -1, 'audio_limit': -1})

        return Response(base)
