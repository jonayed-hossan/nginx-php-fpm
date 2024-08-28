FROM php:8.3.10-fpm-alpine3.20

LABEL maintainer="Zunaid Hossan Gazi <me@zuna.id>"

# resolves #166
ARG LD_PRELOAD="/usr/lib/preloadable_libiconv.so php"

RUN apk add --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community gnu-libiconv

# Install pkg
RUN echo @testing https://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
  echo /etc/apk/respositories && \
  apk update && apk upgrade &&\
  apk add --no-cache \
  build-base shadow nano zlib zlib-dev openssl-dev bzip2-dev oniguruma-dev \
  ca-certificates openssl tar xz \
  bash \
  openssh-client \
  wget \
  supervisor \
  curl \
  libcurl \
  libpq \
  git \
  python3 \
  py3-pip \
  dialog \
  autoconf \
  make \
  libzip-dev \
  bzip2-dev \
  icu-dev \
  tzdata \
  libpng-dev \
  libjpeg-turbo-dev \
  freetype-dev \
  libxslt-dev \
  gcc \
  lua5.1 \
  lua5.1-dev \
  oniguruma-dev \
  ffmpeg nghttp2 jemalloc \
  nginx

RUN apk add --no-cache --virtual .sys-deps \
  musl-dev \
  linux-headers \
  augeas-dev \
  libmcrypt-dev \
  python3-dev \
  libffi-dev \
  gmp-dev \
  libuv-dev \
  sqlite-dev \
  imap-dev \
  lua-resty-core \
  libjpeg-turbo-dev \
  libwebp-dev \
  zlib-dev \
  libxpm-dev \
  libpng \
  libpng-dev && \
  docker-php-ext-configure gd \
  --enable-gd \
  --with-freetype \
  --with-jpeg && \
  docker-php-ext-install gd && \
  docker-php-ext-install pdo_mysql mysqli pdo_sqlite exif intl pcntl \
  xsl soap zip mbstring sockets bcmath calendar ctype filter ftp gmp && \
  pecl install uv-beta && \
  pecl install -o -f redis && \ 
  pecl install -o -f luasandbox && \
  docker-php-ext-enable luasandbox redis && \
  docker-php-source delete

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
  php composer-setup.php --quiet --install-dir=/usr/bin --filename=composer && \
  rm composer-setup.php &&\
  apk del gcc musl-dev linux-headers  augeas-dev python3-dev make autoconf && \
  apk del .sys-deps

RUN pip install --upgrade pip --break-system-packages && mkdir -p /var/www/app/public

#use custom config file
ADD app/conf/ /var/www/app-conf/
ADD app/conf/supervisord.conf /etc/supervisord.conf
ADD app/conf/php-fpm.conf /usr/local/etc/php-fpm.conf
ADD app/conf/php-fpm-pool.conf /usr/local/etc/php-fpm.d/www.conf
ADD app/conf/php-custom-ini.conf /usr/local/etc/php/conf.d/php-custom.ini
ADD app/conf/nginx.conf /etc/nginx/nginx.conf
ADD app/conf/nginx-server.conf /etc/nginx/http.d/default.conf

RUN cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini && \
  sed -i \
  -e "s/;opcache/opcache/g" \
  -e "s/;zend_extension=opcache/zend_extension=opcache/g" \
  /usr/local/etc/php/php.ini


# Add Scripts
ADD app/scripts/start.sh /start.sh
#RUN chmod 755 /start.sh
#ADD app/scripts/pull /usr/bin/pull
#ADD app/scripts/push /usr/bin/push
#ADD app/scripts/letsencrypt-setup /usr/bin/letsencrypt-setup
#ADD app/scripts/letsencrypt-renew /usr/bin/letsencrypt-renew
#RUN chmod 755 /usr/bin/pull && chmod 755 /usr/bin/push && chmod 755 /usr/bin/letsencrypt-setup && chmod 755 /usr/bin/letsencrypt-renew && 

# copy all code
ADD app/ /var/www/app/

EXPOSE 443 80

WORKDIR "/var/www/app/public"
CMD ["bash", "/start.sh"]
