#!/bin/bash
# Build both variants. Push is a separate, explicit step.
set -e
cd "$(dirname "$0")"
PHP_VERSION=${PHP_VERSION:-8.4.27}
REF=$(git rev-parse --short HEAD 2>/dev/null || echo none)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
docker build --build-arg PHP_VERSION=$PHP_VERSION --build-arg VCS_REF=$REF --build-arg BUILD_DATE=$NOW \
  -t signal18/front-php:$PHP_VERSION .
docker build --build-arg PHP_VERSION=$PHP_VERSION --build-arg VCS_REF=$REF --build-arg BUILD_DATE=$NOW --build-arg CLAMAV=1 \
  -t signal18/front-php:$PHP_VERSION-clamav .
echo "push: docker push signal18/front-php:$PHP_VERSION && docker push signal18/front-php:$PHP_VERSION-clamav"
