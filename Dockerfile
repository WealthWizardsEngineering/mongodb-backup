FROM debian:jessie-slim

ENV S3CMD_VERSION=1.6.1
ENV MONGO_VERSION=3.4.14-2.12

RUN apt-get update && apt-get install -y libpcap0.8 jq curl python python-dateutil python-magic && rm -rf /var/lib/apt/lists/*
ADD http://repo.percona.com/apt/pool/main/p/percona-server-mongodb-34/percona-server-mongodb-34-shell_${MONGO_VERSION}.jessie_amd64.deb /tmp/
ADD http://repo.percona.com/apt/pool/main/p/percona-server-mongodb-34/percona-server-mongodb-34-tools_${MONGO_VERSION}.jessie_amd64.deb /tmp/
RUN dpkg -i /tmp/percona-server-mongodb-34-shell_${MONGO_VERSION}.jessie_amd64.deb \
&& dpkg -i /tmp/percona-server-mongodb-34-tools_${MONGO_VERSION}.jessie_amd64.deb \
&& rm -f /tmp/percona-server-mongodb*

ADD https://github.com/s3tools/s3cmd/releases/download/v${S3CMD_VERSION}/s3cmd-${S3CMD_VERSION}.tar.gz /opt
# Docker behviour has changed so the ADD will automatically extract the tar.gz file, but we need to still try for older clients
RUN tar -zxvf /opt/s3cmd-${S3CMD_VERSION}.tar.gz --directory=/opt || true
RUN ln -s /opt/s3cmd-${S3CMD_VERSION}/s3cmd /usr/bin/s3cmd
RUN ln -s /opt/s3cmd-${S3CMD_VERSION}/S3 /usr/bin/S3
RUN mkdir /var/backup

ADD src/* /
ADD src/s3cfg /root/.s3cfg

VOLUME ["/var/backup"]
CMD [ "/backup.sh" ]
