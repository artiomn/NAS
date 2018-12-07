FROM nextcloud:13.0.7-fpm
 
#        supervisor \
RUN echo "deb http://ftp.debian.org/debian jessie-backports main" >> /etc/apt/sources.list \
    && apt-get update && apt-get install --no-install-recommends -y \
        aria2 \
        bzip2 \
        ffmpeg \
        libmagickwand-dev \
        libgmp3-dev \
        libc-client-dev \
        libkrb5-dev \
        python \
        smbclient \
        sudo \
        libsmbclient-dev \
        inotify-tools \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && ln -s "/usr/include/$(dpkg-architecture --query DEB_BUILD_MULTIARCH)/gmp.h" /usr/include/gmp.h \
    && docker-php-ext-install bz2 gmp imap \
    && pecl install imagick smbclient inotify \
    && docker-php-ext-enable imagick smbclient inotify
#    && mkdir /var/log/supervisord /var/run/supervisord

# Download latest youtube-dl binary, need python runtime
RUN curl -sSL https://yt-dl.org/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
        chmod a+rx /usr/local/bin/youtube-dl

# Make not existing ./data/ for specified permission
RUN mkdir /var/www/html/data && \
        chmod -R 770 /var/www/html/data && \
	mkdir -p /var/www/html/apps/aria2 && \
        chmod -R 770 /var/www/html/aria2 && \
	touch /var/www/html/aria2c.sess

# Allow framing into Organizr.
#RUN sed -i "s/\(.*header.*X-Frame-Options:.*SAMEORIGIN.*\)/\/\/\1/" /usr/src/nextcloud/lib/private/legacy/response.php
RUN  { \
        echo '[www]'; \
        echo 'pm=dynamic'; \
        echo 'pm.max_children=25'; \
        echo 'pm.start_servers=10'; \
        echo 'pm.min_spare_servers=5'; \
        echo 'pm.max_spare_servers=20'; \
        echo 'pm.max_requests=700'; \
    } > /usr/local/etc/php-fpm.d/zz-www.conf; \
    \
    echo 'memory_limit=2048M' > /usr/local/etc/php/conf.d/memory-limit.ini;

COPY redis.config.php /usr/src/nextcloud/config/redis.config.php
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh
