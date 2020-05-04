FROM debian:stretch-slim

EXPOSE 9841

RUN apt-get update && \
	apt-get install --no-install-recommends -y \
		ca-certificates wget \
		python3.4 python3-pil python3-lxml \
                python3-openssl python3-crypto poppler-utils \
		gir1.2-gtk-3.0
RUN wget https://downloads.openmedialibrary.com/openmedialibrary_0.1_all.deb
RUN dpkg -i openmedialibrary_0.1_all.deb

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT /entrypoint.sh
