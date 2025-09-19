# https://hub.docker.com/_/php/
# https://github.com/docker-library/php
FROM php:8.2-apache

# Install packages we need for WordPress
RUN set -ex; \
  apt-get update; \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -q -y --no-install-recommends \
    ghostscript \
    git-core \
    less \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libmagickwand-dev \
    libpng-dev \
    libzip-dev \
    unzip \
    zlib1g-dev \
    mailutils \
    msmtp \
    msmtp-mta \
  ;

# Install esh and add config for SendGrid
RUN curl -fsSL https://github.com/jirutka/esh/raw/master/esh > /bin/esh && chmod +x /bin/esh
COPY ./config/msmtprc.esh /etc/msmtprc.esh

# https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions
RUN set -ex; \
  docker-php-ext-configure gd --with-freetype --with-jpeg; \
  docker-php-ext-install -j "$(nproc)" \
    bcmath \
    exif \
    gd \
    intl \
    mysqli \
    opcache \
    zip \
  ; \
  pecl install imagick-3.7.0; \
  docker-php-ext-enable imagick; \
  pecl install redis; \
  docker-php-ext-enable redis

# Clean up
RUN set -ex; \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  rm -rf /var/lib/apt/lists/*

# Customize PHP config
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY ./config/php-custom.ini $PHP_INI_DIR/conf.d/php-custom.ini

# Enable Apache modules
RUN set -ex; a2enmod \
  cache \
  deflate \
  expires \
  headers \
  proxy \
  proxy_ajp \
  proxy_balancer \
  proxy_connect \
  proxy_http \
  rewrite \
  ssl \
  ;

# Configure Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
COPY ./config/000-default.conf /etc/apache2/sites-available/000-default.conf

# Properly log IP addresses when behind proxy
# https://github.com/docker-library/wordpress/issues/383
RUN set -ex; \
  a2enmod remoteip; { \
    echo 'RemoteIPHeader X-Forwarded-For'; \
    echo 'RemoteIPTrustedProxy 10.0.0.0/8'; \
    echo 'RemoteIPTrustedProxy 172.16.0.0/12'; \
    echo 'RemoteIPTrustedProxy 192.168.0.0/16'; \
    echo 'RemoteIPTrustedProxy 169.254.0.0/16'; \
    echo 'RemoteIPTrustedProxy 127.0.0.0/8'; \
  } > /etc/apache2/conf-available/remoteip.conf; \
  a2enconf remoteip; \
  find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# WP-CLI
RUN set -ex; \
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
  chmod +x wp-cli.phar; \
  mv wp-cli.phar /usr/local/bin/wp-cli.phar; \
  echo '#!/bin/sh' >> /usr/local/bin/wp; \
  echo 'wp-cli.phar "$@" --allow-root' >> /usr/local/bin/wp; \
  chmod +x /usr/local/bin/wp;
RUN mkdir -p /srv/web
COPY ./config/wp-cli.yml /srv/wp-cli.yml

# Self-signed certificate for https
RUN openssl req -x509 -batch -nodes -days 36525 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

# Set www-data's ID to 1000
RUN groupmod -g 1000 www-data
RUN usermod -u 1000 -g 1000 www-data

# Install pagespeed
RUN curl https://dl-ssl.google.com/dl/linux/direct/mod-pagespeed-stable_current_amd64.deb > /tmp/pagespeed.deb
RUN dpkg -i /tmp/pagespeed.deb && rm /tmp/pagespeed.deb
RUN mkdir -p /var/cache/mod_pagespeed && chown -R www-data:www-data /var/cache/mod_pagespeed

# Wordpress health for rolling updates
STOPSIGNAL WINCH
HEALTHCHECK CMD curl -fIsk -o /dev/null https://127.0.0.1/wp/wp-admin/images/wordpress-logo.svg || exit 1

EXPOSE 80
EXPOSE 443
WORKDIR /srv
