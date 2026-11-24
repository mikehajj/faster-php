FROM mikehajj/faster-nginx:latest

RUN echo "Install PHP 8.4 ..."
RUN apt-get update
RUN apt-get install -y lsb-release ca-certificates apt-transport-https software-properties-common -y
RUN add-apt-repository ppa:ondrej/php
# Refresh indexes after adding the PPA so php8.4 resolves to 8.4.28+ (Nov 2026 advisories / EC-3750)
RUN apt-get update
RUN apt-get install -y php8.4
RUN apt-get install -y \
    php8.4-bcmath \
    php8.4-bz2 \
    php8.4-cli \
    php8.4-common \
    php8.4-curl \
    php8.4-dba \
    php8.4-fpm \
    php8.4-gd \
    php8.4-gmp \
    php8.4-http \
    php8.4-imap \
    php8.4-intl \
    php8.4-ldap \
    php8.4-mbstring \
    php8.4-memcache \
    php8.4-memcached \
    php8.4-mongodb \
    php8.4-msgpack \
    php8.4-mysql \
    php8.4-odbc \
    php8.4-pgsql \
    php8.4-readline \
    php8.4-redis \
    php8.4-soap \
    php8.4-sqlite3 \
    php8.4-tidy \
    php8.4-uploadprogress \
    php8.4-xdebug \
    php8.4-xml \
    php8.4-yaml \
    php8.4-zip \
    php8.4-dev
RUN apt-get install -y php8.4-raphf
RUN php -v
RUN php -m

RUN echo " Optimizing PHP FPM Configuration ..."
COPY php/php-fpm.conf /etc/php/8.4/fpm/php-fpm.conf
COPY php/www.conf /etc/php/8.4/fpm/pool.d/www.conf
# Do not overwrite packaged php.ini (breaks conf.d extension loading). Use a drop-in instead.
COPY php/conf.d/99-ec3647-security.ini /etc/php/8.4/cli/conf.d/99-ec3647-security.ini
COPY php/conf.d/99-ec3647-security.ini /etc/php/8.4/fpm/conf.d/99-ec3647-security.ini

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
RUN echo "extension=simdjson.so" > /etc/php/8.4/cli/conf.d/20-simdjson.ini && \
    echo "extension=simdjson.so" > /etc/php/8.4/fpm/conf.d/20-simdjson.ini

# Clean up build dependencies and source code to keep the image size small
RUN rm -rf /usr/src/php-ext-simdjson

# Install PECL if not already present and necessary build tools
RUN apt-get install -y php-pear pkg-config libssl-dev

# Upgrade MongoDB PHP extension for PHP 8.4 (1.17.0 does not build on 8.4).
# Stay on the 1.x line (1.21.14); app library bump is EC-3756.
# Build from the PECL tarball with phpize — pecl channel lookup fails in CI with
# "No releases available for package pecl.php.net/mongodb" even though the tarball exists.
RUN apt-get remove -y php8.4-mongodb
RUN curl -fsSL -o /tmp/mongodb.tgz https://pecl.php.net/get/mongodb-1.21.14.tgz \
    && mkdir -p /tmp/mongodb \
    && tar -xzf /tmp/mongodb.tgz -C /tmp/mongodb --strip-components=1 \
    && cd /tmp/mongodb \
    && phpize \
    && ./configure \
    && make \
    && make install \
    && rm -rf /tmp/mongodb /tmp/mongodb.tgz
RUN echo "extension=mongodb.so" > /etc/php/8.4/cli/conf.d/20-mongodb.ini
RUN echo "extension=mongodb.so" > /etc/php/8.4/fpm/conf.d/20-mongodb.ini

RUN echo "listing php modules ..."
RUN php -m

# EC-3750 + Nov 2026 PHP advisories: final gate — patched runtime (>= 8.4.28)
RUN php -r '$v = PHP_VERSION; if (version_compare($v, "8.4.28", "<")) { fwrite(STDERR, "PHP $v is below required 8.4.28 (EC-3750)\n"); exit(1);} echo "PHP version gate OK: $v\n";' \
 && php-fpm8.4 -v \
 && php -i | grep -E '^session.upload_progress.enabled' \
 && php -r 'if (ini_get("session.upload_progress.enabled")) { fwrite(STDERR, "session.upload_progress.enabled must be Off (EC-3647)\n"); exit(1);} echo "session.upload_progress.enabled OK\n";'

RUN echo "==============================================="
RUN echo "Image Building Completed, Enjoy!"

CMD ["/bin/bash"]
