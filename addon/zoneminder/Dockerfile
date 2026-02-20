FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      apache2 \
      curl \
      jq \
      libapache2-mod-php \
      mariadb-client \
      mariadb-server \
      php \
      php-mysql \
      tzdata \
      zoneminder \
    && a2enmod cgi headers expires rewrite \
    && a2enconf zoneminder \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8088

CMD ["/run.sh"]
