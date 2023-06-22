# Community-версия Sage
Sage - это платформа real-time аналитики и мониторинга на базе логов и метрик, разработанная в Тинькофф. Подробнее о платформе [здесь](https://www.tinkoff.ru/software/sage/).

В этом репозитории лежит скрипт установки Сommunity-версии Sage. Она бесплатная, но имеет ряд ограничений. Устанавливая ее, вы принимаете [пользовательское соглашение](https://acdn.tinkoff.ru/static/documents/899d21c1-9b06-49bd-8930-c30da53b75e4.docx).

- [Сравнение версий](#сравнение-версий)
- [Требования к ресурсам](#требования-к-ресурсам)
- [Необходимые навыки и умения](#необходимые-навыки-и-умения)
- [Управление установкой](#управление-установкой)
- [Процесс установки](#процесс-установки)
- [Работа в Sage Community](#работа-в-sage-community)
- [Добавление групп Sage](#добавление-групп-sage)
- [Удаление Sage Community](#удаление-sage-community)
- [Поддержка](#поддержка)

## Сравнение версий
| | Sage Enterprise | Sage Community |
| ------------- | ------------- | ------------- |
| Сбор метрик  | Да  | Да  |
| Сбор логов  | Да  | Да  |
| Объем логов  | В зависимости от лицензии  | 500 Мб в сутки  |
| Простой и гибкий язык запросов к данным  | Да  | Да  |
| Удобный UI  | Да  | Да  |
| Обогащение данных через lookups  | Да  | Да  |
| Алертинг  |Да  | Да  |
| Гибкий механизм уведомлений по различным каналам  | Да  | Да  |
| Визуализации и дашборды | Да  | Да  |
| Встроенная документация | Да  | Да  |
| Масштабируемость | Масштабируется на большие объемы  | Нет |
| Мультитенантность/группы данных | Без ограничений	 | максимум 9 |
| Количество пользователей | Без ограничений	 | максимум 5  |
| Внешний провайдер авторизации | Да  | Нет |
| Обновления | Да | Да |
| Поддержка | Вплоть до 24/7 | best effort  |
| Установка и внедрение | Сервис со стороны вендора/партнера | Самостоятельно |

## Требования к ресурсам

- Процессор x86-64 с числом ядер не менее 8;
- Оперативная память: 16 Gb;
- Пространство для установки на жестком диске: 30 Gb;
- Операционная система: Ubuntu 20.04/22.04;
- Монитор с разрешением 1600х1200 и выше;
- Установленный Docker v.20.10.16 и выше;
- Установленный модуль Docker Compose;
- Установленный Python версии 3.8 и выше;
- Установленный unzip;
- Учетная запись с root-правами для установки Sage Community;
- Доступ в Интернет.

## Необходимые навыки и умения

Установка и использование Sage Community предполагают наличие опыта в следующих областях:

- сети:
  - IP-адресация, маски подсети, сетевые порты;
- системы виртуализации:
  - работа с подсистемой контейнерной виртуализации (Docker);
- опыт работы с командной строкой ОС Linux;
- практический опыт администрирования:
  - ElasticSearch;
  - VictoriaMetrics;
  - Kafka;
  - PostgreSQL;
- опыт работы с Ansible.

## Управление установкой

Развертывание Sage Community выполняется с помощью вспомогательного скрипта `sage-community.sh`, который обеспечивает высокоуровневое управление инсталляцией.

Если кратко, то он делает следующее:
1. Поднимает отдельный ssh на localhost, создает для него ключ
2. Скачивает из облака и запускает docker-образ с установщиком
3. Установщик создает отдельную подсеть докера, скачивает из облака docker-образы остальных компонент и конфигурирует их
   **Важно!** В текущей версии установщика невозможно задать маску подсети, всегда используется 10.102.0.0/16. Если эта подсеть занята, установщик выдаст ошибку. Возможность менять подсеть появится позже.
5. Запускает Sage с помощью модуля Docker Compose

Скрипт содержит следующие команды:

Команда | Описание
--------|---------
`check`| Проверка соответствия рабочей станции требованиям Sage Community. Команда позволяет выявить только критичные отклонения от выдвинутых требований, её успешное завершение не гарантирует положительный результат установки демоверсии.
`install`| Установка Sage Community на рабочую станцию. Время выполнения команды варьируется в зависимости от объёма доступных ресурсов; ожидаемое время установки: 10-30 минут.
`group-add`| Добавление новых групп Sage.
`wipe`| Удаление Sage Community и временных файлов с рабочей станции.

## Процесс установки

Для установки Sage Community выполните следующие команды:

1. Скачайте файл `sage-community.sh` и положите его в директорию, из которой планируете разворачивать Sage Community.

2. Выполните проверку рабочей станции на соответствие требованиям:

  ```sh
  ./sage-community.sh check
  ```

- При выявлении критичных отклонений от требований, выполнение команды завершается выводом сообщения о невозможности установки Sage Community с указанием причины.
- Если рабочая станция соответствует требованиям, сообщение о результате выполнении команды отсутствует.

  **Примечание:** Мы настоятельно рекомендуем выполнить команду при первой установке Sage Community. Если вы уверены, что рабочая станция соответствует требованиям, шаг можно пропустить.

3. Установите Sage Community:

  ```sh
  ./sage-community.sh install
  ```

  **Внимание!** Перед установкой Sage Community, пожалуйста, ознакомьтесь с [Пользовательским соглашением](https://acdn.tinkoff.ru/static/documents/899d21c1-9b06-49bd-8930-c30da53b75e4.docx).

  Выполнение команды может занять продолжительное время. В результате на вашей рабочей станции будет развернут Sage Community.

## Работа в Sage Community

1. Чтобы начать работу с Sage Community, перейдите по ссылке, выведенной инсталлятором в терминал последним сообщением. Для корректной работы приложения рекомендуется использовать Google Chrome.

  **Внимание!** Sage Community использует самоподписанные сертификаты безопасности, поэтому при попытке перейти по указанной ссылке может отображаться предупреждение о переходе на небезопасный сайт. Данное предупреждение можно проигнорировать.

2. Выполните вход в Sage Community, используя одну из существующих учетных записей: `admin`, `sage_user`, `superviewer`, `alice` или `bob`. Пароль: `password`.

## Добавление групп Sage

Для добавления существующих пользователей в новые группы используйте команду:

```sh
sage-community.sh group-add <groups.yml>
```

Последним аргументом в команду передается имя файла, содержащего список новых групп `manul_groups`. Пример минимального файла, добавляющего группу `NewWowGroup`:

```yml
---
manul_groups:
  - name: NewWowGroup
   description: New group added
```

## Удаление Sage Community

Чтобы удалить Sage Community, выполните команду:

```sh
sage-community.sh wipe
```

Данная команда свернет инсталляцию и удалит все временные файлы с рабочей станции.

## Поддержка
Если на любом этапе вам понадобится техническая поддержка, заведите issue в этом репозитории или пишите в [телеграм-чат](https://t.me/+PVvoEcsrwa5mZWQy)
