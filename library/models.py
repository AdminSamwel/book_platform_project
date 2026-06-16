from django.db import models
from django.conf import settings
from books.models import Book

class SavedBook(models.Model):
    """Vitabu vilivyohifadhiwa na msomaji kwenye Maktaba Yangu"""
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                    on_delete=models.CASCADE, related_name='saved_books')
    book       = models.ForeignKey(Book, on_delete=models.CASCADE,
                    related_name='saved_by')
    saved_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')  # Mtu mmoja hawezi kuhifadhi kitabu mara mbili
        ordering = ['-saved_at']

    def __str__(self):
        return f'{self.user.username} → {self.book.title}'


class Wishlist(models.Model):
    """Vitabu ambavyo msomaji anataka kuvinunua baadaye (orodha ya matakwa)"""
    user       = models.ForeignKey(settings.AUTH_USER_MODEL,
                    on_delete=models.CASCADE, related_name='wishlist_items')
    book       = models.ForeignKey(Book, on_delete=models.CASCADE,
                    related_name='wishlisted_by')
    added_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')
        ordering = ['-added_at']

    def __str__(self):
        return f'{self.user.username} ♡ {self.book.title}'
