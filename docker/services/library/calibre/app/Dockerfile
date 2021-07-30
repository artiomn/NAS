FROM python:2

ENV APPNAME="Calibre" UMASK_SET="022" CALIBRE_DEVELOP_FROM="/opt/calibre-master/src" \
 MIN_TIME_DIFF_TO_SYNC_DB=15 INOTIFY_WAIT=5

COPY entrypoint.sh /

RUN \
 echo "**** install runtime packages ****" && \
 chmod +x /entrypoint.sh && \
 apt-get update && \
 apt-get install -y --no-install-recommends --no-install-suggests \
	inotify-tools \
	libnss3 \
	jq \
	wget \
	xz-utils \
	libgl1 \
	unzip && \
 echo "**** install calibre ****" && \
 mkdir -p \
	/opt/calibre && \
 if [ -z ${CALIBRE_RELEASE+x} ]; then \
	CALIBRE_RELEASE=$(curl -sX GET "https://api.github.com/repos/kovidgoyal/calibre/releases/latest" \
	| jq -r .tag_name); \
 fi && \
 CALIBRE_VERSION="$(echo ${CALIBRE_RELEASE} | cut -c2-)" && \
 CALIBRE_URL="https://download.calibre-ebook.com/${CALIBRE_VERSION}/calibre-${CALIBRE_VERSION}-x86_64.txz" && \
 curl -o \
	/tmp/calibre-tarball.txz -L \
	"$CALIBRE_URL" && \
 tar xvf /tmp/calibre-tarball.txz -C \
	/opt/calibre && \
 /opt/calibre/calibre_postinstall && \
 echo "**** install calibre-symlinks ****" && \
 wget "https://github.com/artiomn/calibre/archive/master.zip" -O /tmp/calibre-n.zip && \
 unzip /tmp/calibre-n.zip -d /opt && \
 echo "**** cleanup ****" && \
 apt-get clean && \
 rm -rf \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

ENTRYPOINT ["/entrypoint.sh"]

