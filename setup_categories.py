import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'book_platform.settings')
django.setup()

from books.models import Category, Book

cats = [
    ('Sayansi & Teknolojia', 'sayansi-teknolojia'),
    ('Historia & Utamaduni', 'historia-utamaduni'),
    ('Biashara & Uchumi',    'biashara-uchumi'),
    ('Elimu & Masomo',       'elimu-masomo'),
    ('Riwaya & Hadithi',     'riwaya-hadithi'),
    ('Afya & Maisha',        'afya-maisha'),
    ('Dini & Imani',         'dini-imani'),
    ('Watoto',               'watoto'),
]

for name, slug in cats:
    cat, created = Category.objects.get_or_create(slug=slug, defaults={'name': name})
    print(f'  {"Imeundwa" if created else "Ipo tayari"}: {cat.name}')

book = Book.objects.first()
if book:
    book.category = Category.objects.get(slug='elimu-masomo')
    book.save()
    print(f'Kitabu "{book.title}" kimewekwa: Elimu & Masomo')
