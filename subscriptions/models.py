from django.db import models
from django.conf import settings

class SubscriptionPlan(models.Model):
    name = models.CharField(max_length=50)  # Basic, Pro, Premium
    price = models.DecimalField(max_digits=8, decimal_places=2)
    duration_days = models.IntegerField()
    max_books = models.IntegerField(default=-1)  # -1 = unlimited

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