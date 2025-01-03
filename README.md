# Установка Pterodactyl Panel
* Сценарий установки и обновления Pterodactyl Panel
* Обратите внимание, что этот скрипт предназначен для установки на новую ОС.
* Установка его на не свежую ОС может вызвать проблемы.
* Перед установкой привяжите домен к IP сервера.
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
* Ubuntu: 24.04, 22.04, 20.04
* Debian: 12, 11
* Fedora: 35
* CentOS: 8
* RHEL: 8, 9
* Rocky Linux: 8, 9
* AlmaLinux: 8, 9
--------------------------------
####9 режимов установки:
* [0] Завершение работы скрипта
* [1] Установить панель (Последней версии)
* [2] Установить wings (Последней версии)
* [3] Установить панель и wings
* [4] Обновить (1.x) панель до (Последней версии)
* [5] Обновить wings до (Последней версии)
* [6] Обновить панель и wings до (Последней версии)
* [7] Установка phpMyAdmin (используйте это только после того, как вы установили панель).
* [8] Аварийный сброс пароля root MariaDB.
* [9] Аварийный сброс пароля базы данных.
--------------------------------
* Установка SSL для вашего домена.

* Автоматическое закрытие и защита портов
--------------------------------
####Автоматическая установка:
* PHP 8.2 со следующими расширениями: cli, openssl, gd, mysql, PDO, mbstring, tokenizer, bcmath, xml или dom, curl, zip, и , fpm
* MySQL или MariaDB
* Redis ( redis-server)
* Веб-сервер NGINX
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
|                   | 22.04   | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 24.04   | :heavy_check_mark:   | :heavy_check_mark: |
| Debian            | 11      | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 12      | :heavy_check_mark:   | :heavy_check_mark: |
| CentOS            | Stream  | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 8       | :heavy_check_mark:   | :heavy_check_mark: |
| RHEL              | 8       | :heavy_check_mark:   | :red_circle:       |
|                   | 9       | :heavy_check_mark:   | :heavy_check_mark: |
| Fedora            | 35      | :heavy_check_mark:   | :heavy_check_mark: |
| Rocky Linux       | 8       | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 9       | :heavy_check_mark:   | :heavy_check_mark: |
| AlmaLinux         | 8       | :heavy_check_mark:   | :heavy_check_mark: |
|                   | 9       | :heavy_check_mark:   | :heavy_check_mark: |
