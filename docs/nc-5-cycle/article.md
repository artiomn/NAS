# Цикл статей: построение защищённого NAS, либо домашнего мини-сервера

![](https://habrastorage.org/webt/5s/np/2a/5snp2asrc-dlhjefcfawsaurfqo.png)

**Статьи цикла**:

0. [**Обзор материалов и литературы по NAS**](https://habr.com/post/418091/). По предложениям [пользователей](https://habr.com/users/mkulesh/) ссылки на материалы будут сведены в отдельную статью.
1. [**Выбор железа**](https://habr.com/post/353012/). Описан один из вариантов выбора железа и дан краткий обзор рынка домашних и офисных NAS систем.
2. [**Установка ОС, на которой будет строиться NAS**](https://habr.com/post/351932/). В [отдельной статье](https://habr.com/post/358914/) описано дополнение, позволяющее отказаться ото всех файловых систем, кроме ZFS.
3. [**Проектирование поддерживающей инфраструктуры**](https://habr.com/post/359344/), которая будет лежать в основе всех сервисов NAS.
4. [**Реализация поддерживающей инфраструктуры**](https://habr.com/post/415779/).
5. [**Механизм аварийной удалённой разблокировки**](https://habr.com/post/419915/). Требуется для того, чтобы разблокировать систему, не имея к ней физического доступа.
6. [**Повышение защищённости NAS**](https://habr.com/post/421279/). Исправление ошибок, допущенных в предыдущих статьях и описание Hardening процесса.
7. [**Система контроля версий на базе Git**](https://habr.com/post/418883/). Установка Gitlab в контейнере.
8. [**Система резервного копирования**](https://habr.com/ru/post/421251/). От регламента до установки ПО, где в качестве примера используется UrBackup.
9. [**Персональное облако**](https://habr.com/post/430970/). Обеспечивает хранение персональных файлов пользователя, обмен файлами между пользователями, а также интеграцию различных сервисов между собой.
10. [**Сквозная аутентификация контейнеров**](https://habr.com/ru/post/456894/).
11. Управление файлами.
12. Библиотека.
13. Мультимедийная система 1: музыка.
14. Мультимедийная система 2: медиа сервер.
15. Фронтенд. Интерфейс, позволяющий быстро обращаться к сервисам.
16. Заметки про управление контейнерами.

<cut/>

Как видно из новостей, облака и сервисы крупных компаний - это удобно и надёжно, но далеко не всегда:

- [Безопасности уделяется мало внимания](https://habr.com/company/pt/blog/308906/), несмотря на все заверения.
- [Смена тарифов зависит только от прихоти компании](https://habr.com/post/417715/).
- [Старые сервисы уходят](https://candoru.ru/2018/05/14/proshhaj-google-drive/) с неизвестными для пользователей последствиями.
- [Ваш аккаунт могут заблокировать в любой момент](https://habr.com/post/357280/) по [не вполне понятным причинам](https://habr.com/post/372899/).
- И не стоит даже говорить о том, что в один прекрасный момент доступ к вашим ресурсам вам [может заблокировать государство](https://sohabr.net/habr/post/354018/).

Так что, кормить облачные сервисы - хорошо, но в некоторых случаях "своя рубашка ближе к телу".

Изначально, одной из моих целей являлось исследование построения собственной системы, в частности NAS с возможностью работы "домашним сервером".

Постепенно возникла идея, что в свете недавних событий, информация такого плана интересна, и неплохо бы аккумулировать её в одном месте, структурировать и дополнить.
В итоге, должно сформироваться что-то вроде общедоступных best practices для энтузиастов, начиная от выбора и сборки железа и заканчивая программным обеспечением.

Данная статья является оглавлением к статьям по построению NAS.

По этим практикам желающие смогут построить свой NAS на приемлемом инженерном уровне.
Затем, исправить ошибки, дополнить своими идеями и, при желании, опубликовать свой вариант, улучшив практики и пополнив общую базу.

Основной практической целью построения системы было дать мне возможность безопасно работать с моими данными из любого места, где есть Интернет.

Следствием из этого, главной задачей построения данного NAS стало обеспечение точки синхронизации в виде системы управления Git репозиториями и системы резервного копирования.
Прочие задачи - это коллаборация через self-hosted облако, построение системы мультимедийной поддержки, репликация данных на сторонние облака и хранение относительно статичных данных, таких как книги, фильмы, музыка.