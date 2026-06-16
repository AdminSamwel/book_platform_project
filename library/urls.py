from django.urls import path
from .views import (
    MyLibraryView, SaveBookView, CheckSavedView,
    WishlistView, WishlistToggleView, CheckWishlistView,
)

urlpatterns = [
    path('',                  MyLibraryView.as_view(),  name='my-library'),
    path('<int:book_id>/save/', SaveBookView.as_view(),  name='save-book'),
    path('<int:book_id>/saved/', CheckSavedView.as_view(), name='check-saved'),

    # ====== WISHLIST ======
    path('wishlist/',                WishlistView.as_view(),       name='wishlist'),
    path('wishlist/<int:book_id>/',  WishlistToggleView.as_view(), name='wishlist-toggle'),
    path('wishlist/<int:book_id>/check/', CheckWishlistView.as_view(), name='wishlist-check'),
]
