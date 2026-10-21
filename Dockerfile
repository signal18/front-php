# signal18/front-php — nginx + php-fpm 8.4 front image (successor of signal18/frontmixrnew)
#   default        : docker build -t signal18/front-php:8.4.27 .
#   MixR (clamav)  : docker build --build-arg CLAMAV=1 -t signal18/front-php:8.4.27-clamav .
# NEVER put a secret in this file, a build arg or an ENV: this repo and the image are public.
ARG PHP_VERSION=8.4.27
FROM php:${PHP_VERSION}-fpm-bookworm

ARG CLAMAV=0
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.title="signal18/front-php" \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.revision=$VCS_REF

ENV DEBIAN_FRONTEND=noninteractive \
    SESSION_SAVE_PATH=tcp://127.0.0.1:11211 \
    BLACKFIRE_AGENT_SOCKET=tcp://blackfire.mixr.svc.cloud18:8707

# System packages (same tool set as frontmixrnew; mysql client = MariaDB client on Debian)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg unzip zip xz-utils bzip2 pwgen git \
      nginx memcached default-mysql-client \
      mmdb-bin libmaxminddb0 libheif-examples libheif1 libde265-0 libnuma1 vite \
      build-essential python3 python3-pip python3-setuptools \
      fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions (same module list as frontmixrnew)
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions \
      apcu bcmath blackfire calendar exif ffi gd gettext igbinary imagick imap intl \
      maxminddb memcache memcached msgpack mysqli opcache pcntl pdo_mysql ps pspell \
      shmop sockets sysvmsg sysvsem sysvshm tidy xmlrpc xsl yaml zip

# Composer 2, wp-cli
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
 && chmod +x /usr/local/bin/wp

# Node.js 18 (as frontmixrnew) and Google Chrome (headless rendering)
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
 && curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google.gpg \
 && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list \
 && apt-get update && apt-get install -y --no-install-recommends nodejs google-chrome-stable \
 && rm -rf /var/lib/apt/lists/*

# ClamAV, MixR variant only
RUN if [ "$CLAMAV" = "1" ]; then \
      apt-get update && apt-get install -y --no-install-recommends clamav-daemon clamav-freshclam \
      && rm -rf /var/lib/apt/lists/* \
      && install -d -o clamav -g clamav -m 750 /var/run/clamav \
      && install -d -o clamav -g clamav /var/lib/clamav \
      && sed -i 's/^Foreground false/Foreground true/' /etc/clamav/clamd.conf /etc/clamav/freshclam.conf \
      && freshclam --foreground --stdout ; \
    fi

# supervisord (same supervisor + supervisor_stdout setup as frontmixrnew)
RUN pip3 install --no-cache-dir --break-system-packages supervisor supervisor-stdout
COPY supervisord.conf /etc/supervisord.conf
COPY supervisor.d/ /etc/supervisor.d/
RUN if [ "$CLAMAV" != "1" ]; then rm -f /etc/supervisor.d/clamav.conf; fi

# PHP configuration: production php.ini + frontmixrnew overrides, our pool on the unix socket
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
 && rm -f /usr/local/etc/php-fpm.d/www.conf.default /usr/local/etc/php-fpm.d/zz-docker.conf
COPY php/zz-front.ini $PHP_INI_DIR/conf.d/zz-front.ini
COPY php/zz-blackfire.ini $PHP_INI_DIR/conf.d/zz-blackfire.ini
COPY php/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY php/zz-front-fpm.conf /usr/local/etc/php-fpm.d/zz-front-fpm.conf

# Compatibility with the Ubuntu layout of frontmixrnew (scripts calling php8.4 / php-fpm8.4 / /etc/php/8.4)
RUN ln -s /usr/local/bin/php /usr/bin/php \
 && ln -s /usr/local/bin/php /usr/bin/php8.4 \
 && ln -s /usr/local/sbin/php-fpm /usr/sbin/php-fpm8.4 \
 && mkdir -p /etc/php/8.4 && ln -s "$PHP_INI_DIR" /etc/php/8.4/fpm && ln -s "$PHP_INI_DIR" /etc/php/8.4/cli \
 && chsh -s /bin/bash www-data

# nginx: same tuning as frontmixrnew; the site is mounted on /etc/nginx/sites-available/default
RUN sed -i -e "s/keepalive_timeout 65;/keepalive_timeout 65;\n\tclient_max_body_size 100m;\n/" /etc/nginx/nginx.conf \
 && echo "daemon off;" >> /etc/nginx/nginx.conf \
 && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log
COPY nginx/nginx-extra.conf /etc/nginx/conf.d/extra.conf
COPY nginx/nginx-fd.conf /etc/nginx/conf.d/fd.conf
COPY nginx/nginx-cmp.conf /etc/nginx/conf.cmp.conf

COPY start.sh /start.sh
RUN chmod 755 /start.sh

EXPOSE 80 443
CMD ["/bin/bash", "/start.sh"]
