from django.conf import settings
from django.shortcuts import get_object_or_404, render
from django.views import View

from .models import Book, BookShareClick


class BookShareLandingView(View):
    """Ukurasa wa kushare kitabu kwenye mitandao ya kijamii (Open Graph).

    Mtu anapobofya link ya kushare (whatsapp/facebook/...), anafikia ukurasa
    huu wenye taarifa za kitabu + fomu fupi ya kujisajili, kabla ya kumpeleka
    kwenye app yetu."""

    def get(self, request, book_id):
        book = get_object_or_404(Book, pk=book_id, is_published=True)

        ref = request.GET.get('ref', '')
        src = request.GET.get('src', '')[:20]

        ref_user_id = None
        if ref.isdigit():
            ref_user_id = int(ref)

        BookShareClick.objects.create(
            book=book,
            ref_user_id=ref_user_id,
            platform=src if src in dict(BookShareClick.PLATFORM_CHOICES) else '',
        )

        cover_url = ''
        if book.cover_image:
            cover_url = request.build_absolute_uri(book.cover_image.url)

        context = {
            'book': book,
            'cover_url': cover_url,
            'share_url': request.build_absolute_uri(),
            'ref': ref,
            'site_url': settings.SITE_URL,
            'api_register_url': f'{settings.SITE_URL}/api/users/register/',
            'api_verify_url': f'{settings.SITE_URL}/api/users/verify-otp/',
            'api_resend_url': f'{settings.SITE_URL}/api/users/resend-otp/',
            'api_google_auth_url': f'{settings.SITE_URL}/api/users/google-auth/',
            'google_client_id': settings.GOOGLE_OAUTH_CLIENT_ID,
            'deep_link': f'bookapp://book/{book.id}?ref={ref}',
        }
        return render(request, 'books/share_book.html', context)
