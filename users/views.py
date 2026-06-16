from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import (
    RegisterSerializer, UserSerializer, BanAwareTokenObtainPairSerializer,
    FavoriteCategoriesUpdateSerializer, ChangePasswordSerializer,
    VerifyOTPSerializer, ResendOTPSerializer, GoogleAuthSerializer,
)
from .models import User


class BanAwareTokenObtainPairView(TokenObtainPairView):
    serializer_class = BanAwareTokenObtainPairSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = [permissions.AllowAny]
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {
                'detail': 'Usajili umefanikiwa. Tumetuma nambari ya OTP ili '
                          'kuthibitisha akaunti yako.',
                'user_id': user.id,
                'identifier': user.username,
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyOTPView(generics.GenericAPIView):
    """Thibitisha akaunti mpya kwa OTP, kisha rudisha JWT tokens (auto-login)."""
    serializer_class = VerifyOTPSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data,
        })


class ResendOTPView(generics.GenericAPIView):
    """Tuma tena nambari ya OTP kwa akaunti isiyothibitishwa bado."""
    serializer_class = ResendOTPSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({'detail': 'Nambari mpya ya OTP imetumwa.'})


class GoogleAuthView(generics.GenericAPIView):
    """Ingia/Jisajili kwa akaunti ya Google (ID token), kisha rudisha JWT tokens."""
    serializer_class = GoogleAuthSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data,
        })


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    def get_object(self):
        return self.request.user


class FavoriteCategoriesView(generics.RetrieveUpdateAPIView):
    """Msomaji anaweza kuona/kuongeza/kubadilisha makundi ya vitabu anayopenda
    kutoka kwenye dashibodi yake (hakuna ukomo wa idadi)."""
    serializer_class = FavoriteCategoriesUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class ChangePasswordView(generics.GenericAPIView):
    """Inaruhusu mtumiaji aliyeingia kubadilisha nenosiri lake mwenyewe."""
    serializer_class = ChangePasswordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({'detail': 'Nenosiri limebadilishwa kwa mafanikio.'})
