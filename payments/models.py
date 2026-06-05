from django.db import models
from django.conf import settings
from books.models import Book

class Purchase(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    book = models.ForeignKey(Book, on_delete=models.CASCADE)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_id = models.CharField(max_length=200, default="mock_txn")
    purchased_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'book')  # mtumiaji akinunua kitabu mara moja tu

    def __str__(self):
        return f"{self.user.username} - {self.book.title}"