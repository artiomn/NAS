# Управление файлами в NAS

![](https://habrastorage.org/webt/sx/kt/5f/sxkt5ft6x7e1h0nugugxeastzlq.jpeg)

Кажется странным: зачем управлять файлами в файловом хранилище?

<cut/>

## Введение

NextCloud хорошо подходит для того, чтобы пользователь мог хранить в нём данные и обмениваться с другими пользователями, но оно не является хранилищем редко изменяемых структурированных данных, которые доступны сразу многим пользователям.

Например, он не перекодирует видео. Это делает медиа-сервер, но давать ему индексировать каталоги с файлами пользователей NextCloud - не лучшая идея.
Из медиа-серверов мне нравится Emby, однако его интерфейс для управления файлами весьма убог.

В NextCloud данная проблема решается, используя внешние хранилища.

Однако, кроме него существуют варианты для управления файлами, о которых я здесь хочу рассказать.


## Web-файловые менеджеры

Существует множество файловых менеджеров с Web-интерфейсом.
В основном, они встречаются у хостинг-провадйеров в админках, позволяя администратору небольшого сайта производить операции с файлами без использования FTP, SSH и подобного.
Я опишу лишь два наиболее мне понравившихся.


### [Sprut.io](https://sprut.io/ru/)

![](https://habrastorage.org/webt/2r/xj/i_/2rxji_siqwayh_d06fn3crlujga.png)

Удобный двухпанельный файловый менеджер с продуманным интерфейсов.
Поддерживает:

- Drag&Drop с множественной загрузкой.
- Выкачку нескольких файлов архивом.
- Файловый поиск.
- Управление доступом к директориям и файлам.
- Редактор кода с подсветкой синтаксиса для разных языков.
- Просмотр изображений.
- Горячие клавиши.
- Работу с внешним FTP.

![](https://habrastorage.org/webt/m7/kb/kh/m7kbkha5h_g9oqyvy09dg-r1gh8.png)

Подробнее возможно его [изучить в демо-режиме](https://demo.sprut.io:9443/login).

Его docker-compose файл приведён ниже и также [доступен на Github](https://github.com/artiomn/NAS/tree/master/docker/services/filesystem/sprutio).

<spoiler title="/tank0/docker/services/filesystem/sprutio/docker-compose.yml">
```yaml
version: '2'

networks:
  docker0:
    external:
      name: docker0
  internal:

services:
  app:
    image: beget/sprutio-app
    links:
      - redis:fm-redis
      - rpc:fm-rpc
    networks:
      - internal
    volumes_from:
      - frontend
    volumes:
      - "/tank0/apps/fs/sprutio/ssl:/app/ssl:rw"
      - "/tank0/apps/fs/sprutio/logs:/var/log/fm:rw"
    env_file:
      - "./app.env"

  rpc:
    image: beget/sprutio-rpc
    networks:
      - internal
    links:
      - redis:fm-redis
    volumes_from:
      - cron
    volumes:
      - "/tank0/user_data:/mnt:rw"
      - "/tank0/apps/fs/sprutio/var:/var/spool/fm:rw"
      - "/tank0/apps/fs/sprutio/logs:/var/log/fm:rw"
    env_file:
      - "./rpc.env"

  nginx:
    image: beget/sprutio-nginx
    links:
      - app:fm-app
    volumes_from:
      - cron
      - frontend
    networks:
      - internal
      - docker0
    volumes:
      - "/tank0/apps/fs/sprutio/ssl:/app/ssl:ro"
      - "/tank0/apps/fs/sprutio/logs:/var/log/nginx:rw"
    expose:
      - 80
      - 443
    environment:
      - TZ=Europe/Moscow
      - VIRTUAL_HOST=files.*
      - VIRTUAL_PORT=80
      - VIRTUAL_PROTO=http
      - CERT_NAME=NAS.cloudns.cc

  frontend:
    image: beget/sprutio-frontend
    networks:
      - internal

  cron:
    image: beget/sprutio-cron
    volumes:
      - "/tank0/apps/sprutio/downloads:/tmp/fm:rw"
    networks:
      - internal

  redis:
    image: redis:3.0
    networks:
      - internal

  # EOF
```
</spoiler>


### [KodExplorer](https://github.com/kalcaddle/KodExplorer)

![](https://habrastorage.org/webt/qi/co/fw/qicofwkuyuwu1gonhczdlp0ylqo.png)

Любопытный китайский файловый менеджер, частично повторяющий Проводник Windows.
Помимо, собственно, файлового менеджера, имеет много различных приложений, таких как калькулятор и плеер.

Поддерживает:

- Drag&Drop с множественной загрузкой файлов в фоне.
- Горячие клавиши.
- Многоязыковой интерфейс.
- Встроенный буфер обмена.
- Ролевую модель для управления доступом.
- Одновременную работу с несколькими открытыми каталогами (многооконный интерфейс Explorer).
- Разделение файлов и каталогов между несколькими пользователями.
- Миниатюры для изображений.
- Загрузку файлов с URL.
- Работу с архивами (zip, rar, 7z, tar, gzip, tgz).
- Файловый поиск по имени и содержимому.
- Просмотр файлов разных типов: изображений, текстовых, pdf, swf и т.д..
- Видеоплеер.
- Полноценный редактор кода с подсветкой для более чем 120 языков, регулярными выражениями, автозавершением и проверкой синтаксиса.

![](https://habrastorage.org/webt/x4/tf/4s/x4tf4swvatvrekpu0k1zbklevag.png)

Есть [демо-режим, где возможно его изучить подробнее](http://demo.kodcloud.com/index.php?user/login).

Конфиг для docker-compose [доступен на Github](https://github.com/artiomn/NAS/tree/master/docker/services/filesystem/kodexplorer) и под спойлером.

<spoiler title="/tank0/docker/services/filesystem/kodexplorer/docker-compose.yml">
```yaml
version: '2'

networks:
  docker0:
    external:
      name: docker0

services:
  kodexplorer:
    image: yangxuan8282/kodexplorer
    restart: "always"
    networks:
      - docker0
    expose:
      - 80
    volumes:
      - "/tank0/apps/fs/kodexplorer/html:/var/www/html"
    environment:
      - PGID=33
      - PUID=33
      - TZ=Europe/Moscow
      - VIRTUAL_HOST=files.*
      - VIRTUAL_PORT=80
      - VIRTUAL_PROTO=http
      - CERT_NAME=NAS.cloudns.cc
```
</spoiler>


## Rsync-сервер




## SFTP

Возможно использовать [SFTP с LDAP авторизацией](https://github.com/Turgon37/docker-sftp-ldap), но большого желания открывать очередной порт нет.

## Подключение внешних хранилищ в NextCloud


## WebDAV

Поэтому, я остановился на [WebDAV](https://ru.wikipedia.org/wiki/WebDAV). Поскольку автор оригинального репозитория не спешит принимать пулл-реквесты, а его вариант поддерживает ActiveDirectory, а не OpenLDAP, и содержит несколько багов, я предлагаю использовать [мой вариант WebDAV с авторизацией под LDAP](https://github.com/artiomn/docker-webdav).

Увы, nginx поддерживает LDAP только частично, потому лучше использовать Apache.

https://www.digitalocean.com/community/tutorials/how-to-configure-webdav-access-with-apache-on-ubuntu-14-04


### Nginx-webdav

https://github.com/artiomn/NAS/tree/master/docker/services/filesystem/nginx_webdav

<spoiler title="/tank0/docker/services/filesystem/nginx_webdav">
```yaml
version: '2'

networks:
  docker0:
    external:
      name: docker0

services:
  webdav:
    build: ./docker-webdav
    networks:
      - docker0
    expose:
      - 80
    volumes:
      - /tank0/user_data/:/data
      - /tank0/user_data/.uploads:/tmp/uploads
      - /tank0/apps/fs/webdav/logs:/log
    environment:
      - LDAP_SERVER=172.21.0.1
      - LDAP_PROTOCOL=ldap
      - LDAP_PORT=389
      # - LDAP_DOMAIN=test
      - LDAP_DN=ou=users,dc=nas,dc=nas
      - LDAP_FILTER=uid?sub?(&(objectClass=inetOrgPerson)(memberOf=cn=users_media,ou=groups,dc=nas,dc=nas))
      - LDAP_BIND_USER=cn=admin,dc=nas,dc=nas
      - LDAP_BIND_PASSWORD=<LDAP_PASSWORD>
      - LDAP_AUTH_MESSAGE=Please, enter your login and password
      - LDAP_OPEN_METHODS=none
      - CHOWN=0
      - MIN_DELETE_DEPTH=3
      - PGID=33
      - PUID=33
      - TZ=Europe/Moscow
      - VIRTUAL_HOST=files.*,dav.*
      - VIRTUAL_PORT=80
      - VIRTUAL_PROTO=http
      - CERT_NAME=NAS.cloudns.cc
    restart: always
```
</spoiler>


### NextCloud

Хотя и у NextCloud есть WebDAV: https://cloud.NAS.cloudns.cc/remote.php/dav

https://github.com/artiomn/NAS/blob/master/docker/services/cloud/nextcloud/docker-compose.yml

```
  app:
    build: ./app
    volumes:
      # Main folder, needed for updating
      - /tank0/apps/cloud/nextcloud/html:/var/www/html
      - /tank0/user_data:/user_data
```

```
  dav-proxy:
    restart: always
    image: nginx:alpine
    expose:
      - 80
    environment:
      - "VIRTUAL_HOST=dav.*"
      - "VIRTUAL_PROTO=http"
      - "VIRTUAL_PORT=80"
      - CERT_NAME=NAS.cloudns.cc
    links:
      - web
    volumes:
      - ./dav-proxy-config:/etc/nginx/conf.d
```


## Заключение

Я остановился на NextCloud с внешним хранилищем.
