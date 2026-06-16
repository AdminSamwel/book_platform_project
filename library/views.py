from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions, status
from books.models import Book
from books.serializers import BookListSerializer
from .models import SavedBook, Wishlist


class MyLibraryView(APIView):
    """Pata vitabu vyote vilivyohifadhiwa (saved + purchased)"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from payments.models import Purchase

        # Vitabu vilivyonunuliwa
        purchased_ids = set(
            Purchase.objects.filter(user=request.user)
            .values_list('book_id', flat=True)
        )

        # Vitabu vilivyohifadhiwa
        saved_ids = set(
            SavedBook.objects.filter(user=request.user)
            .values_list('book_id', flat=True)
        )

        all_ids = purchased_ids | saved_ids
        books   = Book.objects.filter(pk__in=all_ids, is_published=True)
        serializer = BookListSerializer(books, many=True,
                                        context={'request': request})

        # Ongeza taarifa za hali (saved/purchased)
        data = []
        for b in serializer.data:
            entry = dict(b)
            entry['is_purchased'] = b['id'] in purchased_ids
            entry['is_saved']     = b['id'] in saved_ids
            data.append(entry)

        return Response(data)


class SaveBookView(APIView):
    """Ongeza au toa kitabu kwenye Maktaba Yangu"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id):
        """Ongeza kitabu kwenye maktaba"""
        try:
            book = Book.objects.get(pk=book_id, is_published=True)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipatikani.'},
                            status=status.HTTP_404_NOT_FOUND)

        _, created = SavedBook.objects.get_or_create(
            user=request.user, book=book)

        if created:
            return Response({'detail': 'Kitabu kimehifadhiwa kwenye maktaba yako.',
                             'saved': True}, status=status.HTTP_201_CREATED)
        return Response({'detail': 'Kitabu kipo tayari kwenye maktaba yako.',
                         'saved': True}, status=status.HTTP_200_OK)

    def delete(self, request, book_id):
        """Toa kitabu kwenye maktaba"""
        deleted, _ = SavedBook.objects.filter(
            user=request.user, book_id=book_id).delete()
        if deleted:
            return Response({'detail': 'Kitabu kimetolewa kwenye maktaba.',
                             'saved': False})
        return Response({'detail': 'Kitabu hakikuwepo kwenye maktaba yako.'},
                        status=status.HTTP_404_NOT_FOUND)


class CheckSavedView(APIView):
    """Angalia kama kitabu kimehifadhiwa"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        saved = SavedBook.objects.filter(
            user=request.user, book_id=book_id).exists()
        return Response({'saved': saved})


# ====================================================================
# WISHLIST (Orodha ya Matakwa) - vitabu vya kununua baadaye
# ====================================================================

class WishlistView(APIView):
    """Pata orodha ya vitabu vyote kwenye wishlist ya mtumiaji"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from payments.models import Purchase

        items = Wishlist.objects.filter(user=request.user).select_related('book')
        book_ids = [it.book_id for it in items]
        books = {b.id: b for b in Book.objects.filter(pk__in=book_ids)}
        purchased_ids = set(
            Purchase.objects.filter(user=request.user, book_id__in=book_ids)
            .values_list('book_id', flat=True)
        )

        ordered_books = [books[it.book_id] for it in items if it.book_id in books]
        serializer = BookListSerializer(ordered_books, many=True,
                                        context={'request': request})
        data = []
        for b in serializer.data:
            entry = dict(b)
            entry['is_purchased'] = b['id'] in purchased_ids
            data.append(entry)
        return Response(data)


class WishlistToggleView(APIView):
    """Ongeza au toa kitabu kwenye wishlist"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, book_id):
        try:
            book = Book.objects.get(pk=book_id, is_published=True)
        except Book.DoesNotExist:
            return Response({'detail': 'Kitabu hakipatikani.'},
                            status=status.HTTP_404_NOT_FOUND)

        _, created = Wishlist.objects.get_or_create(user=request.user, book=book)
        if created:
            return Response({'detail': 'Kitabu kimeongezwa kwenye Wishlist.',
                             'in_wishlist': True}, status=status.HTTP_201_CREATED)
        return Response({'detail': 'Kitabu kipo tayari kwenye Wishlist.',
                         'in_wishlist': True}, status=status.HTTP_200_OK)

    def delete(self, request, book_id):
        deleted, _ = Wishlist.objects.filter(
            user=request.user, book_id=book_id).delete()
        if deleted:
            return Response({'detail': 'Kitabu kimetolewa kwenye Wishlist.',
                             'in_wishlist': False})
        return Response({'detail': 'Kitabu hakikuwepo kwenye Wishlist yako.'},
                        status=status.HTTP_404_NOT_FOUND)


class CheckWishlistView(APIView):
    """Angalia kama kitabu kipo kwenye Wishlist"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, book_id):
        in_wishlist = Wishlist.objects.filter(
            user=request.user, book_id=book_id).exists()
        return Response({'in_wishlist': in_wishlist})
