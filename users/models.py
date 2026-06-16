from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils import timezone

class User(AbstractUser):
    ROLE_CHOICES = (
        ('reader', 'Msomaji'),
        ('author', 'Mwandishi'),
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='reader')
    bio = models.TextField(blank=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True)
    date_of_birth = models.DateField(
        null=True, blank=True, verbose_name='Tarehe ya Kuzaliwa',
        help_text='Inatumika kuzuia vitabu vyenye kikomo cha umri')

    # ====== USAJILI KWA EMAIL/SIMU + OTP ======
    email = models.EmailField(
        blank=True, null=True, unique=True, verbose_name='Barua Pepe')
    phone_number = models.CharField(
        max_length=20, blank=True, null=True, unique=True,
        verbose_name='Namba ya Simu')
    referred_by_book = models.ForeignKey(
        'books.Book', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='referred_signups',
        verbose_name='Alijiunga kupitia Kitabu',
        help_text='Kitabu kilichoshirikiwa (share) ambacho kilimleta mtumiaji huyu')

    # ====== USIMAMIZI / MODERATION ======
    is_banned     = models.BooleanField(default=False, verbose_name='Amefungiwa')
    ban_reason    = models.CharField(max_length=255, blank=True, default='', verbose_name='Sababu ya Kufungiwa')
    banned_at     = models.DateTimeField(null=True, blank=True, verbose_name='Tarehe ya Kufungiwa')
    warning_count = models.PositiveIntegerField(default=0, verbose_name='Idadi ya Maonyo')

    # ====== MAPENDEKEZO YA MSOMAJI / READER PREFERENCES ======
    favorite_categories = models.ManyToManyField(
        'books.Category', blank=True, related_name='followers',
        verbose_name='Makundi Anayopenda Msomaji')

    @property
    def age(self):
        """Umri wa mtumiaji kwa miaka, au None kama tarehe ya kuzaliwa haijawekwa."""
        if not self.date_of_birth:
            return None
        today = timezone.localdate()
        years = today.year - self.date_of_birth.year
        if (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day):
            years -= 1
        return years

    def __str__(self):
        return self.username


class OTPCode(models.Model):
    """Nambari za uthibitisho (OTP) zinazotumwa kwa email/simu wakati wa usajili."""
    PURPOSE_CHOICES = (
        ('register', 'Usajili'),
    )

    user       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='otp_codes')
    code       = models.CharField(max_length=6)
    purpose    = models.CharField(max_length=10, choices=PURPOSE_CHOICES, default='register')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used    = models.BooleanField(default=False)

    def is_valid(self):
        return not self.is_used and timezone.now() < self.expires_at

    def __str__(self):
        return f'{self.user.username} - {self.code} ({self.purpose})'