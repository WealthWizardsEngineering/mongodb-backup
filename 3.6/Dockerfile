FROM debian:stretch-slim

ENV MONGO_PACKAGE percona-server-mongodb
ENV MONGO_MAJOR 36

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y --no-install-recommends python-pip python-setuptools ; \
    pip install --no-cache-dir wheel ; \
    pip install --no-cache-dir s3cmd ; \
    apt-get purge -y --auto-remove python-pip python-setuptools

RUN apt-get install -y --no-install-recommends \
    jq curl gnupg dirmngr lsb-release ca-certificates python python-dateutil python-magic

# https://www.percona.com/doc/percona-server-for-mongodb/LATEST/install/apt.html
RUN curl https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb --output /tmp/percona-release.deb
RUN dpkg -i /tmp/percona-release.deb
RUN percona-release enable psmdb-42 release

RUN apt-get update && apt-get install -y \
      ${MONGO_PACKAGE}-${MONGO_MAJOR}-shell \
      ${MONGO_PACKAGE}-${MONGO_MAJOR}-tools

RUN apt-get purge -y --auto-remove lsb-release dirmngr; \
    rm -rf /var/lib/apt/lists/*

ADD src/* /
ADD src/s3cfg /root/.s3cfg

RUN mkdir /var/backup
VOLUME ["/var/backup"]

CMD [ "/backup.sh" ]
