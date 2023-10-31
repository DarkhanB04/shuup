FROM node:12.21.0-buster-slim as base

# This image is NOT made for production use.
LABEL maintainer="Eero Ruohola <eero.ruohola@shuup.com>"

RUN apt-get update \
    && apt-get --assume-yes install \
        libffi-dev \
        libpangocairo-1.0-0 \
        python3 \
        python3-pip \
        vim \
    && apt-get install -y libxml2-dev libxslt-dev \
    && rm -rf /var/lib/apt/lists/ /var/cache/apt/

# These invalidate the cache every single time but
# there really isn't any other obvious way to do this.
COPY . /app
WORKDIR /app

# The dev compose file sets this to 1 to support development and editing the source code.
# The default value of 0 just installs the demo for running.
#ARG editable=0

#RUN if [ "$editable" -eq 1 ]; then pip3 install -r requirements-tests.txt && python3 setup.py build_resources; else pip3 install shuup; fi

RUN pip3 install -U pip  \
    && pip3 install -U setuptools  \
    && pip3 install shuup  \
    && pip3 install markupsafe==2.0.1 \
    && pip3 install django-prometheus

RUN python3 -m shuup_workbench migrate
RUN python3 -m shuup_workbench shuup_init

RUN echo '\
from django.contrib.auth import get_user_model\n\
from django.db import IntegrityError\n\
try:\n\
    get_user_model().objects.create_superuser("admin", "admin@admin.com", "admin")\n\
except IntegrityError:\n\
    pass\n'\
| python3 -m shuup_workbench shell

CMD ["python3", "-m", "shuup_workbench", "runserver", "0.0.0.0:8000"]

FROM jenkins/jenkins:2.414.3-jdk17
USER root
RUN apt-get update && apt-get install -y lsb-release
RUN curl -fsSLo /usr/share/keyrings/docker-archive-keyring.asc \
  https://download.docker.com/linux/debian/gpg
RUN echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/docker-archive-keyring.asc] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
RUN apt-get update && apt-get install -y docker-ce-cli
USER jenkins
RUN jenkins-plugin-cli --plugins "blueocean docker-workflow"