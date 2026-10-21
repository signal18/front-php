#!/bin/bash

# The site config is a bind mount: replace the environment placeholder only when it is present
if grep -q "____MIXR_ENV____" /etc/nginx/sites-available/default 2>/dev/null; then
  sed -i.bak "s/____MIXR_ENV____/$MIXR_ENV/g" /etc/nginx/sites-available/default
fi
mkdir -p /run/php
if [ -d /etc/clamav ]; then
  install -d -o clamav -g clamav /run/clamav
fi

# start all the services
exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
