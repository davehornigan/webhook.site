# Thin overlay over the upstream build: webhook.site ships pdo_mysql and
# pdo_sqlite but no pdo_pgsql, and sqlite is not an option on NFS-backed
# storage, where its fcntl locking is unreliable.
ARG BASE
FROM ${BASE}
USER root
# postgresql-dev is only needed to compile the extension. libpq is what it links
# against at runtime, and removing the dev package takes libpq with it unless it
# is installed in its own right.
RUN apk add --no-cache --virtual .build-deps postgresql-dev \
 && docker-php-ext-install pdo_pgsql \
 && apk add --no-cache libpq \
 && apk del .build-deps
# Upstream's Dockerfile ends as root on purpose: nginx under s6 needs it to
# create /var/cache/nginx before it drops privileges itself. Switching to
# www-data here leaves it in a crash loop on "Permission denied".
USER root
