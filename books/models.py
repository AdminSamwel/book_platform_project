from django.db import models
from django.conf import settings
from cryptography.fernet import Fernet

class Category(models.Model):
    name = models.CharField(max_length=100)
    slug = models.SlugField(unique=True)

    def __str__(self):
        return self.name

class Book(models.Model):
    title       = models.CharField(max_length=255)
    author      = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='books',
    )
    description    = models.TextField()
    cover_image    = models.ImageField(upload_to='covers/', blank=True)
    category       = models.ForeignKey(
        Category, on_delete=models.SET_NULL, null=True, blank=True)
    price          = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    is_free        = models.BooleanField(default=False)

    PLAN_LEVEL_CHOICES = [
        (0, 'Wote (pamoja na mpango wa Bure)'),
        (1, 'Basic na zaidi'),
        (2, 'Pro na zaidi'),
        (3, 'Premium pekee'),
    ]
    min_plan_level = models.PositiveSmallIntegerField(
        default=0, choices=PLAN_LEVEL_CHOICES,
        verbose_name='Kiwango cha chini cha mpango',
        help_text='Kiwango cha chini cha usajili kinachohitajika kusoma kitabu hiki')

    MIN_AGE_CHOICES = [
        (0, 'Hakuna kikomo (Wote)'),
        (12, 'Miaka 12+'),
        (16, 'Miaka 16+'),
        (18, 'Miaka 18+ (Watu Wazima)'),
    ]
    min_age = models.PositiveSmallIntegerField(
        default=0, choices=MIN_AGE_CHOICES,
        verbose_name='Kikomo cha Umri',
        help_text='Umri wa chini unaohitajika kusoma/kusikiliza kitabu hiki. 0 = hakuna kikomo.')

    # ── Taarifa za Kimaktaba (Library Metadata) ──────────────────────────────
    isbn           = models.CharField(max_length=20, blank=True, default='',
                        verbose_name='ISBN',
                        help_text='ISBN-10 au ISBN-13')
    book_authors   = models.CharField(max_length=500, blank=True, default='',
                        verbose_name='Waandishi',
                        help_text='Majina ya waandishi, tenganisha kwa koma')
    publisher      = models.CharField(max_length=255, blank=True, default='',
                        verbose_name='Mchapishaji')
    year_published = models.PositiveSmallIntegerField(null=True, blank=True,
                        verbose_name='Mwaka wa Kuchapishwa')
    edition        = models.CharField(max_length=50, blank=True, default='',
                        verbose_name='Toleo',
                        help_text='Mfano: Toleo la 1, 2nd Edition')
    page_count     = models.PositiveIntegerField(null=True, blank=True,
                        verbose_name='Idadi ya Kurasa')
    book_language  = models.CharField(max_length=50, blank=True, default='Kiswahili',
                        verbose_name='Lugha ya Kitabu')
    # ─────────────────────────────────────────────────────────────────────────

    # Faili la maandishi (PDF/TXT/EPUB)
    raw_file       = models.FileField(upload_to='raw_books/', blank=True)
    encrypted_file = models.FileField(upload_to='encrypted_books/', blank=True)

    # Faili la sauti (MP3/WAV/OGG)
    audio_file          = models.FileField(upload_to='audio_books/', blank=True, null=True)
    encrypted_audio     = models.FileField(upload_to='encrypted_audio/', blank=True, null=True)

    created_at  = models.DateTimeField(auto_now_add=True)
    is_published = models.BooleanField(default=False)

    @property
    def has_text(self):
        return bool(self.encrypted_file)

    @property
    def has_audio(self):
        return bool(self.audio_file or self.encrypted_audio)

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
            save=False,
        )

    def decrypt_content(self):
        fernet = Fernet(settings.BOOK_ENCRYPTION_KEY)
        with self.encrypted_file.open('rb') as f:
            return fernet.decrypt(f.read())

    def encrypt_audio(self):
        """Simba faili la sauti"""
        if not self.audio_file:
            return
        fernet = Fernet(settings.BOOK_ENCRYPTION_KEY)
        with self.audio_file.open('rb') as f:
            raw_data = f.read()
        encrypted = fernet.encrypt(raw_data)
        from django.core.files.base import ContentFile
        ext = self.audio_file.name.split('.')[-1].lower()
        self.encrypted_audio.save(
            f"{self.id}_audio_encrypted.bin",
            ContentFile(encrypted),
            save=False,
        )

    def decrypt_audio(self):
        """Fungua faili la sauti"""
        fernet = Fernet(settings.BOOK_ENCRYPTION_KEY)
        with self.encrypted_audio.open('rb') as f:
            return fernet.decrypt(f.read())

    def get_audio_content_type(self):
        if self.audio_file:
            name = self.audio_file.name.lower()
            if name.endswith('.mp3'):  return 'audio/mpeg'
            if name.endswith('.wav'):  return 'audio/wav'
            if name.endswith('.ogg'):  return 'audio/ogg'
            if name.endswith('.m4a'):  return 'audio/mp4'
        return 'audio/mpeg'

    def __str__(self):
        return self.title


class BookShareClick(models.Model):
    """Rekodi ya kubofya link ya kushare kitabu (kutoka mitandao ya kijamii),
    inatumika kuonyesha mwandishi takwimu za uwiano wa wateja."""
    PLATFORM_CHOICES = [
        ('whatsapp', 'WhatsApp'),
        ('facebook', 'Facebook'),
        ('twitter', 'Twitter/X'),
        ('telegram', 'Telegram'),
        ('copy', 'Nakili Link'),
        ('app', 'Fungua App'),
        ('other', 'Nyingine'),
    ]

    book       = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='shares')
    ref_user   = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='book_share_clicks', verbose_name='Aliyeshare')
    platform   = models.CharField(max_length=20, blank=True, default='',
                    choices=PLATFORM_CHOICES, verbose_name='Mtandao')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.book.title} - {self.platform or "?"} ({self.created_at:%Y-%m-%d})'


class Rating(models.Model):
    """Tathmini (nyota) na maoni ya msomaji kuhusu kitabu baada ya kukisoma."""
    book       = models.ForeignKey(Book, on_delete=models.CASCADE, related_name='ratings')
    user       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='book_ratings')
    score      = models.PositiveSmallIntegerField(verbose_name='Nyota (1-5)')
    comment    = models.TextField(blank=True, default='', verbose_name='Maoni')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('book', 'user')
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.username} -> {self.book.title}: {self.score}★'
