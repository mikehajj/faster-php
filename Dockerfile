FROM mikehajj/faster-nginx:latest

RUN echo "Install PHP8 ..."
RUN apt-get update
RUN apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common -y
RUN add-apt-repository ppa:ondrej/php
# Refresh indexes after adding the PPA so php8.2 resolves to 8.2.35+ (EC-3647)
RUN apt-get update
RUN apt-get install -y php8.2
RUN apt-get install -y \
    php8.2-bcmath \
    php8.2-bz2 \
    php8.2-cli \
    php8.2-common \
    php8.2-curl \
    php8.2-dba \
    php8.2-fpm \
    php8.2-gd \
    php8.2-gmp \
    php8.2-http \
    php8.2-imap \
    php8.2-intl \
    php8.2-ldap \
    php8.2-mbstring \
    php8.2-memcache \
    php8.2-memcached \
    php8.2-mongodb \
    php8.2-msgpack \
    php8.2-mysql \
    php8.2-odbc \
    php8.2-pgsql \
    php8.2-pspell \
    php8.2-readline \
    php8.2-redis \
    php8.2-soap \
    php8.2-sqlite3 \
    php8.2-tidy \
    php8.2-uploadprogress \
    php8.2-xdebug \
    php8.2-xml \
    php8.2-yaml \
    php8.2-zip \
    php8.2-dev
RUN apt-get install -y php8.2-raphf
RUN php -v
RUN php -m

RUN echo " Optimizing PHP FPM Configuration ..."
COPY php/php-fpm.conf /etc/php/8.2/fpm/php-fpm.conf
COPY php/www.conf /etc/php/8.2/fpm/pool.d/www.conf
# Do not overwrite packaged php.ini (breaks conf.d extension loading). Use a drop-in instead.
COPY php/conf.d/99-ec3647-security.ini /etc/php/8.2/cli/conf.d/99-ec3647-security.ini
COPY php/conf.d/99-ec3647-security.ini /etc/php/8.2/fpm/conf.d/99-ec3647-security.ini

# Install Composer
RUN echo "Installing PHP composer ..."
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && php -r "unlink('composer-setup.php');"
RUN php -v

# Clone the php-ext-simdjson repository
# Use --depth 1 to get only the latest commit, saving space
# Use -b <branch_name> to target a specific PHP version compatible branch if needed (e.g., master for latest)
RUN git clone -b master --depth 1 https://github.com/crazyxman/simdjson_php.git /usr/src/php-ext-simdjson

# Navigate into the extension directory, prepare for build, compile, and install
RUN cd /usr/src/php-ext-simdjson \
    && phpize \
    && ./configure \
    && make \
    && make install

# Enable the extension in PHP
# Use docker-php-ext-enable if available or create a custom .ini file
# Enable the extension in PHP for both CLI and FPM
RUN echo "extension=simdjson.so" > /etc/php/8.2/cli/conf.d/20-simdjson.ini && \
    echo "extension=simdjson.so" > /etc/php/8.2/fpm/conf.d/20-simdjson.ini

# Clean up build dependencies and source code to keep the image size small
RUN rm -rf /usr/src/php-ext-simdjson

# Install PECL if not already present and necessary build tools
RUN apt-get install -y php-pear pkg-config libssl-dev

# Upgrade MongoDB PHP extension to required version
RUN apt-get remove -y php8.2-mongodb
RUN pecl install mongodb-1.17.0
RUN echo "extension=mongodb.so" > /etc/php/8.2/cli/conf.d/20-mongodb.ini
RUN echo "extension=mongodb.so" > /etc/php/8.2/fpm/conf.d/20-mongodb.ini

RUN echo "listing php modules ..."
RUN php -m

# EC-3647: final gate — patched runtime (CVE-2026-109618 / CVE-2026-109619)
RUN php -r '$v = PHP_VERSION; if (version_compare($v, "8.2.35", "<")) { fwrite(STDERR, "PHP $v is below required 8.2.35 (EC-3647)\n"); exit(1);} echo "PHP version gate OK: $v\n";' \
 && php-fpm8.2 -v \
 && php -i | grep -E '^session.upload_progress.enabled' \
 && php -r 'if (ini_get("session.upload_progress.enabled")) { fwrite(STDERR, "session.upload_progress.enabled must be Off (EC-3647)\n"); exit(1);} echo "session.upload_progress.enabled OK\n";'

RUN echo "==============================================="
RUN echo "Image Building Completed, Enjoy!"

CMD ["/bin/bash"]
