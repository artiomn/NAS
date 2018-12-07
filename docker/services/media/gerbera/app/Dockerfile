# Dockerfile for Gerbera Ubuntu Development
# Created by: Eamonn Buss
# Created on: 09/23/2017

##--------------------------------------
## Start with ubuntu image as the base
##--------------------------------------
FROM ubuntu:latest

##--------------------------------------
## Enable Ubuntu Repositories
##--------------------------------------
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN add-apt-repository main
RUN add-apt-repository universe
RUN add-apt-repository restricted
RUN add-apt-repository multiverse

##--------------------------------------
## Install Ubuntu Development essentials
##--------------------------------------
RUN apt-get install -y autoconf \
  automake \
  build-essential \
  cmake \
  git \
  libboost-all-dev \
  libtool \
  pkg-config \
  sudo \
  wget

##--------------------------------------
## Install Gerbera Build Prerequisites
##--------------------------------------
RUN apt-get install -y\
  uuid-dev \
  libexpat1-dev \
  libsqlite3-dev \
  libmysqlclient-dev \
  libmagic-dev \
  libexif-dev \
  libcurl4-openssl-dev \
  libavutil-dev \
  libavcodec-dev \
  libavformat-dev \
  libavdevice-dev \
  libavfilter-dev \
  libavresample-dev \
  libswscale-dev \
  libswresample-dev \
  libpostproc-dev \
  systemd \
  vorbis-tools

ENV SHELL /bin/bash

##--------------------------------------
## Clone Gerbera GIT Repository
##--------------------------------------
RUN mkdir /gerbera
WORKDIR /gerbera
RUN git clone https://github.com/elmodaddyb/gerbera.git

RUN mkdir build
WORKDIR /gerbera/build

##--------------------------------------
## Install libupnp library
##--------------------------------------
RUN sh ../gerbera/scripts/install-pupnp18.sh

##--------------------------------------
## Install taglib library
##--------------------------------------
RUN sh ../gerbera/scripts/install-taglib111.sh

##--------------------------------------
## Install Duktape and make library available
##--------------------------------------
RUN sh ../gerbera/scripts/install-duktape.sh
RUN echo /usr/local/lib > /etc/ld.so.conf.d/gerbera-x86_64.conf
RUN ldconfig

##--------------------------------------
## Build & Install Gerbera
##--------------------------------------
RUN cmake ../gerbera -DWITH_MAGIC=1 -DWITH_MYSQL=0 -DWITH_CURL=1 -DWITH_JS=1 -DWITH_TAGLIB=1 -DWITH_AVCODEC=1 -DWITH_EXIF=1 -DWITH_LASTFM=0
RUN make
RUN make install

##--------------------------------------
## Setup the Gerbera user
##--------------------------------------
RUN useradd --system gerbera
RUN mkdir /home/gerbera
RUN mkdir /home/gerbera/.config
RUN mkdir /home/gerbera/.config/gerbera

RUN chown gerbera:gerbera -Rv /usr/local/share/gerbera
RUN chown gerbera:gerbera -Rv /home/gerbera
USER gerbera

##--------------------------------------
## Setup Gerbera config.xml
##--------------------------------------
RUN gerbera --create-config > /home/gerbera/.config/gerbera/config.xml

ENTRYPOINT ["/usr/local/bin/gerbera", "--debug"]
EXPOSE 49152/tcp 1900/udp
