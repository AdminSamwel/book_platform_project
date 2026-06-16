import logging
import random
from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.utils import timezone

from .models import OTPCode

logger = logging.getLogger(__name__)

OTP_LENGTH = 6
OTP_EXPIRY_MINUTES = 10


def generate_otp_for_user(user, purpose='register'):
    """Tengeneza OTP mpya kwa mtumiaji, ukibatilisha OTP za zamani
    za kusudi (purpose) hilo zisizotumika."""
    OTPCode.objects.filter(user=user, purpose=purpose, is_used=False).update(is_used=True)

    code = ''.join(random.choices('0123456789', k=OTP_LENGTH))
    otp = OTPCode.objects.create(
        user=user,
        code=code,
        purpose=purpose,
        expires_at=timezone.now() + timedelta(minutes=OTP_EXPIRY_MINUTES),
    )
    return otp


def send_otp(user, otp):
    """Tuma OTP kwa barua pepe ya mtumiaji. Kama hakuna barua pepe
    (usajili wa namba ya simu pekee), andika kwenye logi ya server
    (nafasi tayari kwa kuunganisha SMS gateway baadaye)."""
    message = (
        f'Hujambo {user.username},\n\n'
        f'Nambari yako ya uthibitisho (OTP) ni: {otp.code}\n'
        f'Nambari hii itatumika kwa dakika {OTP_EXPIRY_MINUTES}.\n\n'
        f'Kama hukufanya ombi hili, puuza ujumbe huu.\n\n'
        f'-- Maktaba ya Vitabu'
    )

    if user.email:
        send_mail(
            subject='Nambari yako ya Uthibitisho (OTP)',
            message=message,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
    else:
        # TODO: unganisha na SMS gateway (mfano Africa's Talking/Twilio)
        # kwa usajili wa namba ya simu pekee.
        logger.info(
            'OTP kwa %s (simu: %s) ni: %s',
            user.username, user.phone_number, otp.code,
        )
