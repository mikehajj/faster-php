# faster-php

PHP 8.4.28+ (FPM + CLI), Composer, simdjson, and MongoDB PECL on top of `mikehajj/faster-nginx`.

### Base
- `mikehajj/faster-nginx:latest`

### Stack
- PHP: **8.4.28 or newer** (EC-3750 + Nov 2026 PHP security release)
- Composer (`/usr/local/bin/composer`)
- simdjson (built from [crazyxman/simdjson_php](https://github.com/crazyxman/simdjson_php))
- mongodb **1.21.14** via PECL (apt `php8.4-mongodb` is not used)

### Security / FPM hardening (EC-3647 / EC-3750)
- Build fails unless `php` / `php-fpm8.4` report version ≥ 8.4.28
- `session.upload_progress.enabled = Off` via `php/conf.d/99-ec3647-security.ini` (CLI + FPM)
- Packaged `php.ini` is **not** overwritten (preserves ondrej `conf.d` extension loading)
- FPM pool: `php/php-fpm.conf`, `php/www.conf`

### Consumer note
App images that `COPY` their own `docker/php/www.conf` / `php.ini` over the base must keep the same `session.upload_progress` settings, or the FPM admin flag / drop-in will be replaced at app build time.

Staging consumers should use `FROM mikehajj/faster-php:8.4`. Production stays on `mikehajj/faster-php:latest` (PHP **8.2**), which is built from `main` and is **not** overwritten by this 8.4 branch.

### PHP packages (apt)
bcmath, bz2, cli, common, curl, dba, fpm, gd, gmp, http, imap, intl, ldap, mbstring, memcache, memcached, msgpack, mysql, odbc, pgsql, readline, redis, soap, sqlite3, tidy, uploadprogress, xdebug, xml, yaml, zip, dev, raphf

(`pspell` is omitted — unbundled from PHP 8.4 / not required by incent-backend.)

### Extra extensions
- simdjson
- mongodb (PECL 1.21.14)

### Image tags
```
mikehajj/faster-php:8.4     # this branch (EC-3750) — PHP 8.4
mikehajj/faster-php:latest  # main — PHP 8.2 (production)
```

### Build
Build and push `faster-ubuntu` → `faster-nginx` first, then:

```bash
# PHP 8.4 staging tag (this branch) — do NOT retag as :latest
docker build -t mikehajj/faster-php:8.4 .
docker push mikehajj/faster-php:8.4
```

### Layer chain
```
ubuntu:24.04 → faster-ubuntu → faster-nginx → faster-php
```
