import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings')
app = Celery('core')

REDIS_URL = os.getenv('REDIS_URL', 'redis://redis:6379/0')
app.conf.broker_url = REDIS_URL
app.conf.result_backend = REDIS_URL
app.autodiscover_tasks()