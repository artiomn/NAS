FROM nextcloud:21-fpm

#        supervisor \
RUN echo "deb http://ftp.debian.org/debian stretch main" >> /etc/apt/sources.list \
    && apt-get update && apt-get install --no-install-recommends -y \
        aria2 \
        ffmpeg \
        libgmp3-dev \
        libc-client-dev \
        libkrb5-dev \
        libbz2-1.0 \
        python \
        smbclient \
        sudo \
        libsmbclient-dev \
        inotify-tools \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && ln -fs "/usr/include/$(dpkg-architecture --query DEB_BUILD_MULTIARCH)/gmp.h" /usr/include/gmp.h \
    && docker-php-ext-install gmp imap \
    && pecl install smbclient inotify \
    && docker-php-ext-enable smbclient inotify \
    && rm -rf /var/lib/apt/lists/*
#    && mkdir /var/log/supervisord /var/run/supervisord

#
# Downloaders.
#

# Download latest youtube-dl binary, need python runtime
RUN curl -sSL https://yt-dl.org/latest/youtube-dl -o /usr/local/bin/youtube-dl \
    && chmod a+rx /usr/local/bin/youtube-dl \
    # Make not existing ./data/ for specified permission
    && mkdir /var/www/html/data \
    && chmod -R 770 /var/www/html/data \
    && mkdir -p /var/www/html/apps/aria2 \
    && chmod -R 770 /var/www/html/apps/aria2 \
    && touch /var/www/html/apps/aria2/aria2c.sess \
    && { \
        echo '[www]'; \
        echo 'pm=dynamic'; \
        echo 'pm.max_children=25'; \
        echo 'pm.start_servers=10'; \
        echo 'pm.min_spare_servers=5'; \
        echo 'pm.max_spare_servers=20'; \
        echo 'pm.max_requests=700'; \
    } > /usr/local/etc/php-fpm.d/zz-www.conf; \
    \
    echo 'memory_limit=2048M' > /usr/local/etc/php/conf.d/memory-limit.ini \
   # ocDownloader requirements.
   && sed -i 's|exec "$@"|sudo -u www-data -- /usr/bin/aria2c --enable-rpc --rpc-allow-origin-all -c -D --log=/dev/stdout --check-certificate=false --log-level=info|' /entrypoint.sh \
   && echo 'umask 0007' >> /entrypoint.sh \
   && echo 'exec "$@"' >> /entrypoint.sh

COPY redis.config.php /usr/src/nextcloud/config/redis.config.php

# --save-session=/var/www/html/apps/aria2/aria2c.sess --save-session-interval=2 --continue=true --input-file=/var/www/html/apps/aria2/aria2c.sess --rpc-save-upload-metadata=true --force-save=true

#USER www-data
