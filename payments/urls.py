from django.urls import path
from .views import (
    PurchaseBookView, MyLibraryView,
    CartView, CartAddView, CartCheckoutView,
    AuthorReadersStatsView,
)

urlpatterns = [
    path('purchase/<int:book_id>/', PurchaseBookView.as_view(), name='purchase-book'),
    path('mylibrary/', MyLibraryView.as_view(), name='my-library'),

    # ====== CART / BILL ======
    path('cart/', CartView.as_view(), name='cart'),
    path('cart/<int:book_id>/', CartAddView.as_view(), name='cart-add'),
    path('cart/checkout/', CartCheckoutView.as_view(), name='cart-checkout'),

    # ====== AUTHOR READERS STATS ======
    path('my-readers/', AuthorReadersStatsView.as_view(), name='author-readers'),
]
