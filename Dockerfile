# Contao-ready PHP runtime tuned for Contao 4.9 (PHP 7.4)
FROM php:7.4-apache

LABEL org.opencontainers.image.source="https://contao.org" \
      org.opencontainers.image.description="Contao ready PHP + Apache image"

ENV APACHE_DOCUMENT_ROOT=/var/www/html/web \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1

# Install system libraries and PHP extensions required per Contao docs
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        unzip \
        libicu-dev \
        libxml2-dev \
        libcurl4-openssl-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libfreetype6-dev \
        libzip-dev \
        zlib1g-dev \
        libonig-dev \
        libmagickwand-dev \
        libsodium-dev \
        libgmp-dev \
        libxslt1-dev \
        mariadb-client; \
    docker-php-ext-configure gd --with-jpeg --with-freetype --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        opcache \
        pcntl \
        pdo_mysql \
        soap \
        sodium \
        zip; \
    pecl install imagick; \
    docker-php-ext-enable imagick; \
    a2enmod rewrite headers; \
    mkdir -p "$APACHE_DOCUMENT_ROOT"; \
    sed -ri 's!DocumentRoot /var/www/html!DocumentRoot ${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf; \
    sed -ri 's!<Directory /var/www/html>!<Directory ${APACHE_DOCUMENT_ROOT}>!g' /etc/apache2/apache2.conf /etc/apache2/sites-available/000-default.conf; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Provide Composer for installing Contao via composer/manager
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Apply php.ini overrides
COPY docker/php/php.ini /usr/local/etc/php/conf.d/contao.ini

# Contao helper scripts
COPY scripts/install-contao.sh /usr/local/bin/install-contao
COPY scripts/entrypoint.sh /usr/local/bin/contao-entrypoint
RUN chmod +x /usr/local/bin/install-contao /usr/local/bin/contao-entrypoint

WORKDIR /var/www/html

# Provide non-root option for CI
RUN useradd --create-home --shell /bin/bash contao && \
    chown -R contao:contao /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/contao-entrypoint"]
CMD ["apache2-foreground"]
