# Contao-ready PHP runtime tuned for Contao 4.9 (PHP 7.4)
FROM php:7.4-apache

LABEL org.opencontainers.image.source="https://contao.org" \
      org.opencontainers.image.description="Contao ready PHP + Apache image"

ENV APACHE_DOCUMENT_ROOT=/var/www/html/web \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1

# Install system libraries and PHP extensions required per Contao docs
# Using retry logic to handle transient network errors during apt-get
RUN set -eux; \
    for i in 1 2 3; do \
        apt-get update && break || sleep 5; \
    done; \
    for i in 1 2 3; do \
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
            mariadb-client \
        && break || (apt-get update && sleep 5); \
    done; \
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
    a2enmod rewrite headers deflate filter; \
    mkdir -p /var/www/html/web; \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf; \
    sed -ri 's!DocumentRoot /var/www/html!DocumentRoot /var/www/html/web!g' /etc/apache2/sites-available/000-default.conf; \
    sed -ri '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Provide Composer 2.2.24 for compatibility with older Contao Manager Bundle
# Newer Composer versions (2.9+) have breaking changes in Process::__construct()
COPY --from=composer:2.2.24 /usr/bin/composer /usr/local/bin/composer

# Apply php.ini overrides
COPY docker/php/php.ini /usr/local/etc/php/conf.d/contao.ini

# Contao helper scripts
COPY scripts/install-contao.sh /usr/local/bin/install-contao
COPY scripts/entrypoint.sh /usr/local/bin/contao-entrypoint
COPY scripts/pin2SpecificVersion.sh /usr/local/bin/pin-contao-version
RUN chmod +x /usr/local/bin/install-contao /usr/local/bin/contao-entrypoint /usr/local/bin/pin-contao-version

WORKDIR /var/www/html

# Provide non-root option for CI
RUN useradd --create-home --shell /bin/bash contao && \
    chown -R contao:contao /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/contao-entrypoint"]
CMD ["apache2-foreground"]
