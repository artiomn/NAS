# Персональное облако

![](https://habrastorage.org/webt/pp/rh/gv/pprhgvtoydiwu1ks2fpnobjszqm.png)

Облачное хранилище позволяет не только хранить данные, но и обеспечивать совместную работу с ними [в NAS](https://habr.com/post/359346/).

<cut/>

## Возможные решения

Существует несколько вариантов облачных сервисов: NextCloud, Seafile, Pydio и т.д..
Ниже рассмотрена часть из них.

<spoiler title="Реализации облачных сервисов.">
### [OwnCloud](https://owncloud.org/)

[![](https://habrastorage.org/webt/fj/be/gx/fjbegxfckhsx7ww4y9b8_m10jsm.png)](https://habrastorage.org/webt/fj/be/gx/fjbegxfckhsx7ww4y9b8_m10jsm.png)

Реализован на PHP/Javascript.

Возможности:

- Возможно расширять функционал, устанавливая приложения из репозитория облака.
- Есть интеграция с офисом Collabora и OnlyOffice.
- Возможно использовать существующие хранилища, такие как FTP, Swift, S3, Dropbox и т.п.,
  распределяя данные между ними и локальным облаком.
- Шифрование на клиенте.
- Возможность предоставлять файлы внешним пользователям по e-mail.
- Есть автоматизация операций с файлами (например, автоматическое добавление тэгов).
- LDAP.
- Есть аудио плеер, музыкальная коллекция, галерея плагин чтения PDF.
- Интеграция с Zimbra.
- Есть календари, списки задач, текстовые редакторы и т.п.
- Антивирус и защита от ransomware.
- Двуфакторная аутентификация.
- Возможность имперсонации под другого пользователя (с целью отладки).


### [NextCloud](https://nextcloud.org/)

[![](https://habrastorage.org/webt/62/cb/lo/62cbloe--f5eaxvejke31jqk-r4.png)](https://habrastorage.org/webt/62/cb/lo/62cbloe--f5eaxvejke31jqk-r4.png)

Форк OwnCloud. Реализован на PHP/Javascript.

Возможности:

- Хранение файлов с использованием обычных структур каталогов, или с использованием WebDAV.
- Есть NextCloud Talk, через который возможно делать видеозвонки и видеоконференции.
- Синхронизация между клиентами под управлением Windows (Windows XP, Vista, 7 и 8), Mac OS X (10.6 и новее) или Linux.
- Синхронизация с мобильными устройствами.
- Календарь (также как CalDAV).
- Планировщик задач.
- Адресная книга (также как CardDAV).
- Потоковое мультимедиа (используется Ampache).
- Поддерживает разные провайдеры авторизации: LDAP, OpenID, Shibboleth.
- Двуфакторная авторизация.
- Разделение контента между группами или используя публичные URL. Тонкая настройка правил.
- Онлайн текстовый редактор с подсветкой синтаксиса и сворачиванием. Анонсирована поддержка онлайн-версий редакторов LibreOffice.
- Закладки.
- Механизм сокращения URL.
- Фотогалерея.
- Просмотрщик PDF (используется PDF.js)
- Интеграция с Collabora и OnlyOffice.
- Модуль логирования.
- Возможность создания свои Web-сайтов (на PicoCMS).
- Интеграция с Outlook и Thunderbird.
- Интеграция клиента в Gnome.
- Возможность использовать внешнее хранилище.
- Полнотекстовый поиск.
- Интеграция с антивирусом.


### [SparkleShare](http://www.sparkleshare.org/)

Реализован на C#.

Возможности:

- Версионирование.
- Шифрование на клиенте.
- Прозрачная синхронизация между несколькими пользователями: удалённые изменения появятся в локальном каталоге, выделенном для SparkleShare.


Особенности:

- Использует git, как бэкэнд.


### [Seafile](https://www.seafile.com)

[![](https://habrastorage.org/webt/gk/rb/op/gkrbopkni_o44lqncmhdeuqe2fa.png)](https://habrastorage.org/webt/gk/rb/op/gkrbopkni_o44lqncmhdeuqe2fa.png)

Реализован на C/Javascript.

Возможности:

- Файлы могут быть организованы в библиотеки, которые могут быть синхронизированы между устройствами.
- Есть клиент, позволяющий создать локальный "диск", отображённый на облако.
- Встроенное шифрование. Все файлы шифруются клиентом и хранятся в облаке зашифрованными.
- Поддержка мобильных устройств.
- HTTS/TLS шифрование.
- Есть LDAP.
- Тонкая настройка прав.
- Версионирование файлов.
- Возможность создания снимка каталога, к которому потом возможно вернуться.
- Дедупликация.
- Поддержка блокировки файлов.
- Совместное редактирование файлов онлайн.
- Антивирус.
- Тонкая настройка прав.
- Периодический бэкап через rsync.
- WebDAV.
- REST API.
- Возможность интеграции с Collabora.

Особенности:

- Быстрый и нетребовательный к ресурсам.
- Считается надёжным.
- Установка прав на подкаталоги поддерживается только в платной Pro версии.
- Интеграция с антивирусом - только в Pro версии.
- Аудит - только в Pro версии.
- Полнотекстовый поиск - только в Pro версии.
- Интеграция с S3 и Ceph - только в Pro версии.
- Онлайн просмотр Doc/PPT/Excel - только в Pro версии.


### [Pydio](https://pydio.com)

[![](https://habrastorage.org/webt/v7/7n/he/v77nhe_y1o7wq8lkg7e1dhtp1ms.jpeg)](https://habrastorage.org/webt/v7/7n/he/v77nhe_y1o7wq8lkg7e1dhtp1ms.jpeg)

Реализован на PHP/Javascript.

Возможности:

- Обмен файлами не только между пользователями, но и между несколькими экземплярами Pydio.
- SSL/TLS шифрование.
- WebDAV.
- Возможность создать несколько рабочих пространств.
- Обмен файлами с внешними пользователями, с тонкой настройкой обмена (например, прямые ссылки, пароль и т.п.).
- Встроен офис Collabora.
- Предосмотр и редактирование изображений.
- Есть встроенный аудио и видео проигрыватель.


### [ProjectSend](https://www.projectsend.org)

[![](https://habrastorage.org/webt/61/1k/uc/611kuc8ohfjs4ym7kajncgufowo.png)](https://habrastorage.org/webt/61/1k/uc/611kuc8ohfjs4ym7kajncgufowo.png)

Реализован на PHP/Javascript.

Возможности:

- Возможно расшаривать файлы, как между конкретными пользователями, так и между группами.
- Полный отчёт по операциям с файлами.
- Возможность внешним пользователям загружать файлы (с целью обмена, например прикладывать баг-репорты).


### [SpiderOak](https://spideroak.com/)

[![](https://habrastorage.org/webt/w9/ce/k5/w9cek5imrxva3-chj9iejtwdh04.jpeg)](https://habrastorage.org/webt/w9/ce/k5/w9cek5imrxva3-chj9iejtwdh04.jpeg)

Возможности:

- Экономия места в хранилище и времени выгрузки файлов за счёт дедупликации и внесения изменений в уже имеющиеся файлы (вместо перезаписи файлов целиком).
- Настраиваемая мультиплатформенная синхронизация.
  DropBox для синхронизации создаёт специальную папку, в которую надо помещать все синхронизируемые файлы. SpiderOak может работать с любым каталогом.
- Сохранение всех хронологических версий файлов и удаленных файлов
- Совместное использование папок при помощи так называемых ShareRooms, на которые устанавливается пароль.
  Файлы, обновлённые на локальном компьютере, автоматически обновляются в хранилище. Пользователи извещаются об изменениях по RSS.
- Получение файлов с любого подключенного к Интернету устройства.
- Полное шифрование данных по принципу «нулевого знания».
- Поддержка неограниченного количества устройств.
- Шифрование данных на стороне клиента.
- Двуфакторная аутентификация.

Особенности:

Закрытая проприетарная система.

С учётом того, что данное ПО платное и частично закрытое, его использование исключается.
</spoiler>


## Установка NextCloud

Изначально было желание использовать Seafile: серверная часть реализована на C, он эффективен и стабилен. Но выяснилось, что в бесплатной версии есть далеко не всё.

Потому, я попробовал Nextcloud и остался доволен. Он предоставляет больше возможностей и полностью бесплатен.

Посмотреть, как он работает в демо-режиме вы можете [здесь](https://demo.nextcloud.com/).

Вот общие точки сопряжения между облачным хранилищем и системой:

- `/tank0/apps/cloud/nextcloud` - хранилище облачного сервиса.
- `/tank0/apps/onlyoffice` - данные офиса.
- `https://cloud.NAS.cloudns.cc` - WEB интерфейс облачного сервиса.

Т.к. конфигурация NextCloud достаточно объёмна и состоит из нескольких файлов, я не буду приводить их здесь.

Всё, что нужно вы найдёте в [репозитории на Github](https://github.com/artiomn/NAS/tree/master/docker/services/cloud/nextcloud).

Там же доступна конфигурация для [SeaFile](https://github.com/artiomn/NAS/tree/master/docker/services/cloud/seafile).

Сначала установите и запустите NextCloud.

Для этого надо скопировать конфигурацию в каталог `/tank0/docker/services/nextcloud` и выполнить:

```
# docker-compose up -d
```

Будет собран новый образ на основе Nextcloud 13.0.7. Если вы хотите изменить версию базового образа, сделайте это в `app/Dockerfile`. Я использую версию 15, но стоит заметить, что в ней не работают многие плагины, такие как загрузчик ocDownloader и заметки, а также я ещё не восстановил работоспособность OnlyOffice.

Кардинальных отличий или сильного улучшения производительности я не заметил.

Ниже я считаю, что вы используете версию 13+.

Далее, зайдите в NextCloud и выбрав в меню справа вверху "Приложения", выполните установку необходимых плагинов.

[![Приложения](https://habrastorage.org/webt/sd/3y/rv/sd3yrvs5lqfdzig5smsbdasiiw0.png)](https://habrastorage.org/webt/sd/3y/rv/sd3yrvs5lqfdzig5smsbdasiiw0.png)

Потребуются обязательно:

- **LDAP user and group backend** - сопряжение с LDAP.
- **External Storage Support** - поддержка внешних хранилищ. Нужна будет далее, с целью интеграции NextCloud и общих файлов, а также сопряжения с внешними облачными хранилищами. Про настройку внешних хранилищ я расскажу в другой статье.
- **ocDownloader** - загрузчик файлов. Расширяет функциональность облака. Docker образ специально пересобран так, чтобы он работал.
- **ONLYOFFICE** - интеграция с офисом. Без этого приложения, файлы документов не будут открываться в облаке.
- **End-to-End Encryption** - сквозное шифрование на клиенте. Если облако используют несколько пользователей, плагин необходим, чтобы удобно обеспечить безопасность их файлов.

Желательные приложения:

- **Brute-force settings** - защита от подбора учётных данных. NextCloud смотрит в Интернет, потому лучше установить.
- **Impersonate** - позволяет администратору заходить под другими пользователями. Полезно для отладки и устранения проблем.
- **Talk** - видеочат.
- **Calendar** - говорит сам за себя, позволяет вести календари в облаке.
- **File Access Control** - позволяет запрещать доступ к файлам и каталогам пользователям на основе тэгов и правил.
- **Checksum** - позволяет вычислять и просматривать контрольные суммы файлов.
- **External sites** - создаёт ссылки на произвольные сайты на панельке вверху.

Особенности контейнера:

- Установлен загрузчик Aria2.
- Установлен загрузчик Youtube-DL.
- Установлены inotify-tools.
- Увеличены лимиты памяти для PHP.
- Web-сервер настроен под лучшую работу с LDAP.

Замечу, что если вы установите версию 13+, но потом решите обновиться на версию 15, это и многое другое вы сможете сделать с помощью утилиты [occ](https://docs.nextcloud.com/server/14/admin_manual/configuration_server/occ_command.html).


### LDAP

Настройка LDAP не тривиальна, потому я расскажу подробнее.

Зайдите в "Настройки->Интеграция с LDAP/AD".
Добавьте сервер 172.21.0.1 с портом 389.
Логин: `cn=admin,dc=nas,dc=nas`.
NextCloud может управлять пользователями в базе LDAP и для этого ему потребуется администратор.

[![](https://habrastorage.org/webt/9n/tg/h9/9ntgh9xbg3rtfvjrqid6qbj0a5y.png)](https://habrastorage.org/webt/9n/tg/h9/9ntgh9xbg3rtfvjrqid6qbj0a5y.png)

Нажимайте кнопку "Проверить конфигурацию DN" и, если индикатор проверки зелёный, кнопку "Далее".

Каждый пользователь имеет атрибут `inetOrgPerson` и состоит в группе `users_cloud`.

Фильтр будет выглядеть так:

```
(&(|(objectclass=inetOrgPerson))(|(memberof=cn=users_cloud,ou=groups,dc=nas,dc=nas)))
```

Нажимайте "Проверить базу настроек и пересчитать пользователей", и если всё корректно, должно быть выведено количество пользователей. Нажимайте "Далее".

На следующей странице будет настроен фильтр пользователей, по которому NextCloud их будет искать.

Фильтр:

```
￼(&(objectclass=inetOrgPerson)(uid=%uid))
```

На этой странице надо ввести логин какого-либо пользователя и нажать "Проверить настройки".
Последний раз "Далее".

Тут нажмите "Дополнительно" и проверьте, что поле "База дерева групп" равно полю "База дерева пользователей" и имеет значение `dc=nas,dc=nas`.

Вернитесь в группы и установите в поле "Только эти классы объектов" галочку напротив `groupOfUniqueNames`.

Итоговый фильтр здесь такой:

```
(&(|(objectclass=groupOfUniqueNames)))
```

Поле "Только из этих групп" я не устанавливал, т.к. хочу увидеть в интерфейсе NextCloud всех пользователей, а те кто не входит в группу `users_cloud`, отсеиваются фильтром на предыдущем этапе.


## OnlyOffice

[![](https://habrastorage.org/webt/fr/rs/9e/frrs9euxco6_ycd8p_4a1y8bxiw.png)](https://habrastorage.org/webt/fr/rs/9e/frrs9euxco6_ycd8p_4a1y8bxiw.png)

[OnlyOffice](https://onlyoffice.com) - это прекрасный кроссплатформенный офисный пакет, который поддерживает работу с документами MS Office. Он бесплатный и открытый, также как и [LibreOffice](https://ru.libreoffice.org/) и также способен работать, как сервер.

Но при этом, поддержка оригинального формата у него реализована гораздо лучше, почти как в оригинальном офисе от MS, он более стабилен, имеет более продуманный интерфейс.

Также он [из коробки интегрируется с NextCloud](https://api.onlyoffice.com/editors/nextcloud).

Кстати, есть и Desktop версия OnlyOffice, в том числе под Linux. В общем, намучавшись с тяжёлой и нестабильной Collabora (это LibreOffice), я выбрал OnlyOffice и пока вполне доволен.

Конфигурация OnlyOffice [доступна на Github](https://github.com/artiomn/NAS/tree/master/docker/services/office/onlyoffice) и ниже, под спойлером.

На Github есть [конфигурация и для Collabora](https://github.com/artiomn/NAS/tree/master/docker/services/office/collabora).

<spoiler title="/tank0/docker/services/office/onlyoffice/docker-compose.yml">
```yaml
version: '2'

# https://helpcenter.onlyoffice.com/ru/server/docker/document/docker-installation.aspx

networks:
  onlyoffice:
    driver: 'bridge'
  docker0:
    external:
      name: docker0

services:
  onlyoffice-redis:
    container_name: onlyoffice-redis
    image: redis
    restart: always
    networks:
      - onlyoffice
    expose:
      - '6379'

  onlyoffice-rabbitmq:
    container_name: onlyoffice-rabbitmq
    image: rabbitmq
    restart: always
    networks:
      - onlyoffice
    expose:
      - '5672'

  onlyoffice-postgresql:
    container_name: onlyoffice-postgresql
    image: postgres
    environment:
      - POSTGRES_DB=onlyoffice
      - POSTGRES_USER=onlyoffice
    networks:
      - onlyoffice
    restart: always
    expose:
      - '5432'
    volumes:
      - /tank0/apps/onlyoffice/postgresql_data:/var/lib/postgresql

  onlyoffice-documentserver-data:
    container_name: onlyoffice-documentserver-data
    image: onlyoffice/documentserver:latest
    environment:
      - ONLYOFFICE_DATA_CONTAINER=true
      - POSTGRESQL_SERVER_HOST=onlyoffice-postgresql
      - POSTGRESQL_SERVER_PORT=5432
      - POSTGRESQL_SERVER_DB_NAME=onlyoffice
      - POSTGRESQL_SERVER_USER=onlyoffice
      - RABBITMQ_SERVER_URL=amqp://guest:guest@onlyoffice-rabbitmq
      - REDIS_SERVER_HOST=onlyoffice-redis
      - REDIS_SERVER_PORT=6379
    stdin_open: true
    restart: always
    networks:
      - onlyoffice
    volumes:
       - /tank0/apps/onlyoffice/document-server-data/data:/var/www/onlyoffice/Data
       - /tank0/apps/onlyoffice/document-server-data/logs:/var/log/onlyoffice
       - /tank0/apps/onlyoffice/document-server-data/cache:/var/lib/onlyoffice/documentserver/App_Data/cache/files
       - /tank0/apps/onlyoffice/document-server-data/files:/var/www/onlyoffice/documentserver-example/public/files
       - /usr/share/fonts

  onlyoffice-documentserver:
    image: onlyoffice/documentserver:latest
    depends_on:
      - onlyoffice-postgresql
      - onlyoffice-redis
      - onlyoffice-rabbitmq
      - onlyoffice-documentserver-data
    environment:
      - ONLYOFFICE_DATA_CONTAINER_HOST=onlyoffice-documentserver-data
      - BALANCE=uri depth 3
      - EXCLUDE_PORTS=443
      - HTTP_CHECK=GET /healthcheck
      - EXTRA_SETTINGS=http-check expect string true
      - JWT_ENABLED=true
      - JWT_SECRET=<JWT_SECRET_TOKEN>
      # Uncomment the string below to redirect HTTP request to HTTPS request.
      #- FORCE_SSL=true
      - VIRTUAL_HOST=office.*
      - VIRTUAL_PORT=80
      - VIRTUAL_PROTO=http
      - CERT_NAME=NAS.cloudns.cc
    stdin_open: true
    restart: always
    networks:
      - onlyoffice
      - docker0
    expose:
      - '80'
    volumes:
      - /tank0/apps/onlyoffice/document-server/logs:/var/log/onlyoffice
      - /tank0/apps/onlyoffice/document-server/data:/var/www/onlyoffice/Data
      - /tank0/apps/onlyoffice/document-server/lib:/var/lib/onlyoffice
      - /tank0/apps/onlyoffice/document-server/db:/var/lib/postgresql
    volumes_from:
      - onlyoffice-documentserver-data
```
</spoiler>

Поясню некоторые моменты:

- Вам надо изменить <JWT_SECRET_TOKEN> на свой, также как и NAS на имя своей DNS зоны.
- HTTPS здесь не требуется включать, потому что хотя офис и виден снаружи, обмен с ним идёт через обратный прокси, который работает с пользователем исключительно по HTTPS. Так построена архитектура NAS.

Теперь надо поднять офис:

```
docker-compose up -d
```

И, если всё работает, по адресу office.NAS.cloudns.cc будет следующая страница:

[![Экран сервера OnlyOffice](https://habrastorage.org/webt/nt/e6/nq/nte6nqehacnsc__jn_zpqja9hi0.png)](https://habrastorage.org/webt/nt/e6/nq/nte6nqehacnsc__jn_zpqja9hi0.png)

Затем, в настройках NextCloud требуется выбрать Пункт "Администрирование->ONLYOFFICE" и прописать в первых двух полях адрес сервера документов: `https://office.NAS.cloudns.cc/` и ваш JWT token.

В третьем поле надо прописать адрес облака.

JWT токен возможно сгенерировать, например [здесь](https://jwt.io/).

Если сервер настроен правильно, в меню создания документов облака появятся дополнительные пункты для офисных документов, а `.docx` файлы будут открывать в офисе.


## Выводы

Облачное хранилище является центральным звеном для взаимодействия пользователей между собой и другими сервисами.

В этой роли NextCloud весьма удобен и обладает широким функционалом.

У него есть свои в процессе обновления между версиями, но в целом, это хранилище возможно рекомендовать.
