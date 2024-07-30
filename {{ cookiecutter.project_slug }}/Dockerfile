# use osgeo gdal ubuntu small 3.7 image.
# pre-installed with GDAL 3.7.0 and Python 3.10.6
FROM ghcr.io/osgeo/gdal:ubuntu-small-3.7.0

ARG UID
ENV UID=${UID:-9999}
ARG GID
ENV GID=${GID:-9999}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# We might be running as a user which already exists in this image. In that situation
# Everything is OK and we should just continue on.
RUN groupadd -g $GID {{cookiecutter.project_module}}_docker_group || exit 0
RUN useradd --shell /bin/bash -u $UID -g $GID -o -c "" -m {{cookiecutter.project_module}}_docker_user -l || exit 0
ENV DOCKER_USER={{cookiecutter.project_module}}_docker_user

# install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    lsb-release \
    libpq-dev \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    libwebp-dev \
    gosu \
    python3-dev \
    python3-venv \
    python3-pip --fix-missing \
    && apt-get autoclean \
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# install docker-compose wait
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.12.1/wait /wait
RUN chmod +x /wait

USER $UID:$GID

# install python requirements
COPY --chown=$UID:$GID ./requirements.txt /{{ cookiecutter.project_slug }}/requirements.txt
RUN python3 -m venv /{{ cookiecutter.project_slug }}/venv

ENV PIP_CACHE_DIR=/tmp/{{ cookiecutter.project_module }}_pip_cache
RUN --mount=type=cache,mode=777,target=$PIP_CACHE_DIR,uid=$UID,gid=$GID . /{{ cookiecutter.project_slug }}/venv/bin/activate && pip3 install  -r /{{ cookiecutter.project_slug }}/requirements.txt

# copy code
COPY --chown=$UID:$GID . /{{cookiecutter.project_slug }}/

# setup working dir
WORKDIR /{{cookiecutter.project_slug }}

# set python env
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Copy entrypoint script
COPY --chown=$UID:$GID docker-entrypoint.sh  /{{cookiecutter.project_slug }}/docker-entrypoint.sh
RUN chmod +x /{{cookiecutter.project_slug }}/docker-entrypoint.sh

ENTRYPOINT ["/{{cookiecutter.project_slug }}/docker-entrypoint.sh"]

ENV DJANGO_SETTINGS_MODULE='{{cookiecutter.project_module }}.settings.production'

CMD ["gunicorn-wsgi"]