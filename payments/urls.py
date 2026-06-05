from django.urls import path
from .views import PurchaseBookView, MyLibraryView

urlpatterns = [
    path('purchase/<int:book_id>/', PurchaseBookView.as_view(), name='purchase-book'),
    path('mylibrary/', MyLibraryView.as_view(), name='my-library'),
]