#!/bin/bash
# Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail

show_help() {
    echo """
The available commands and services are shown below:

ADMIN COMMANDS:
manage          : Manage {{ cookiecutter.project_name }} and its database
shell           : Start a Django Python shell
help            : Show this message

SERVICE COMMANDS:
gunicorn            : Start {{ cookiecutter.project_name }} django using a prod ready gunicorn server:
                         * Waits for the postgres database to be available first.
                         * Automatically migrates the database on startup.
                         * Binds to 0.0.0.0
celery-worker       : Start the celery worker queue which runs important async tasks
celery-beat         : Start the celery beat service used to schedule periodic jobs
"""
}

run_setup_commands_if_configured(){
  if [ "$MIGRATE_ON_STARTUP" = "true" ] ; then
    echo "python /{{ cookiecutter.project_slug }}/manage.py migrate"
    /{{cookiecutter.project_slug }}/manage.py migrate
  fi

  # collect staticfiles
  if [ "$COLLECT_STATICFILES_ON_STARTUP" = "true" ] ; then
    echo "python /{{cookiecutter.project_slug }}/manage.py collectstatic --noinput"
    /{{ cookiecutter.project_slug }}/manage.py collectstatic --noinput
  fi
}

start_celery_worker() {
    EXTRA_CELERY_ARGS=()

    if [[ -n "$GUNICORN_NUM_OF_WORKERS" ]]; then
        EXTRA_CELERY_ARGS+=(--concurrency "$GUNICORN_NUM_OF_WORKERS")
    fi
    exec celery -A {{ cookiecutter.project_module }} worker "${EXTRA_CELERY_ARGS[@]}" -l INFO "$@"
}

run_server() {
    run_setup_commands_if_configured

    if [[ "$1" = "wsgi" ]]; then
        STARTUP_ARGS=({{ cookiecutter.project_module }}.wsgi:application)
    elif [[ "$1" = "asgi" ]]; then
        STARTUP_ARGS=(-k uvicorn.workers.UvicornWorker {{ cookiecutter.project_module }}.asgi:application)
    else
        echo -e "\e[31mUnknown run_server argument $1 \e[0m" >&2
        exit 1
    fi


    # Gunicorn args explained in order:
    #
    # 1. See https://docs.gunicorn.org/en/stable/faq.html#blocking-os-fchmod for
    #    why we set worker-tmp-dir to /dev/shm by default.
    # 2. Log to stdout
    # 3. Log requests to stdout
    exec gunicorn --workers="$GUNICORN_NUM_OF_WORKERS" \
        --worker-tmp-dir "${TMPDIR:-/dev/shm}" \
        --log-file=- \
        --access-logfile=- \
        --capture-output \
        -b "0.0.0.0:8000" \
        --log-level="${LOG_LEVEL}" \
        "${STARTUP_ARGS[@]}" \
        "${@:2}"
}

# ======================================================
# COMMANDS
# ======================================================

if [[ -z "${1:-}" ]]; then
    echo "Must provide arguments to docker-entrypoint.sh"
    show_help
    exit 1
fi

# activate virtual environment
source /{{cookiecutter.project_slug}}/venv/bin/activate

case "$1" in
gunicorn)
    run_server asgi "${@:2}"
    ;;
gunicorn-wsgi)
    run_server wsgi "${@:2}"
    ;;
manage)
    exec python3 /{{ cookiecutter.project_slug }}/manage.py "${@:2}"
    ;;
shell)
    exec python3 /{{ cookiecutter.project_slug }}/manage.py shell
    ;;
celery-worker)
    start_celery_worker -Q celery -n default-worker@%h "${@:2}"
    ;;
celery-beat)
    exec celery -A {{ cookiecutter.project_module }} beat -l "${CELERY_BEAT_DEBUG_LEVEL}" -S django_celery_beat.schedulers:DatabaseScheduler "${@:2}"
    ;;
*)
    echo "Command given was $*"
    show_help
    exit 1
    ;;
esac