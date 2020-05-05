# GitLab в NAS

![](images/lcdsgoqvkupc9ywr3m-83iqu-sy.jpeg)

При наличии [работоспособного NAS с докером](https://habr.com/post/415779/), установка Gitlab не представляет особых сложностей.

<cut/>

Эта статья является лишь наглядным примером в рамках цикла про NAS. И показывает как просто возможно манипулировать сервисами, на уже готовой платформе, даже построенной самостоятельно, без команды разработчиков, специально подогнанных ОС и магазинов приложений.


## Почему Gitlab?

Существует несколько систем для управления Git-репозиториями.
<spoiler title="Из них достаточно зрелыми являются...">

- [Bitbucket](https://bitbucket.org) - платная и закрытая система, хотя и популярная в корпоративном секторе. Предполагается интеграция с другими продуктами Atlassian, которые я не использую. Реализован на Java. Не особенно подходящее решение, особенно учитывая политику, что платить надо всё, даже за плагины (хотя есть и бесплатные).
- [Gogs](https://gogs.io/) - система, похожая на Gitlab. Реализована на Go. Когда я последний раз смотрел на её возможности, там не было возможности ревью кода. Да и вообще отстаёт по функционалу от Gitlab, т.к. система намного более новая:
  * Легковесен.
  * По интерфейсу похож на Github.
  * Управление пользователями.
  * Баг-трэкер.
  * Wiki.
  * **Нет ревью кода.**
  * Поддержка Git хуков.
  * Доступ по HTTPS/SSH.
  * Реализован на Go.
  * [Есть форк Gitea](https://github.com/go-gitea/gitea).
  * Имеется LDAP плагин.
- [Gitea](https://gitea.io/en-us/) - форк Gogs. Имеет то, чего не хватает в Gogs:
  * Code review.
  * Хранилище для больших файлов.
  * Метки.
  * Доработанный поиск.
  * Прогресс задач с чекбоксами.
  * LDAP тоже поддерживается.
- [Kallithea](https://kallithea-scm.org/repos/) - форк RhodeCode.
  * Очень развитое управление пользователями и группами.
  * Синхронизация с удалёнными репозиториями.
  * Баг-трэкер.
  * Wiki.
  * Есть ревью кода.
  * Поддержка Git хуков.
  * Доступ по HTTPS/SSH.
  * Реализован на Python.
  * Интегрируется с LDAP.
  * Есть образ Docker.
- [Phacility](https://www.phacility.com/) - система от Facebook. Функционал широкий, есть не только ревью, но даже система управления задачами и проектами. Подробно я её не рассматривал.
- [Gerrit](https://ru.wikipedia.org/wiki/Gerrit) - предназначен, в основном для обсуждения и ревью кода, с некоторым функционалом для управления репозиториями.
- [Sr.ht](https://meta.sr.ht/) - порекомендовали [в комментариях](https://habr.com/post/418883/#comment_19568348). Судя по всему, функционал достаточно широкий. Но система пока в стадии активной разработки.
</spoiler>

С Gitlab я работал до этого, кроме того, он имеет встроенный функционал CI, что в будущем мне пригодится. Система зрелая, по ней есть много документации, и за годы разработки Gitlab оброс множеством возможностей. Потому, я его и выбрал.


## Общие настройки

Я использую [образ Gitlab от sameersbn](https://github.com/sameersbn/docker-gitlab).
В [`docker-compose.yml`](https://github.com/artiomn/NAS/blob/master/docker/services/gitlab/docker-compose.yml) (файл также приведён в конце статьи) надо изменить следующие переменные:

- `DB_PASS`- пароль на базу данных Gitlab. Должен совпадать с паролем в контейнере `postgresql`.
- `GITLAB_SECRETS_DB_KEY_BASE`, `GITLAB_SECRETS_SECRET_KEY_BASE`, `GITLAB_SECRETS_OTP_KEY_BASE` - базовые значения для генерации ключей.
- `GITLAB_ROOT_EMAIL` - e-mail администратора.
- `GITLAB_ROOT_PASSWORD` - пароль администратора по умолчанию, который в дальнейшем возможно поменять из Web-интерфейса.
- `GITLAB_EMAIL`, `GITLAB_EMAIL_REPLY_TO`, `GITLAB_INCOMING_EMAIL_ADDRESS` - адреса для почтовых оповещений.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` - настройки SMTP для почтовых оповещений.
-  `IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`, `IMAP_PASS` - Gitlab может не только отправлять почту, но и забирать по IMAP. Ему возможно делать запросы по e-mail.


## Настройка LDAP

Для того, чтобы пользователи NAS могли входить в Gitlab, ему надо предоставить сервер LDAP, как провайдер авторизации.

Обратите внимание, что когда LDAP настроен, при входе в Gitlab будет две вкладки: LDAP и Standard.

Администратор сможет войти только на вкладке Standard, потому что он зарегистрирован локально, а пользователи только на вкладке LDAP.

Локальная регистрация администратора полезна на случай, если пропадёт связь с LDAP сервером.

[![Вход в Gitlab](images/c6ypeavhmm3okm_fwgzrpofdzi0.png)](images/c6ypeavhmm3okm_fwgzrpofdzi0.png)

Это легко делается установкой переменных в конфигурационном файле docker-compose:

- `LDAP_ENABLED=true` - включение LDAP авторизации.
- `LDAP_HOST=172.21.0.1` - адрес LDAP сервера.
- `LDAP_PORT=389` - порт.
- `LDAP_METHOD=plain` - метод доступа без шифрования, т.к. LDAP сервер внутри сети хоста. Также возможно использовать StartTLS.
- `LDAP_UID=uid` - поле UID пользователя. В случае OpenLDAP, в той конфигурации, которая была настроена, - это `uid`.
- `LDAP_BIND_DN=cn=admin,dc=nas,dc=nas` - пользователь и домен, под которыми Gitlab авторизуется на LDAP сервере.
- `LDAP_PASS=<LDAP_PASSWORD>` - пароль для пользователя LDAP, под которым Gitlab авторизуется на LDAP сервере.
- `LDAP_BLOCK_AUTO_CREATED_USERS=false` - пользователь LDAP появится в Gitlab после его первого захода. Если тут установлено `true`, он будет заблокирован. Разблокировать его сможет администратор.
- `LDAP_BASE=ou=users,dc=nas,dc=nas` - это базовый адрес, по которому находятся аккаунты пользователей.
- `LDAP_USER_FILTER=memberOf=cn=users_code,ou=groups,dc=nas,dc=nas` - фильтр. Тут указывается, что я хочу получать только членов группы `users_code`.
- `LDAP_ALLOW_USERNAME_OR_EMAIL_LOGIN=true` - разрешить пользователю заходить не только по UID, но и по e-mail.

Обратите внимание на параметр `LDAP_USER_FILTER`. В [предыдущей статье](https://habr.com/post/421279/) были введены группы пользователей в LDAP, и данный параметр разрешает доступ в Gitlab только пользователям, состоящим в группе `users_code`.


## Gitlab CI

Настройка CI подробно не раз описана в [статьях](https://habr.com/company/southbridge/blog/306596/) и [документации Gitlab](https://docs.gitlab.com/ee/ci/). Повторяться смысла нет.

Если очень кратко, всё что надо сделать:

- Зайти на страницу агентов сборки: https://git.NAS.cloudns.cc/admin/runners и скопировать:
  * Адрес (https://git.NAS.cloudns.cc/).
  * Токен.
- Зарегистрировать агент. Адрес и токен он попросит в процессе регистрации.

[![Токен и адрес](images/ueclgnlcl4qvgnqljidxr9hce2g.png)](images/ueclgnlcl4qvgnqljidxr9hce2g.png)

Регистрация производится следующей командной:

```
docker-compose  exec gitlab-runner /entrypoint register
```

Про то, какие бывают агенты в Gitlab, возможно почитать [в документации](https://docs.gitlab.com/runner/executors/README.html).

Docker Registry я не включал, потому что он мне не требуется. О том, что это такое и зачем нужно, читайте на [сайте Gitlab](https://about.gitlab.com/2016/05/23/gitlab-container-registry/).

Ниже под спойлером приведён конфигурационный файл для Gitlab, который также [доступен в репозитории](https://github.com/artiomn/NAS/tree/master/docker/services/gitlab).

<spoiler title="/tank0/docker/services/gitlab/docker-compose.yml">
```
# https://github.com/sameersbn/docker-gitlab

version: '2'

networks:
  gitlab:
  docker0:
    external:
      name: docker0

services:
  redis:
    restart: always
    image: sameersbn/redis:latest
    command:
      - --loglevel warning
    networks:
      - gitlab
    volumes:
      - /tank0/apps/gitlab/redis:/var/lib/redis:Z

  postgresql:
    restart: always
    image: sameersbn/postgresql:9.6-2
    volumes:
      - /tank0/apps/gitlab/postgresql:/var/lib/postgresql:Z
    networks:
      - gitlab
    environment:
      - DB_USER=gitlab
      - DB_PASS=<DB_PASSWORD>
      - DB_NAME=gitlabhq_production
      - DB_EXTENSION=pg_trgm

#  plantuml:
#    restart: always
#    image: plantuml/plantuml-server
#    image: plantuml/plantuml-server:jetty
#    ports:
#      - "127.0.0.1:9542:8080"
#    ports:
#      - "plantuml:8080:8080"
#    expose:
#      - 8080
#    networks:
#      - gitlab

  gitlab:
    restart: always
    image: sameersbn/gitlab:10.6.3
    depends_on:
      - redis
      - postgresql
    ports:
      - "11022:22"
    expose:
      - 443
      - 80
      - 22
    volumes:
      - /tank0/apps/repos:/home/git/data/repositories:Z
      - /tank0/apps/repos/system/backup:/home/git/data/backups:Z
      - /tank0/apps/repos/system/builds:/home/git/data/builds:Z
      - /tank0/apps/repos/system/lfs-objects:/home/git/data/shared/lfs-objects:Z
      - /tank0/apps/repos/system/public:/uploads/-/system:Z
      - /tank0/apps/gitlab/logs:/var/log/gitlab
      - /tank0/apps/gitlab/gitlab:/home/git/data:Z
    networks:
      - gitlab
      - docker0
    environment:
      - "VIRTUAL_HOST=git.*,gitlab.*"
      - VIRTUAL_PORT=443
      - VIRTUAL_PROTO=https
      - CERT_NAME=NAS.cloudns.cc
      - DEBUG=false

      # Default: 1
      - NGINX_WORKERS=2
      # Default: 3
      - UNICORN_WORKERS=3
      # Default: 25
      - SIDEKIQ_CONCURRENCY=10

      - DB_ADAPTER=postgresql
      - DB_HOST=postgresql
      - DB_PORT=5432
      - DB_USER=gitlab
      - DB_PASS=<DB_PASS>
      - DB_NAME=gitlabhq_production

      - REDIS_HOST=redis
      - REDIS_PORT=6379

      - TZ=Europe/Moscow
      - GITLAB_TIMEZONE=Moscow

      - GITLAB_HTTPS=true
      - SSL_SELF_SIGNED=true
      #- SSL_VERIFY_CLIENT=true
      - NGINX_HSTS_MAXAGE=2592000

      - GITLAB_HOST=git.NAS.cloudns.cc
      #- GITLAB_PORT=11443
      - GITLAB_SSH_PORT=11022
      - GITLAB_RELATIVE_URL_ROOT=
      - GITLAB_SECRETS_DB_KEY_BASE=<DB_KEY_BASE>
      - GITLAB_SECRETS_SECRET_KEY_BASE=<SC_KEY_BASE>
      - GITLAB_SECRETS_OTP_KEY_BASE=<OTP_KEY_BASE>

      - GITLAB_SIGNUP_ENABLED=false

      # Defaults to 5iveL!fe.
      - GITLAB_ROOT_PASSWORD=
      - GITLAB_ROOT_EMAIL=root@gmail.com

      - GITLAB_NOTIFY_ON_BROKEN_BUILDS=true
      - GITLAB_NOTIFY_PUSHER=false

      - GITLAB_EMAIL=GITLAB@yandex.ru
      - GITLAB_EMAIL_REPLY_TO=noreply@yandex.ru
      - GITLAB_INCOMING_EMAIL_ADDRESS=GITLAB@yandex.ru

      - GITLAB_BACKUP_SCHEDULE=daily
      - GITLAB_BACKUP_TIME=01:00

      - GITLAB_MATTERMOST_ENABLED=true
      - GITLAB_MATTERMOST_URL=""

      - SMTP_ENABLED=true
      - SMTP_DOMAIN=www.example.com
      - SMTP_HOST=smtp.yandex.ru
      - SMTP_PORT=25
      - SMTP_USER=GITLAB@yandex.ru
      - SMTP_PASS=<SMTP_PASSWORD>
      - SMTP_STARTTLS=true
      - SMTP_AUTHENTICATION=login

      - IMAP_ENABLED=true
      - IMAP_HOST=imap.yandex.ru
      - IMAP_PORT=993
      - IMAP_USER=GITLAB@yandex.ru
      - IMAP_PASS=<IMAP_PASSWORD>
      - IMAP_SSL=true
      - IMAP_STARTTLS=false

      - OAUTH_ENABLED=false
      - OAUTH_AUTO_SIGN_IN_WITH_PROVIDER=
      - OAUTH_ALLOW_SSO=
      - OAUTH_BLOCK_AUTO_CREATED_USERS=true
      - OAUTH_AUTO_LINK_LDAP_USER=false
      - OAUTH_AUTO_LINK_SAML_USER=false
      - OAUTH_EXTERNAL_PROVIDERS=

      - OAUTH_CAS3_LABEL=cas3
      - OAUTH_CAS3_SERVER=
      - OAUTH_CAS3_DISABLE_SSL_VERIFICATION=false
      - OAUTH_CAS3_LOGIN_URL=/cas/login
      - OAUTH_CAS3_VALIDATE_URL=/cas/p3/serviceValidate
      - OAUTH_CAS3_LOGOUT_URL=/cas/logout

      - OAUTH_GOOGLE_API_KEY=
      - OAUTH_GOOGLE_APP_SECRET=
      - OAUTH_GOOGLE_RESTRICT_DOMAIN=

      - OAUTH_FACEBOOK_API_KEY=
      - OAUTH_FACEBOOK_APP_SECRET=

      - OAUTH_TWITTER_API_KEY=
      - OAUTH_TWITTER_APP_SECRET=

      - OAUTH_GITHUB_API_KEY=
      - OAUTH_GITHUB_APP_SECRET=
      - OAUTH_GITHUB_URL=
      - OAUTH_GITHUB_VERIFY_SSL=

      - OAUTH_GITLAB_API_KEY=
      - OAUTH_GITLAB_APP_SECRET=

      - OAUTH_BITBUCKET_API_KEY=
      - OAUTH_BITBUCKET_APP_SECRET=

      - OAUTH_SAML_ASSERTION_CONSUMER_SERVICE_URL=
      - OAUTH_SAML_IDP_CERT_FINGERPRINT=
      - OAUTH_SAML_IDP_SSO_TARGET_URL=
      - OAUTH_SAML_ISSUER=
      - OAUTH_SAML_LABEL="Our SAML Provider"
      - OAUTH_SAML_NAME_IDENTIFIER_FORMAT=urn:oasis:names:tc:SAML:2.0:nameid-format:transient
      - OAUTH_SAML_GROUPS_ATTRIBUTE=
      - OAUTH_SAML_EXTERNAL_GROUPS=
      - OAUTH_SAML_ATTRIBUTE_STATEMENTS_EMAIL=
      - OAUTH_SAML_ATTRIBUTE_STATEMENTS_NAME=
      - OAUTH_SAML_ATTRIBUTE_STATEMENTS_FIRST_NAME=
      - OAUTH_SAML_ATTRIBUTE_STATEMENTS_LAST_NAME=

      - OAUTH_CROWD_SERVER_URL=
      - OAUTH_CROWD_APP_NAME=
      - OAUTH_CROWD_APP_PASSWORD=

      - OAUTH_AUTH0_CLIENT_ID=
      - OAUTH_AUTH0_CLIENT_SECRET=
      - OAUTH_AUTH0_DOMAIN=

      - OAUTH_AZURE_API_KEY=
      - OAUTH_AZURE_API_SECRET=
      - OAUTH_AZURE_TENANT_ID=

      - LDAP_ENABLED=true
      #- LDAP_LABEL=nas
      - LDAP_HOST=172.21.0.1
      - LDAP_PORT=389
      #- LDAP_METHOD=start_tls
      - LDAP_METHOD=plain
      - LDAP_UID=uid
      - LDAP_BIND_DN=cn=admin,dc=nas,dc=nas
      - LDAP_PASS=<LDAP_PASSWORD>
      #- LDAP_CA_FILE=
      # Default: false.
      #- LDAP_BLOCK_AUTO_CREATED_USERS=true
      - LDAP_BASE=ou=users,dc=nas,dc=nas
      - LDAP_ACTIVE_DIRECTORY=false
      #- LDAP_USER_FILTER=(givenName=)
      - LDAP_USER_FILTER=memberOf=cn=users_code,ou=groups,dc=nas,dc=nas
      - LDAP_ALLOW_USERNAME_OR_EMAIL_LOGIN=true

  gitlab-runner:
    container_name: gitlab-runner
    image: gitlab/gitlab-runner:latest
    networks:
      - gitlab
    volumes:
      - /tank0/apps/gitlab/gitlab-runner/data:/home/gitlab_ci_multi_runner/data
      - /tank0/apps/gitlab/gitlab-runner/config:/etc/gitlab-runner
    environment:
      - CI_SERVER_URL=https://gitlab.NAS.cloudns.cc
    restart: always

#  registry:
#    container_name: docker-registry
#    restart: always
#    image: registry:2.4.1
#    volumes:
#    - /srv/gitlab/shared/registry:/registry
#    - /srv/certs:/certs
#    environment:
#    - REGISTRY_LOG_LEVEL=info
#    - REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/registry
#    - REGISTRY_AUTH_TOKEN_REALM=http://git.labs.lc:10080/jwt/auth
#    - REGISTRY_AUTH_TOKEN_SERVICE=container_registry
#    - REGISTRY_AUTH_TOKEN_ISSUER=gitlab-issuer
#    - REGISTRY_AUTH_TOKEN_ROOTCERTBUNDLE=/certs/registry-auth.crt
#    - REGISTRY_STORAGE_DELETE_ENABLED=true
#    - REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt
#    - REGISTRY_HTTP_TLS_KEY=/certs/registry.key
#    ports:
#    - "0.0.0.0:5000:5000"
#    networks:
#     mynet:
#      aliases:
#      - registry.git.labs.lc
#
```
</spoiler>
