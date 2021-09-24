# Pterodactyl-Panel-Install
* Сценарий установки и обновления Pterodactyl
* Обратите внимание, что этот скрипт предназначен для установки на новую ОС.
* Установка его на не свежую ОС может вызвать проблемы.
--------------------------------
####Автоматическое обнаружение нежелательных виртуализации:
* 1 Bare Metal
* 2 OpenVZ
* 3 Xen-HVM
* 4 Google Cloud
* 5 CloudLinux
* и так далее
--------------------------------
####Автоматическое обнаружение операционной системы.
* Поддерживаемые ОС:
* Ubuntu: 19.04 18.10, 18.04, 16.04
* Debian: 10
* Fedora: 29, 28
* CentOS: 7
* RHEL: 7
--------------------------------
####22 режима установки:
* [0] Завершение работы скрипта
* [1] Установить панель 1.6.2.
* [2] Установить панель 0.7.19.
* [3] Установить wings 1.5.1.
* [4] Установить daemon 0.6.13.
* [5] Установить панель 1.6.2 и wings 1.5.1.
* [6] Установить панель 0.7.19 и daemon 0.6.13.
* [7] Установить standalone SFTP server.
* [8] Обновить (1.x) панель до 1.6.2.
* [9] Обновить (0.7.x) панель до 1.6.2.
* [10] Обновить (0.7.x) панель до 0.7.19.
* [11] Обновить (0.6.x) daemon до 0.6.13.
* [12] Миграция daemon в wings.
* [13] Обновить панель до 1.6.2 и миграция в wings
* [14] Обновить панель до 0.7.19 и daemon до 0.6.13
* [15] Обновить standalone SFTP server до (1.0.5).
* [16] Сделать Pterodactyl совместимым с мобильным приложением (используйте это только после того, как вы установили панель - Используйте https://pterodactyl.cloud для получения дополнительной информации).
* [17] Обновить мобильную совместимость.
* [18] Установка или обновление phpMyAdmin (5.1.1) (используйте это только после того, как вы установили панель).
* [19] Установить автономный хост базы данных (только для использования в установках с daemon).
* [20] Установка тем Pterodactyl (Только для панели 0.7.19 ).
* [21] Аварийный сброс пароля root MariaDB.
* [22] Аварийный сброс пароля базы данных.
--------------------------------
####Темы:
* [1] По умолчанию
* [2] Tango Twist.
* [3] Blue Brick.
* [4] Minecraft Madness.
* [5] Lime Stitch.
* [6] Red Ape.
* [7] BlackEnd Space.
* [8] Nothing But Graphite.
* Вы можете узнать о темах Fonix здесь: https://github.com/TheFonix/Pterodactyl-Themes
--------------------------------
* Выбор установки Apache2 или Nginx.

* Установка SSL для вашего домена.

* Автоматическое закрытие и защита портов
--------------------------------
####Автоматическая установка:
* PHP 8.0 со следующими расширениями: cli, openssl, gd, mysql, PDO, mbstring, tokenizer, bcmath, xmlили dom, curl, zip, и , fpm если вы планируете использовать Nginx
* MySQL 5.7 или MariaDB 10.5
* Redis ( redis-server)
* Веб-сервер (Apache, NGINX)
* curl
* tar
* unzip
* git
* composer
--------------------------------
####Установка:
* Шаг 1. Скопируйте код и вставьте в консоль и нажмите Enter.

* **`curl -Lo install.sh https://raw.githubusercontent.com/stashenko/Pterodactyl-Panel-Install/master/install.sh`**

* Шаг 2. Скопируйте код и вставьте в консоль и нажмите Enter.

* **`bash install.sh`**

# Поддерживаемая операционная система
| Опер. система     | Версия  | Поддержка            | Рекомендуется      |
| ----------------- | ------- | -------------------- | ------------------ |
| Ubuntu            | 20.04   | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 18.04   | :heavy_check_mark:   | :heavy_check_mark: |
| Debian            | 10      | :heavy_check_mark:   | :heavy_check_mark: |
| CentOS            | Stream  | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 8       | :heavy_check_mark:   | :heavy_check_mark: |
| RHEL              | 8       | :heavy_check_mark:   | :red_circle:       |
| Fedora            | 34      | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 33      | :heavy_check_mark:   | :heavy_check_mark: |
