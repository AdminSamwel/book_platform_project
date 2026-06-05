from django.db import models
from django.conf import settings
from cryptography.fernet import Fernet

class Category(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True)

    def __str__(self):
        return self.name

class Book(models.Model):
    title = models.CharField(max_length=255)
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='books'     # Hii inaipa jina la kurudi nyuma, inaepuka mgongano
    )
    description = models.TextField()
    cover_image = models.ImageField(upload_to='covers/', blank=True)
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    is_free = models.BooleanField(default=False)
    raw_file = models.FileField(upload_to='raw_books/')
    encrypted_file = models.FileField(upload_to='encrypted_books/', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    is_published = models.BooleanField(default=False)

    def encrypt_content(self):
        if not self.raw_file:
            return
        fernet = Fernet(settings.BOOK_ENCRYPTION_KEY)
        with self.raw_file.open('rb') as f:
            raw_data = f.read()
        encrypted = fernet.encrypt(raw_data)
        from django.core.files.base import ContentFile
        self.encrypted_file.save(
            f"{self.id}_encrypted.txt",
            ContentFile(encrypted),
            save=False
        )

    def decrypt_content(self):
        fernet = Fernet(settings.BOOK_ENCRYPTION_KEY)
        with self.encrypted_file.open('rb') as f:
            return fernet.decrypt(f.read())

    def __str__(self):
        return self.title