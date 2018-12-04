FROM debian:stretch-slim

ENV MONGO_PACKAGE percona-server-mongodb
ENV MONGO_MAJOR 34

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y --no-install-recommends python-pip python-setuptools ; \
    pip install --no-cache-dir wheel ; \
    pip install --no-cache-dir s3cmd ; \
    apt-get purge -y --auto-remove python-pip python-setuptools

RUN apt-get install -y --no-install-recommends \
    jq curl gnupg dirmngr lsb-release ca-certificates python python-dateutil python-magic

# Add Percona key (https://www.percona.com/blog/2016/10/13/new-signing-key-for-percona-debian-and-ubuntu-packages/)
RUN apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 8507EFA5
RUN echo "deb http://repo.percona.com/apt "$(lsb_release -sc)" main" | tee /etc/apt/sources.list.d/percona.list

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