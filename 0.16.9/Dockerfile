FROM node:latest

MAINTAINER pastakhov@yandex.ru

ENV RB_HOME=/var/lib/restbase \
    RB_DATA=/data \
    RB_USER=restbase \
    RB_BRANCH=v0.16.9

# restbase setup
RUN set -x; \
    # Core
    mkdir -p $RB_HOME \
    && git clone \
        --branch $RB_BRANCH \
        --single-branch \
        --depth 1 \
        --quiet \
        https://github.com/wikimedia/restbase.git \
        $RB_HOME \
    && cd $RB_HOME \
    && npm install \
    && useradd -U -r -s /bin/bash $RB_USER \
    && mkdir -p $RB_DATA \
    && chown -R $RB_USER:$RB_USER $RB_DATA

COPY run-restbase.sh /run-restbase.sh
RUN chmod -v +x /run-restbase.sh

COPY projects_docker.yaml $RB_HOME/projects/docker.yaml

EXPOSE 7231
CMD ["/run-restbase.sh"]
VOLUME $RB_DATA
