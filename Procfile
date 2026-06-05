web: gunicorn book_platform.wsgi --bind 0.0.0.0:$PORT
release: python manage.py migrate --noinput
