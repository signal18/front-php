# signal18/front-php

nginx + php-fpm 8.4 front image, successor of `signal18/frontmixrnew` (Ubuntu 20.04, PHP 8.4.5).
Based on the official `php:<version>-fpm-bookworm` image.

| Tag | Content |
|---|---|
| `signal18/front-php:8.4.27` | nginx, php-fpm, memcached (sessions), Node 18, Chrome, wp-cli, composer |
| `signal18/front-php:8.4.27-clamav` | same + clamd/freshclam (MixR) |

Build: `./build.sh` (`PHP_VERSION=8.4.x ./build.sh` for another patch release).

Runtime: mount the site on `/etc/nginx/sites-available/default` (php-fpm listens on `unix:/var/run/php-fpm.sock`).
Environment: `MIXR_ENV`, `SESSION_SAVE_PATH` (default `tcp://127.0.0.1:11211`), `BLACKFIRE_AGENT_SOCKET`.

**Public repository and public image: never commit or bake a secret.** Secrets are provided at run time only.
