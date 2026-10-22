# faster-php

PHP 8.2.35+ (FPM + CLI), Composer, simdjson, and MongoDB PECL on top of `mikehajj/faster-nginx`.

### Base
- `mikehajj/faster-nginx:latest`

### Stack
- PHP: **8.2.35 or newer** (EC-3647 — CVE-2026-109618 / CVE-2026-109619)
- Composer (`/usr/local/bin/composer`)
- simdjson (built from [crazyxman/simdjson_php](https://github.com/crazyxman/simdjson_php))
- mongodb **1.17.0** via PECL (apt `php8.2-mongodb` is not used)

### Security / FPM hardening (EC-3647)
- Build fails unless `php` / `php-fpm8.2` report version ≥ 8.2.35
- `session.upload_progress.enabled = Off` via `php/conf.d/99-ec3647-security.ini` (CLI + FPM)
- Packaged `php.ini` is **not** overwritten (preserves ondrej `conf.d` extension loading)
- FPM pool: `php/php-fpm.conf`, `php/www.conf`

### Consumer note
App images that `COPY` their own `docker/php/www.conf` / `php.ini` over the base must keep the same `session.upload_progress` settings, or the FPM admin flag / drop-in will be replaced at app build time.

### PHP packages (apt)
bcmath, bz2, cli, common, curl, dba, fpm, gd, gmp, http, imap, intl, ldap, mbstring, memcache, memcached, msgpack, mysql, odbc, pgsql, pspell, readline, redis, soap, sqlite3, tidy, uploadprogress, xdebug, xml, yaml, zip, dev, raphf

### Extra extensions
- simdjson
- mongodb (PECL 1.17.0)

### Image
```
mikehajj/faster-php:latest
```

### Build
Build and push `faster-ubuntu` → `faster-nginx` first, then:

```bash
docker build -t mikehajj/faster-php:latest .
```

### Layer chain
```
ubuntu:24.04 → faster-ubuntu → faster-nginx → faster-php
```
