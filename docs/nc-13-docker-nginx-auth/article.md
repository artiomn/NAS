# Docker и аутентификация через Nginx

![](https://habrastorage.org/webt/er/pm/ew/erpmewjegcpdjjgb6aobbkf3yda.jpeg)

Одна из досадных проблем, которые встают при создании NAS, заключается в том, что не всякое программное обеспечение может работать с LDAP, а [некоторое](https://github.com/d0u9/youtube-dl-webui) вообще не содержит механизмов аутентификации.

<cut/>

Решением является сквозная аутентификация через обратный прокси.
Пример того, как это сделать, весьма подробно разобран, например в [этой статье](https://www.tune-it.ru/web/asddsa1137/home/-/blogs/%D0%BE%D0%B3%D1%80%D0%B0%D0%BD%D0%B8%D0%B7%D0%B0%D1%86%D0%B8%D1%8F-%D1%80%D0%B0%D0%B7%D0%B3%D1%80%D0%B0%D0%BD%D0%B8%D1%87%D0%B5%D0%BD%D0%B8%D1%8F-%D0%B4%D0%BE%D1%81%D1%82%D1%83%D0%BF%D0%B0-%D0%BA-web-%D1%80%D0%B5%D1%81%D1%83%D1%80%D1%81%D1%83-%D1%87%D0%B5%D1%80%D0%B5%D0%B7-ldap-%D0%B2-nginx).

Поскольку данная статья является частью [NAS цикла](https://habr.com/ru/post/359346/),
здесь я остановлюсь на том, как приспособить данное решение к сервисам в Docker-контейнерах.

Решение основывается на примере реализации аутентификации через внешнего агента [Nginx LDAP Auth](https://github.com/nginxinc/nginx-ldap-auth), но я использую [контейнеризованный вариант от LinuxServer.io](https://github.com/linuxserver/docker-ldap-auth) потому, что это готовый образ, соответствующий определённым стандартам.

Единственная проблема заключалась в том, что патчи LinuxServer.io сломали базовую HTTP аутентификацию, но после того, как влили [багфикс](https://github.com/linuxserver/docker-ldap-auth/pull/18), пользоваться этим стало опять возможно.


## Аутентификация в общем случае

Как показано в статьях, аутентификация производится по следующей схеме:

- Клиент обращается к сервису.
- Обратный прокси делает перенаправление, если установлен cookie.
- Если cookie нет, делается запрос к сервису аутентификации.
- Сервис аутентификации запрашивает логин и пароль, которые проверяет через обращение к LDAP серверу.
- Если проверка успешна, он устанавливает cookie и выполняет перенаправление на сервис.

![Схема аутентификации](https://habrastorage.org/webt/n_/e_/7j/n_e_7jmjle2qbyc35vfpv_0p7e4.jpeg)

Альтернативным вариантом может являться использование компилируемого модуля для nginx, но я данный вариант здесь не рассматриваю с силу некоторых проблем с данным модулем и меньшей его гибкости.

Доработанный образ для OpenLDAP сервера есть [здесь](https://github.com/artiomn/nginx-proxy-ldap).


## Аутентификация контейнеров

В рамках NAS, сервисы работают в контейнерах, поэтому есть желание сделать так, чтобы возможно было переключать режимы аутентификации, просто установив переменные внутри контейнера.

Такой механизм уже есть в используемом [образе ngingx-proxy](https://github.com/jwilder/nginx-proxy) и реализован он через шаблоны, которые обрабатывает [docker-gen](https://github.com/jwilder/docker-gen).

Он подставляет в шаблон метаданные, которые содержат описание запущенных в данный момент контейнеров Docker.

Таким образом, всё что надо сделать - это доработать шаблон конфигурации обратного прокси так, чтобы при наличии условной переменной в контейнере, было включено перенаправление на сервис сквозной аутентификации, который также работает в контейнере.

Затем, внести соответствующие коррективы в конфигурацию docker-compose.


## Реализация аутентификации

### Модификация шаблона конфигурации nginx-proxy

В первую очередь добавляется новый upstream, который позволяет обращаться к сервису аутентификации в конфиге:

```nginx
proxy_cache_path cache/  keys_zone=auth_cache:10m;

upstream ldap-backend {
        server {{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_LOGIN_PORT "9000" }};
}
```

Видно, что сервис аутентификации работает на хосте `${LDAP_BACKEND}` и порту `${LDAP_LOGIN_PORT }`, по умолчанию 9000.
Значения переменных будут подставлены docker-gen так, что данная часть конфига будет выглядеть следующим образом в `/etc/nginx/conf.d/default.conf` внутри контейнера:

```nginx
### LDAP                                                                                                                  
proxy_cache_path cache/  keys_zone=auth_cache:10m;                              
upstream ldap-backend {                                                                                                                                                                                                
        server ldap-auth:9000;                                                                                                                                                                                         
}                                                                                                                                                                                                                      
###
```

Следующее дополнение устанавливает переменную `ext_ldap_auth`, если в контейнере некоего сервиса была взведена переменная `LDAP_EXT_AUTH`.
Также, устанавливаются ещё несколько переменных для настройки аутентификации.

```nginx
{{/* Nginx LDAP authentication enabled */}}
{{ $ext_ldap_auth := parseBool (or (first (groupByKeys $containers "Env.LDAP_EXT_AUTH")) "false") }}

{{/* User need to be participated in these groups to use service */}}
{{ $ldap_add_groups := or (first (groupByKeys $containers "Env.LDAP_EXT_ADD_GROUPS")) "" }}

{{/* Use HTML login page or HTTP Basic authentication */}}
{{ $ldap_use_login_page := parseBool (or $.Env.LDAP_USE_LOGIN_PAGE "false" ) }}
```

Основной блок дополнений приведён ниже. Он активируется, только если установлена переменная `ext_ldap_auth`.
Если `ldap_use_login_page` установлена, то будет включено перенаправление на страницу аутентификации, иначе будет использовано окно базовой аутентификации HTTP.

Путь `/auth-proxy` - это и есть перенаправление на сервис аутентификации.
Параметры будут переданы через заголовки HTTP.
Какие параметры и для чего нужны, вполне подробно описано в комментариях.

<spoiler title="LDAP секция">
```nginx
        {{ if ($ext_ldap_auth) }}
        ### LDAP

        {{ if ($ldap_use_login_page) }}
        location /login-ldap {
	        proxy_pass http://{{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_LOGIN_PORT "9000" }};
                # Login service returns a redirect to the original URI
                # and sets the cookie for the ldap-auth daemon
                proxy_set_header X-Target $request_uri;

                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_cache auth_cache;
                proxy_cache_valid 200 10m;

                proxy_cache_key "$http_authorization$cookie_nginxauth";

                proxy_set_header X-CookieName "nginxauth";
                proxy_set_header Cookie nginxauth=$cookie_nginxauth;
        }
        {{ end }}

	location = /auth-proxy {
		internal;

                # The ldap-auth daemon listens on port $LDAP_BACKEND_PORT (8888, by default), as set
                # in nginx-ldap-auth-daemon.py.
                # Change the IP address if the daemon is not running on
                # the same host as NGINX/NGINX Plus.
                proxy_pass http://{{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_BACKEND_PORT "8888" }};

                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_cache auth_cache;
                proxy_cache_valid 200 10m;

                # The following directive adds the cookie to the cache key
                proxy_cache_key "$http_authorization$cookie_nginxauth";

                # As implemented in nginx-ldap-auth-daemon.py, the ldap-auth daemon
                # communicates with a LDAP server, passing in the following
                # parameters to specify which user account to authenticate. To
                # eliminate the need to modify the Python code, this file contains
                # 'proxy_set_header' directives that set the values of the
                # parameters. Set or change them as instructed in the comments.
                #
                #    Parameter      Proxy header
                #    -----------    ----------------
                #    url            X-Ldap-URL
                #    starttls       X-Ldap-Starttls
                #    basedn         X-Ldap-BaseDN
                #    binddn         X-Ldap-BindDN
                #    bindpasswd     X-Ldap-BindPass
                #    cookiename     X-CookieName
                #    realm          X-Ldap-Realm
                #    template       X-Ldap-Template

                # (Required) Set the URL and port for connecting to the LDAP server,
                # by replacing 'example.com'.
                # Do not mix ldaps-style URL and X-Ldap-Starttls as it will not work.
                proxy_set_header X-Ldap-URL      "{{ $.Env.LDAP_HOST }}";

                # (Optional) Establish a TLS-enabled LDAP session after binding to the
                # LDAP server.
                # This is the 'proper' way to establish encrypted TLS connections, see
                # http://www.openldap.org/faq/data/cache/185.html
                {{ if eq ("$.Env.LDAP_METHOD") "start_tls" }}
                proxy_set_header X-Ldap-Starttls "true";
                {{ end }}

                # (Required) Set the Base DN, by replacing the value enclosed in
                # double quotes.
                proxy_set_header X-Ldap-BaseDN   "{{ $.Env.LDAP_BASE }}";

                # (Required) Set the Bind DN, by replacing the value enclosed in
                # double quotes.
                proxy_set_header X-Ldap-BindDN   "{{ $.Env.LDAP_BIND_DN }}";

                # (Required) Set the Bind password, by replacing 'secret'.
                proxy_set_header X-Ldap-BindPass "{{ $.Env.LDAP_PASS }}";

                # (Required) The following directives set the cookie name and pass
                # it, respectively. They are required for cookie-based
                # authentication. Comment them out if using HTTP basic
                # authentication.
                proxy_set_header X-CookieName "nginxauth";
                proxy_set_header Cookie nginxauth=$cookie_nginxauth;

                # (Required if using Microsoft Active Directory as the LDAP server)
                # Set the LDAP template by uncommenting the following directive.
                #proxy_set_header X-Ldap-Template "(sAMAccountName=%(username)s)";

                # (May be required if using Microsoft Active Directory and
                # getting "In order to perform this operation a successful bind
                # must be completed on the connection." errror)
                #proxy_set_header X-Ldap-DisableReferrals "true";

                # (Optional if using OpenLDAP as the LDAP server) Set the LDAP
                # template by uncommenting the following directive and replacing
                # '(cn=%(username)s)' which is the default set in
                # nginx-ldap-auth-daemon.py.
                {{ $ldap_filter := $.Env.LDAP_USER_FILTER }}
                {{ $ldap_filter := (printf "(&%s%s)" $ldap_filter $ldap_add_groups) }}

                proxy_set_header X-Ldap-Template "{{ $ldap_filter }}";

                # (Optional) Set the realm name, by uncommenting the following
                # directive and replacing 'Restricted' which is the default set
                # in nginx-ldap-auth-daemon.py.
                #proxy_set_header X-Ldap-Realm    "Restricted";
        }
        ### /LDAP
        {{ end }}
```
</spoiler>

И последнее, когда LDAP аутентификация для сервиса включена, добавляется `auth_request` в его location:

```nginx
	location / {
                {{ if ($ext_ldap_auth) }}
		auth_request /auth-proxy;

		{{ if ($ldap_use_login_page) }}
		# redirect 401 to login form
		# Comment them out if using HTTP basic authentication.
		# or authentication popup won't show
		error_page 401 =200 /login-ldap;
		{{ end }}
		{{ end }}

```

Ниже приведён полный листинг шаблона.

<spoiler title="nginx.tmpl">
```nginx
{{ $CurrentContainer := where $ "ID" .Docker.CurrentContainerID | first }}

{{ define "upstream" }}
	{{ if .Address }}
		{{/* If we got the containers from swarm and this container's port is published to host, use host IP:PORT */}}
		{{ if and .Container.Node.ID .Address.HostPort }}
			# {{ .Container.Node.Name }}/{{ .Container.Name }}
			server {{ .Container.Node.Address.IP }}:{{ .Address.HostPort }};
		{{/* If there is no swarm node or the port is not published on host, use container's IP:PORT */}}
		{{ else if .Network }}
			# {{ .Container.Name }}
			server {{ .Network.IP }}:{{ .Address.Port }};
		{{ end }}
	{{ else if .Network }}
		# {{ .Container.Name }}
		{{ if .Network.IP }}
			server {{ .Network.IP }} down;
		{{ else }}
			server 127.0.0.1 down;
		{{ end }}
	{{ end }}
	
{{ end }}

# If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
# scheme used to connect to this server
map $http_x_forwarded_proto $proxy_x_forwarded_proto {
  default $http_x_forwarded_proto;
  ''      $scheme;
}

# If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
# server port the client connected to
map $http_x_forwarded_port $proxy_x_forwarded_port {
  default $http_x_forwarded_port;
  ''      $server_port;
}

# If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
# Connection header that may have been passed to this server
map $http_upgrade $proxy_connection {
  default upgrade;
  '' close;
}

# Apply fix for very long server names
server_names_hash_bucket_size 128;

# Default dhparam
{{ if (exists "/etc/nginx/certs/dhparam.pem") }}
ssl_dhparam /etc/nginx/certs/dhparam.pem;
{{ end }}

# Set appropriate X-Forwarded-Ssl header
map $scheme $proxy_x_forwarded_ssl {
  default off;
  https on;
}

gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;

log_format vhost '$host $remote_addr - $remote_user [$time_local] '
                 '"$request" $status $body_bytes_sent '
                 '"$http_referer" "$http_user_agent"';

access_log off;

{{ if $.Env.RESOLVERS }}
resolver {{ $.Env.RESOLVERS }};
{{ end }}

{{ if (exists "/etc/nginx/proxy.conf") }}
include /etc/nginx/proxy.conf;
{{ else }}
# HTTP 1.1 support
proxy_http_version 1.1;
proxy_buffering off;
proxy_set_header Host $http_host;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $proxy_connection;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;

# Allow iframing.
proxy_hide_header X-Frame-Options;

# Mitigate httpoxy attack (see README for details)
proxy_set_header Proxy "";
{{ end }}

### LDAP

proxy_cache_path cache/  keys_zone=auth_cache:10m;

upstream ldap-backend {
        server {{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_LOGIN_PORT "9000" }};
}

###

{{ $enable_ipv6 := eq (or ($.Env.ENABLE_IPV6) "") "true" }}
server {
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 80;
	{{ if $enable_ipv6 }}
	listen [::]:80;
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 503;
}

{{ if (and (exists "/etc/nginx/certs/default.crt") (exists "/etc/nginx/certs/default.key")) }}
server {
	server_name _; # This is just an invalid value which will never trigger on a real hostname.
	listen 443 ssl http2;
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2;
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 503;

	ssl_session_tickets off;
	ssl_certificate /etc/nginx/certs/default.crt;
	ssl_certificate_key /etc/nginx/certs/default.key;
}
{{ end }}

{{ range $host, $containers := groupByMulti $ "Env.VIRTUAL_HOST" "," }}

{{ $host := trim $host }}
{{ $is_regexp := hasPrefix "~" $host }}
{{ $upstream_name := when $is_regexp (sha1 $host) $host }}

# {{ $host }}
upstream {{ $upstream_name }} {

{{ range $container := $containers }}
	{{ $addrLen := len $container.Addresses }}

	{{ range $knownNetwork := $CurrentContainer.Networks }}
		{{ range $containerNetwork := $container.Networks }}
			{{ if (and (ne $containerNetwork.Name "ingress") (or (eq $knownNetwork.Name $containerNetwork.Name) (eq $knownNetwork.Name "host"))) }}
				## Can be connected with "{{ $containerNetwork.Name }}" network

				{{/* If only 1 port exposed, use that */}}
				{{ if eq $addrLen 1 }}
					{{ $address := index $container.Addresses 0 }}
					{{ template "upstream" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
				{{/* If more than one port exposed, use the one matching VIRTUAL_PORT env var, falling back to standard web port 80 */}}
				{{ else }}
					{{ $port := coalesce $container.Env.VIRTUAL_PORT "80" }}
					{{ $address := where $container.Addresses "Port" $port | first }}
					{{ template "upstream" (dict "Container" $container "Address" $address "Network" $containerNetwork) }}
				{{ end }}
			{{ else }}
				# Cannot connect to network of this container
				server 127.0.0.1 down;
			{{ end }}
		{{ end }}
	{{ end }}
{{ end }}
}

{{ $default_host := or ($.Env.DEFAULT_HOST) "" }}
{{ $default_server := index (dict $host "" $default_host "default_server") $host }}

{{/* Get the VIRTUAL_PROTO defined by containers w/ the same vhost, falling back to "http" */}}
{{ $proto := trim (or (first (groupByKeys $containers "Env.VIRTUAL_PROTO")) "http") }}

{{/* Get the NETWORK_ACCESS defined by containers w/ the same vhost, falling back to "external" */}}
{{ $network_tag := or (first (groupByKeys $containers "Env.NETWORK_ACCESS")) "external" }}

{{/* Get the HTTPS_METHOD defined by containers w/ the same vhost, falling back to "redirect" */}}
{{ $https_method := or (first (groupByKeys $containers "Env.HTTPS_METHOD")) "redirect" }}

{{/* Get the SSL_POLICY defined by containers w/ the same vhost, falling back to "Mozilla-Intermediate" */}}
{{ $ssl_policy := or (first (groupByKeys $containers "Env.SSL_POLICY")) "Mozilla-Intermediate" }}

{{/* Get the HSTS defined by containers w/ the same vhost, falling back to "max-age=31536000" */}}
{{ $hsts := or (first (groupByKeys $containers "Env.HSTS")) "max-age=31536000" }}

{{/* Get the VIRTUAL_ROOT By containers w/ use fastcgi root */}}
{{ $vhost_root := or (first (groupByKeys $containers "Env.VIRTUAL_ROOT")) "/var/www/public" }}

{{/* Nginx LDAP authentication enabled */}}
{{ $ext_ldap_auth := parseBool (or (first (groupByKeys $containers "Env.LDAP_EXT_AUTH")) "false") }}

{{/* User need to be participated in these groups to use service */}}
{{ $ldap_add_groups := or (first (groupByKeys $containers "Env.LDAP_EXT_ADD_GROUPS")) "" }}

{{/* Use HTML login page or HTTP Basic authentication */}}
{{ $ldap_use_login_page := parseBool (or $.Env.LDAP_USE_LOGIN_PAGE "false" ) }}

{{/* Get the first cert name defined by containers w/ the same vhost */}}
{{ $certName := (first (groupByKeys $containers "Env.CERT_NAME")) }}

{{/* Get the best matching cert  by name for the vhost. */}}
{{ $vhostCert := (closest (dir "/etc/nginx/certs") (printf "%s.crt" $host))}}

{{/* vhostCert is actually a filename so remove any suffixes since they are added later */}}
{{ $vhostCert := trimSuffix ".crt" $vhostCert }}
{{ $vhostCert := trimSuffix ".key" $vhostCert }}

{{/* Use the cert specified on the container or fallback to the best vhost match */}}
{{ $cert := (coalesce $certName $vhostCert) }}

{{ $is_https := (and (ne $https_method "nohttps") (ne $cert "") (or (and (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/fullchain.pem" $cert)) (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/privkey.pem" $cert))) (and (exists (printf "/etc/nginx/certs/%s.crt" $cert)) (exists (printf "/etc/nginx/certs/%s.key" $cert)))) ) }}

{{ if $is_https }}

{{ if eq $https_method "redirect" }}
server {
	server_name {{ $host }};
	listen 80 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:80 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;

	return 301 https://$host$request_uri;
}
{{ end }}

server {
	server_name {{ $host }};
	listen 443 ssl http2 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;

	{{ if eq $network_tag "internal" }}
	# Only allow traffic from internal clients
	include /etc/nginx/network_internal.conf;
	{{ end }}

	{{ if eq $ssl_policy "Mozilla-Modern" }}
	ssl_protocols TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
	{{ else if eq $ssl_policy "Mozilla-Intermediate" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:!DSS';
	{{ else if eq $ssl_policy "Mozilla-Old" }}
	ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:ECDHE-RSA-DES-CBC3-SHA:ECDHE-ECDSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:DES-CBC3-SHA:HIGH:SEED:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!RSAPSK:!aDH:!aECDH:!EDH-DSS-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA:!SRP';
	{{ else if eq $ssl_policy "AWS-TLS-1-2-2017-01" }}
	ssl_protocols TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:AES128-GCM-SHA256:AES128-SHA256:AES256-GCM-SHA384:AES256-SHA256';
	{{ else if eq $ssl_policy "AWS-TLS-1-1-2017-01" }}
	ssl_protocols TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';
	{{ else if eq $ssl_policy "AWS-2016-08" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA';
	{{ else if eq $ssl_policy "AWS-2015-05" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DES-CBC3-SHA';
	{{ else if eq $ssl_policy "AWS-2015-03" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA:DES-CBC3-SHA';
	{{ else if eq $ssl_policy "AWS-2015-02" }}
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:AES128-GCM-SHA256:AES128-SHA256:AES128-SHA:AES256-GCM-SHA384:AES256-SHA256:AES256-SHA:DHE-DSS-AES128-SHA';
	{{ end }}

	ssl_prefer_server_ciphers on;
	ssl_session_timeout 5m;
	ssl_session_cache shared:SSL:50m;
	ssl_session_tickets off;

        {{ if (and (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/fullchain.pem" $cert)) (exists (printf "/etc/nginx/certs/letsencrypt/live/%s/privkey.pem" $cert))) }}
	ssl_certificate /etc/nginx/certs/letsencrypt/live/{{ (printf "%s/fullchain.pem" $cert) }};
	ssl_certificate_key /etc/nginx/certs/letsencrypt/live/{{ (printf "%s/privkey.pem" $cert) }};
        {{ else if (and (exists (printf "/etc/nginx/certs/%s.crt" $cert)) (exists (printf "/etc/nginx/certs/%s.key" $cert))) }}
	ssl_certificate /etc/nginx/certs/{{ (printf "%s.crt" $cert) }};
	ssl_certificate_key /etc/nginx/certs/{{ (printf "%s.key" $cert) }};
	{{ end }}

	{{ if (exists (printf "/etc/nginx/certs/%s.dhparam.pem" $cert)) }}
	ssl_dhparam {{ printf "/etc/nginx/certs/%s.dhparam.pem" $cert }};
	{{ end }}

	{{ if (exists (printf "/etc/nginx/certs/%s.chain.pem" $cert)) }}
	ssl_stapling on;
	ssl_stapling_verify on;
	ssl_trusted_certificate {{ printf "/etc/nginx/certs/%s.chain.pem" $cert }};
	{{ end }}

	{{ if (and (ne $https_method "noredirect") (ne $hsts "off")) }}
	add_header Strict-Transport-Security "{{ trim $hsts }}" always;
	{{ end }}

	{{ if (exists (printf "/etc/nginx/vhost.d/%s" $host)) }}
	include {{ printf "/etc/nginx/vhost.d/%s" $host }};
	{{ else if (exists "/etc/nginx/vhost.d/default") }}
	include /etc/nginx/vhost.d/default;
	{{ end }}

        {{ if ($ext_ldap_auth) }}
        ### LDAP

        {{ if ($ldap_use_login_page) }}
        location /login-ldap {
	        proxy_pass http://{{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_LOGIN_PORT "9000" }};
                # Login service returns a redirect to the original URI
                # and sets the cookie for the ldap-auth daemon
                proxy_set_header X-Target $request_uri;

                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_cache auth_cache;
                proxy_cache_valid 200 10m;

                proxy_cache_key "$http_authorization$cookie_nginxauth";

                proxy_set_header X-CookieName "nginxauth";
                proxy_set_header Cookie nginxauth=$cookie_nginxauth;
        }
        {{ end }}

	location = /auth-proxy {
		internal;

                # The ldap-auth daemon listens on port $LDAP_BACKEND_PORT (8888, by default), as set
                # in nginx-ldap-auth-daemon.py.
                # Change the IP address if the daemon is not running on
                # the same host as NGINX/NGINX Plus.
                proxy_pass http://{{ $.Env.LDAP_BACKEND }}:{{ or $.Env.LDAP_BACKEND_PORT "8888" }};

                proxy_pass_request_body off;
                proxy_set_header Content-Length "";
                proxy_cache auth_cache;
                proxy_cache_valid 200 10m;

                # The following directive adds the cookie to the cache key
                proxy_cache_key "$http_authorization$cookie_nginxauth";

                # As implemented in nginx-ldap-auth-daemon.py, the ldap-auth daemon
                # communicates with a LDAP server, passing in the following
                # parameters to specify which user account to authenticate. To
                # eliminate the need to modify the Python code, this file contains
                # 'proxy_set_header' directives that set the values of the
                # parameters. Set or change them as instructed in the comments.
                #
                #    Parameter      Proxy header
                #    -----------    ----------------
                #    url            X-Ldap-URL
                #    starttls       X-Ldap-Starttls
                #    basedn         X-Ldap-BaseDN
                #    binddn         X-Ldap-BindDN
                #    bindpasswd     X-Ldap-BindPass
                #    cookiename     X-CookieName
                #    realm          X-Ldap-Realm
                #    template       X-Ldap-Template

                # (Required) Set the URL and port for connecting to the LDAP server,
                # by replacing 'example.com'.
                # Do not mix ldaps-style URL and X-Ldap-Starttls as it will not work.
                proxy_set_header X-Ldap-URL      "{{ $.Env.LDAP_HOST }}";

                # (Optional) Establish a TLS-enabled LDAP session after binding to the
                # LDAP server.
                # This is the 'proper' way to establish encrypted TLS connections, see
                # http://www.openldap.org/faq/data/cache/185.html
                {{ if eq ("$.Env.LDAP_METHOD") "start_tls" }}
                proxy_set_header X-Ldap-Starttls "true";
                {{ end }}

                # (Required) Set the Base DN, by replacing the value enclosed in
                # double quotes.
                proxy_set_header X-Ldap-BaseDN   "{{ $.Env.LDAP_BASE }}";

                # (Required) Set the Bind DN, by replacing the value enclosed in
                # double quotes.
                proxy_set_header X-Ldap-BindDN   "{{ $.Env.LDAP_BIND_DN }}";

                # (Required) Set the Bind password, by replacing 'secret'.
                proxy_set_header X-Ldap-BindPass "{{ $.Env.LDAP_PASS }}";

                # (Required) The following directives set the cookie name and pass
                # it, respectively. They are required for cookie-based
                # authentication. Comment them out if using HTTP basic
                # authentication.
                proxy_set_header X-CookieName "nginxauth";
                proxy_set_header Cookie nginxauth=$cookie_nginxauth;

                # (Required if using Microsoft Active Directory as the LDAP server)
                # Set the LDAP template by uncommenting the following directive.
                #proxy_set_header X-Ldap-Template "(sAMAccountName=%(username)s)";

                # (May be required if using Microsoft Active Directory and
                # getting "In order to perform this operation a successful bind
                # must be completed on the connection." errror)
                #proxy_set_header X-Ldap-DisableReferrals "true";

                # (Optional if using OpenLDAP as the LDAP server) Set the LDAP
                # template by uncommenting the following directive and replacing
                # '(cn=%(username)s)' which is the default set in
                # nginx-ldap-auth-daemon.py.
                {{ $ldap_filter := $.Env.LDAP_USER_FILTER }}
                {{ $ldap_filter := (printf "(&%s%s)" $ldap_filter $ldap_add_groups) }}

                proxy_set_header X-Ldap-Template "{{ $ldap_filter }}";

                # (Optional) Set the realm name, by uncommenting the following
                # directive and replacing 'Restricted' which is the default set
                # in nginx-ldap-auth-daemon.py.
                #proxy_set_header X-Ldap-Realm    "Restricted";
        }
        ### /LDAP
        {{ end }}

	location / {
                {{ if ($ext_ldap_auth) }}
		auth_request /auth-proxy;

		{{ if ($ldap_use_login_page) }}
		# redirect 401 to login form
		# Comment them out if using HTTP basic authentication.
		# or authentication popup won't show
		error_page 401 =200 /login-ldap;
		{{ end }}
		{{ end }}

		{{ if eq $proto "uwsgi" }}
		include uwsgi_params;
		uwsgi_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ else if eq $proto "fastcgi" }}
		root   {{ trim $vhost_root }};
		include fastcgi.conf;
		fastcgi_pass {{ trim $upstream_name }};
		{{ else }}
		proxy_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ end }}

		{{ if (exists (printf "/etc/nginx/htpasswd/%s" $host)) }}
		auth_basic	"Restricted {{ $host }}";
		auth_basic_user_file	{{ (printf "/etc/nginx/htpasswd/%s" $host) }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/vhost.d/%s_location" $host)) }}
		include {{ printf "/etc/nginx/vhost.d/%s_location" $host}};
		{{ else if (exists "/etc/nginx/vhost.d/default_location") }}
		include /etc/nginx/vhost.d/default_location;
		{{ end }}
	}
}

{{ end }}

{{ if or (not $is_https) (eq $https_method "noredirect") }}

server {
	server_name {{ $host }};
	listen 80 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:80 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;

	{{ if eq $network_tag "internal" }}
	# Only allow traffic from internal clients
	include /etc/nginx/network_internal.conf;
	{{ end }}

	{{ if (exists (printf "/etc/nginx/vhost.d/%s" $host)) }}
	include {{ printf "/etc/nginx/vhost.d/%s" $host }};
	{{ else if (exists "/etc/nginx/vhost.d/default") }}
	include /etc/nginx/vhost.d/default;
	{{ end }}

	location / {
		{{ if eq $proto "uwsgi" }}
		include uwsgi_params;
		uwsgi_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ else if eq $proto "fastcgi" }}
		root   {{ trim $vhost_root }};
		include fastcgi.conf;
		fastcgi_pass {{ trim $upstream_name }};
		{{ else }}
		proxy_pass {{ trim $proto }}://{{ trim $upstream_name }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/htpasswd/%s" $host)) }}
		auth_basic	"Restricted {{ $host }}";
		auth_basic_user_file	{{ (printf "/etc/nginx/htpasswd/%s" $host) }};
		{{ end }}
		{{ if (exists (printf "/etc/nginx/vhost.d/%s_location" $host)) }}
		include {{ printf "/etc/nginx/vhost.d/%s_location" $host}};
		{{ else if (exists "/etc/nginx/vhost.d/default_location") }}
		include /etc/nginx/vhost.d/default_location;
		{{ end }}
	}
}

{{ if (and (not $is_https) (exists "/etc/nginx/certs/default.crt") (exists "/etc/nginx/certs/default.key")) }}
server {
	server_name {{ $host }};
	listen 443 ssl http2 {{ $default_server }};
	{{ if $enable_ipv6 }}
	listen [::]:443 ssl http2 {{ $default_server }};
	{{ end }}
	access_log /var/log/nginx/access.log vhost;
	return 500;

	ssl_certificate /etc/nginx/certs/default.crt;
	ssl_certificate_key /etc/nginx/certs/default.key;
}
{{ end }}

{{ end }}
{{ end }}
```
</spoiler>

### Модификация конфигурации docker-compose

В `docker-compose.yml` были добавлены:

- Новый сервис "ldap-auth", который отвечает за авторизацию.
- Блок переменных, настраивающих взаимодействия с LDAP сервером.

То что записано в переменных, nginx передаст сервису аутентификации через HTTP заголовки.
Назначение параметров ясно из названий переменных, так что останавливаться я на них не буду.
Полный конфиг смотрите ниже.

<spoiler title="docker-compose.yml">
```yml
version: '2'

networks:
  internal:
  docker0:
    external:
      name: docker0

services:
  ldap-auth:
    image: linuxserver/ldap-auth:latest
    container_name: ldap-auth
    networks:
      - internal
      - docker0
    environment:
      - TZ=Europe/Moscow
    expose:
      - 8888
      - 9000
    restart: unless-stopped

  nginx-proxy:
    depends_on:
      - ldap-auth
    networks:
      - internal
      - docker0
    restart: always
    image: jwilder/nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./certs:/etc/nginx/certs:ro
      - ./vhost.d:/etc/nginx/vhost.d
      - ./html:/usr/share/nginx/html
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./local-config:/etc/nginx/conf.d
      - ./nginx.tmpl:/app/nginx.tmpl
    environment:
      - DEFAULT_HOST=nas.nas
      - LDAP_BACKEND=ldap-auth
      #- LDAP_BACKEND_PORT=8888
      #- LDAP_LOGIN_PORT=9000
      - LDAP_HOST=ldap://172.21.0.1:389
      #- LDAP_METHOD=start_tls
      - LDAP_METHOD=plain
      - LDAP_UID=uid
      - LDAP_PASS=LDAP_PASSWORD
      - LDAP_BASE=ou=users,dc=nas,dc=nas
      - LDAP_BIND_DN=cn=readonly,dc=nas,dc=nas
      - LDAP_USER_FILTER=(uid=%(username)s)
      #- LDAP_USE_LOGIN_PAGE=true

    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy=true"

  letsencrypt-dns:
    image: adferrand/letsencrypt-dns
    restart: always
    volumes:
      - ./certs/letsencrypt:/etc/letsencrypt
    environment:
      - "LETSENCRYPT_USER_MAIL=MAIL@MAIL.COM"
      - "LEXICON_PROVIDER=cloudns"
      - "LEXICON_OPTIONS=--delegated NAS.cloudns.cc"
      - "LEXICON_PROVIDER_OPTIONS=--auth-id=CLOUDNS_ID --auth-password=CLOUDNS_PASSWORD"
```
</spoiler>


## Использование сервисом

Сквозная аутентификация по умолчанию выключена.
Для её включения достаточно установить в окружении нужного контейнера переменные:

- `LDAP_EXT_AUTH=true` - включение аутентификации.
- `LDAP_EXT_ADD_GROUPS=(memberOf=cn=users_cloud,ou=groups,dc=nas,dc=nas)` - необязательный фильтр, список групп, в которые обязательно должен входить пользователь, чтобы быть аутентифицированным. Таким образом обеспечивается поддержка авторизации.

```yml
   environment:
      - LDAP_EXT_AUTH=true
      - LDAP_EXT_ADD_GROUPS=(memberOf=cn=users_cloud,ou=groups,dc=nas,dc=nas)
```

## Заключение

В целом, решение уже длительное время работает и обеспечивает не только аутентификацию, но и авторизацию.
Что позволяет использовать в NAS любые сервисы в контейнерах, независимо от того поддерживают ли они аутентификацию через LDAP.

Хотя имеются некоторые проблемы:

- Безопаснее и удобнее для пользователя производить аутентификации через HTML страницу, включив переменную `ldap_use_login_page`. Но этот вариант у меня не заработал. Будет время - разберусь.
- Неудобно задавать список групп. Я вынужден был делать LDAP фильтр, а не список, поскольку ограничения docker-gen не позволяют мне сформировать нужную строку.
- Сервисы независимы, каждый сервис является отдельным поддоменом. И приходится вводить логин и пароль каждый раз, когда производится доступ на сервис, в котором ещё не была произведена аутентификация, что раздражает. В будущем возможно сделаю единый центр аутентификации.

Конфигурацию NAS вы можете найти в [репозитории](https://github.com/artiomn/NAS).
