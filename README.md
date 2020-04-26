# Pterodactyl-Panel-Install
Сценарий установки и обновления Pterodactyl
Обратите внимание, что этот скрипт предназначен для установки на новую ОС.
Установка его на не свежую ОС может вызвать проблемы.

Автоматическое обнаружение не желательных виртуализации:
1 Bare Metal
2 OpenVZ
3 Xen-HVM
4 Google Cloud
5 CloudLinux
и так далее

Автоматическое обнаружение операционной системы.
Поддерживаемые ОС:
Ubuntu: 19.04 18.10, 18.04, 16.04
Debian: 9, 8
Fedora: 29, 28
CentOS: 7
RHEL: 7

12 режимов установки:
0 Завершение работы скрипта
1 Установка Pterodactyl panel.
2 Установка Pterodactyl daemon.
3 Установка Pterodactyl panel и daemon.
4 Установка standalone SFTP server.
5 Обновление 0.7.x panel до 0.7.17.
6 Обновление 0.6.x daemon до 0.6.13.
7 Обновление panel до 0.7.17 и daemon до 0.6.13
8 Обновление standalone SFTP server 1.0.4.
9 Установка или Обновление phpMyAdmin 5.0.2
10 Аварийный сброс пароля root MariaDB.
11 Аварийный сброс базы данных.
12 Установка тем Pterodactyl.
Темы:
[1] По умолчанию
[2] Tango Twist.
[3] Blue Brick.
[4] Minecraft Madness.
[5] Lime Stitch.
[6] Red Ape.
[7] BlackEnd Space.
[8] Nothing But Graphite.
Вы можете узнать о темах Fonix здесь: https://github.com/TheFonix/Pterodactyl-Themes

Выбор установки Apache2 или Nginx.

Установка SSL для вашего домена.

Автоматическое закрытие и защита портов

Автоматическая установка:
PHP 7.2 со следующими расширениями: cli, openssl, gd, mysql, PDO, mbstring, tokenizer, bcmath, xmlили dom, curl, zip, и , fpm если вы планируете использовать Nginx
MySQL 5.7 или MariaDB 10.1.3
Redis ( redis-server)
Веб-сервер (Apache, NGINX)
curl
tar
unzip
git
composer

Установка:
Шаг 1. Скопируйте код и вставьте в консоль и нажмите Enter.

curl -Lo install.sh https://raw.githubusercontent.com/stashenko/Pterodactyl-Panel-Install/master/install.sh

Шаг 2. Скопируйте код и вставьте в консоль и нажмите Enter.

bash install.sh
