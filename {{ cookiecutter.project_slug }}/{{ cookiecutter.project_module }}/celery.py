from celery import Celery

app = Celery("{{ cookiecutter.project_module }}")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()
