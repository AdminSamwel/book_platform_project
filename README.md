# Book Platform

A full-stack book marketplace built with **Django REST Framework** (backend) and **Flutter** (mobile/desktop frontend).

## Features

- Browse and search books by category
- Purchase books using an in-app wallet
- Subscribe to plans for unlimited reading access
- Upload and publish books (authors)
- Read book content in-app
- Leave comments on books
- JWT-based authentication with auto token refresh

## Project Structure

```
book_platform_project/
├── book_app/              # Flutter frontend
│   └── lib/
│       ├── models/        # Book, User
│       ├── providers/     # Auth, Book, Wallet, Subscription
│       ├── screens/       # All app screens
│       ├── services/      # API service (HTTP client)
│       └── widgets/       # Reusable widgets
├── book_platform/         # Django project settings
├── books/                 # Books app (CRUD, categories, content)
├── comments/              # Comments app
├── payments/              # Purchases & library
├── subscriptions/         # Subscription plans
├── users/                 # Custom user model, profiles
├── wallet/                # Wallet & top-up
└── manage.py
```

## Backend Setup

**Requirements:** Python 3.10+, pip

```bash
cd book_platform_project
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

The API will be available at `http://localhost:8000/api/`.

## Frontend Setup

**Requirements:** Flutter SDK 3.x

```bash
cd book_app
flutter pub get
flutter run
```

Update the base URL in `lib/services/api_service.dart` to match your backend IP:

```dart
static const String baseUrl = 'http://<YOUR_IP>:8000/api/';
```

## Tech Stack

| Layer    | Technology                              |
|----------|-----------------------------------------|
| Backend  | Django 4, Django REST Framework, JWT    |
| Frontend | Flutter 3, Provider, flutter_secure_storage |
| Database | SQLite (dev) — swap for PostgreSQL in prod |
| Auth     | JWT (SimpleJWT) with auto refresh       |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/token/` | Login |
| POST | `/api/users/register/` | Register |
| GET/POST | `/api/users/profile/` | View/update profile |
| GET | `/api/books/` | List books |
| POST | `/api/books/create/` | Upload a book |
| GET | `/api/books/<id>/content/` | Read book content |
| POST | `/api/payments/purchase/<id>/` | Purchase a book |
| GET | `/api/payments/mylibrary/` | My purchased books |
| GET/POST | `/api/wallet/` | Wallet balance & top-up |
| GET | `/api/subscriptions/plans/` | List plans |
| POST | `/api/subscriptions/subscribe/<id>/` | Subscribe |
| GET/POST | `/api/comments/<book_id>/` | Comments |

## Notes

- Change `SECRET_KEY` in `book_platform/settings.py` before deploying
- Set `DEBUG = False` and configure `ALLOWED_HOSTS` for production
- Replace SQLite with PostgreSQL for production use
