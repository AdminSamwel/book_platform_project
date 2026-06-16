from django.contrib import admin
from .models import SavedBook, Wishlist

@admin.register(SavedBook)
class SavedBookAdmin(admin.ModelAdmin):
    list_display = ['user', 'book', 'saved_at']

@admin.register(Wishlist)
class WishlistAdmin(admin.ModelAdmin):
    list_display = ['user', 'book', 'added_at']
