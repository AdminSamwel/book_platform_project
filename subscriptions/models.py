from django.db import models
from django.conf import settings

class SubscriptionPlan(models.Model):
    LEVEL_CHOICES = [
        (0, 'Bure (Free)'),
        (1, 'Basic'),
        (2, 'Pro'),
        (3, 'Premium'),
    ]

    name = models.CharField(max_length=50)  # Free, Basic, Pro, Premium
    price = models.DecimalField(max_digits=8, decimal_places=2)
    duration_days = models.IntegerField()
    max_books = models.IntegerField(default=-1)  # -1 = unlimited
    level = models.PositiveSmallIntegerField(
        default=0, choices=LEVEL_CHOICES,
        help_text='Kiwango cha mpango: kadiri kinavyopanda ndivyo unavyopata vitabu zaidi')
    features = models.JSONField(
        default=list, blank=True,
        help_text='Orodha ya faida za mpango huu (zinazoonekana kwa mtumiaji)')

    class Meta:
        ordering = ['level']

    def __str__(self):
        return self.name

class UserSubscription(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True)
    start_date = models.DateTimeField(auto_now_add=True)
    end_date = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.user.username} - {self.plan.name}"