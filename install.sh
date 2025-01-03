#!/bin/bash

output(){
    echo -e '\e[36m'$1'\e[0m';
}

warn(){
    echo -e '\e[31m'$1'\e[0m';
}

PANEL=latest
WINGS=latest

preflight(){
    output "Скрипт установки и обновления Pterodactyl Panel"
    output "Copyright © 2025 The_stas."
    output ""

    output "Обратите внимание, что этот сценарий предназначен для установки на новую ОС. Установка на не новую ОС может вызвать проблемы."
    output "Автоматическое определение операционной системы ..."

    os_check

    if [ "$EUID" -ne 0 ]; then
        output "Пожалуйста, запустите скрипт как пользователь root."
        exit 3
    fi

    output "Автоматическое определение архитектуры ..."
    MACHINE_TYPE=`uname -m`
    if [ "${MACHINE_TYPE}" == 'x86_64' ]; then
        output "Обнаружен 64-битный сервер! Поехали дальше."
        output ""
    else
        output "Обнаружена неподдерживаемая архитектура! Пожалуйста, перейдите на 64-разрядную версию (x86_64)."
        exit 4
    fi

    output "Автоматическое обнаружение виртуализации ..."
    if [ "$lsb_dist" =  "ubuntu" ]; then
        apt-get update --fix-missing
        apt-get -y install software-properties-common
        add-apt-repository -y universe
        apt-get -y install virt-what curl
    elif [ "$lsb_dist" =  "debian" ]; then
        apt update --fix-missing
        apt-get -y install software-properties-common virt-what wget curl dnsutils
    elif [ "$lsb_dist" = "fedora" ] || [ "$lsb_dist" = "centos" ] || [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        yum -y install virt-what wget bind-utils
    fi
    virt_serv=$(echo $(virt-what))
    if [ "$virt_serv" = "" ]; then
        output "Виртуализация: обнаружено Bare Metal."
    elif [ "$virt_serv" = "openvz lxc" ]; then
        output "Виртуализация: обнаружено OpenVZ 7."
    elif [ "$virt_serv" = "xen xen-hvm" ]; then
        output "Виртуализация: обнаружено Xen-HVM."
    elif [ "$virt_serv" = "xen xen-hvm aws" ]; then
        output "Виртуализация: обнаружено Xen-HVM on AWS."
        warn "При создании выделения для этого узла используйте внутренний IP-адрес, поскольку Google Cloud использует маршрутизацию NAT."
        warn "Возобновление через 10 секунд ..."
        sleep 10
    else
        output "Виртуализация: $virt_serv detected."
    fi
    output ""
    if [ "$virt_serv" != "" ] && [ "$virt_serv" != "kvm" ] && [ "$virt_serv" != "vmware" ] && [ "$virt_serv" != "hyperv" ] && [ "$virt_serv" != "openvz lxc" ] && [ "$virt_serv" != "xen xen-hvm" ] && [ "$virt_serv" != "xen xen-hvm aws" ]; then
        warn "Обнаружен неподдерживаемый тип виртуализации. Проконсультируйтесь со своим хостинг-провайдером, может ли ваш сервер запускать Docker или нет. Действуйте на свой страх и риск."
        warn "Никакой поддержки не будет, если ваш сервер сломается в любой момент."
        warn "Продолжить?\n[1] Да.\n[2] Нет."
        read choice
        case $choice in 
            1)  output "Продолжение ..."
                ;;
            2)  output "Отмена установки ..."
                exit 5
                ;;
        esac
        output ""
    fi

    output "Обнаружение ядра ..."
    if echo $(uname -r) | grep -q xxxx; then
        output "Обнаружено ядро OVH. Этот скрипт работать не будет. Пожалуйста, переустановите свой сервер, используя стандартное / дистрибутивное ядро."
        output "Когда вы переустанавливаете свой сервер, нажмите 'custom installation', а после этого нажмите 'use distribution'"
        output "Вы также можете сделать пользовательское разбиение на разделы, удалить раздел / home и предоставить / all the remaining space.."
        exit 6
    elif echo $(uname -r) | grep -q pve; then
        output "Обнаружено ядро Proxmox LXE. Вы решили продолжить последний шаг, поэтому мы действуем на ваш страх и риск."
        output "Продолжение рискованной операции ..."
    elif echo $(uname -r) | grep -q stab; then
        if echo $(uname -r) | grep -q 2.6; then 
            output "Обнаружен OpenVZ 6. Этот сервер определенно не будет работать с Docker, что бы ни сказал ваш провайдер. Отмените установку во избежание дальнейших повреждений."
            exit 6
        fi
    elif echo $(uname -r) | grep -q gcp; then
        output "Обнаружена Google Cloud Platform."
        warn "Убедитесь, что у вас установлен статический IP-адрес, иначе система не будет работать после перезагрузки."
        warn "Также убедитесь, что брандмауэр GCP разрешает порты, необходимые для нормальной работы сервера."
        warn "При создании выделения для этого узла используйте внутренний IP-адрес, поскольку Google Cloud использует маршрутизацию NAT."
        warn "Возобновление через 10 секунд ..."
        sleep 10
    else
        output "Не обнаружил плохих ядер. Поехали дальше..."
        output ""
    fi
}

os_check(){
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        if [ "$lsb_dist" = "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
            dist_version="$(echo $dist_version | awk -F. '{print $1}')"
        fi
    else
        exit 1
    fi
    
    if [ "$lsb_dist" =  "ubuntu" ]; then
        if  [ "$dist_version" != "24.04" ] && [ "$dist_version" != "22.04" ] && [ "$dist_version" != "20.04" ]; then
            output "Неподдерживаемая версия Ubuntu. Поддерживаются только Ubuntu 24.04, 22.04, 20.04."
            exit 2
        fi
    elif [ "$lsb_dist" = "debian" ]; then
        if [ "$dist_version" != "10" ] && [ "$dist_version" != "12" ] && [ "$dist_version" != "11" ]; then
            output "Неподдерживаемая версия Debian. Поддерживается только Debian 10, 11, 12"
            exit 2
        fi
    elif [ "$lsb_dist" = "fedora" ]; then
        if [ "$dist_version" != "35" ]; then
            output "Неподдерживаемая версия Fedora. Поддерживаются только Fedora 35."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "8" ] && [ "$dist_version" != "7" ]; then
            output "Неподдерживаемая версия CentOS. Поддерживаются только CentOS Stream и 8."
            exit 2
        fi
    elif [ "$lsb_dist" = "rhel" ]; then
        if [ "$dist_version" != "8" ] && [ "$dist_version" != "9" ]; then
            output "Неподдерживаемая версия RHEL. Поддерживается только RHEL 8 и 9"
            exit 2
        fi
    elif [ "$lsb_dist" = "rocky" ]; then
        if [ "$dist_version" != "8" ] && [ "$dist_version" != "9" ]; then
            output "Неподдерживаемая версия Rocky. Поддерживается только Rocky 8 и 9"
            exit 2
        fi
    elif [ "$lsb_dist" = "almalinux" ]; then
        if [ "$dist_version" != "8" ] && [ "$dist_version" != "9" ]; then
            output "Неподдерживаемая версия Almalinux. Поддерживается только Almalinux 8 и 9"
            exit 2
        fi
    elif [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "debian" ] && [ "$lsb_dist" != "fedora" ] && [ "$lsb_dist" != "centos" ] && [ "$lsb_dist" != "rhel" ] && [ "$lsb_dist" != "rocky" ] && [ "$lsb_dist" != "almalinux" ]; then
        output "Неподдерживаемая операционная система."
        output ""
        output "Поддерживаемая ОС:"
        output "Ubuntu: 24.04, 22.04, 20.04"
        output "Debian: 11, 12"
        output "Fedora: 35"
        output "CentOS: 8"
        output "RHEL: 8, 9"
        output "Rocky Linux: 8, 9"
        output "AlmaLinux: 8, 9"
        exit 2
    fi
}

install_options(){
    output "Выберите вариант установки:"
    output "[1] Установить панель ${PANEL}."
    output "[2] Установить wings ${WINGS}."
    output "[3] Установить панель ${PANEL} и Установить wings ${WINGS}."
    output "[4] Обновить (1.x) панель до ${PANEL}."
    output "[5] Обновить wings до ${WINGS}."
    output "[6] Обновить панель до ${PANEL} и wings до ${WINGS}."
    output "[7] Установка phpMyAdmin (используйте это только после того, как вы установили панель)."
    output "[8] Аварийный сброс пароля root MariaDB."
    output "[9] Аварийный сброс пароля базы данных."
    read -r choice
    case $choice in
        1 ) installoption=1
            output "Вы выбрали установку только панели ${PANEL}."
            ;;
        2 ) installoption=2
            output "Вы выбрали установку только wings ${WINGS}."
            ;;
        3 ) installoption=3
            output "Вы выбрали установку панели ${PANEL} и wings ${WINGS}."
            ;;
        4 ) installoption=4
            output "Вы выбрали обновление панели до ${PANEL}."
            ;;
        5 ) installoption=5
            output "Вы выбрали обновление wings до ${WINGS}."
            ;;
        6 ) installoption=6
            output "Вы выбрали обновление панели до ${PANEL} и wings до ${WINGS}."
            ;;
        7 ) installoption=7
            output "Вы выбрали установку phpMyAdmin."
            ;;
        8 ) installoption=8
            output "Вы выбрали сброс пароля root MariaDB."
            ;;
        9 ) installoption=9
            output "Вы выбрали сброс пароля базы данных."
            ;;
        * ) output "Вы ввели неверный выбор. Введите цифру от 1 до 9"
            install_options
    esac
}

required_infos() {
    output "Пожалуйста, введите желаемый адрес электронной почты пользователя:"
    read -r email
    dns_check
}

dns_check(){
    output "Пожалуйста, введите ваше полное доменное имя (panel.domain.tld):"
    read -r FQDN

    output "Разрешение DNS..."
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com -4)
    DOMAIN_RECORD=$(dig +short ${FQDN})
    if [ "${SERVER_IP}" != "${DOMAIN_RECORD}" ]; then
        output ""
        output "Введенный домен не соответствует первичному общедоступному IP-адресу этого сервера."
        output "Пожалуйста, сделайте запись A, указывающую на IP-адрес вашего сервера. Например, если вы сделаете запись A под названием 'panel', указывающую на IP-адрес вашего сервера, ваше полное доменное имя будет panel.domain.tld."
        output "Если вы используете Cloudflare, отключите оранжевое облако."
        output "Если у вас нет домена, вы можете получить его бесплатно по адресу https://freenom.com"
        dns_check
    else
        output "Домен определен правильно. Поехали дальше..."
    fi
}

repositories_setup(){
    output "Настройка репозиториев ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common curl apt-transport-https ca-certificates gnupg
        dpkg --remove-architecture i386
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update
    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            apt -y install tuned dnsutils
            tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            apt -y install dirmngr
            wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
            sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
            apt -y install tuned
            tuned-adm profile latency-performance
            apt-get -y update
            apt-get -y upgrade
            apt-get -y autoremove
            apt-get -y autoclean
            apt-get -y install curl
        fi
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install dnf-utils
        if  [ "$lsb_dist" =  "fedora" ] ; then
            dnf -y install http://rpms.remirepo.net/fedora/remi-release-35.rpm
    else	
        dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
    fi
        dnf config-manager --set-enabled remi
        dnf -y install tuned dnf-automatic
        tuned-adm profile latency-performance
    systemctl enable --now irqbalance
    sed -i 's/apply_updates = no/apply_updates = yes/g' /etc/dnf/automatic.conf
    systemctl enable --now dnf-automatic.timer
        dnf -y upgrade
        dnf -y autoremove
        dnf -y clean packages
        dnf -y install curl bind-utils cronie
    fi
    systemctl enable --now fstrim.timer
}

install_dependencies(){
    output "Установка зависимостей ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} nginx tar unzip git redis-server nginx git wget expect composer
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated mariadb-server"
    else
        dnf -y module install nginx:mainline/common
        dnf -y module install php:remi-8.0/common
        dnf -y module install redis:remi-6.2/common
        dnf -y module install mariadb:10.5/server
        dnf -y install git policycoreutils-python-utils unzip wget expect jq php-mysql php-zip php-bcmath tar composer
    fi

    output "Включение служб ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        systemctl enable --now redis-server
        systemctl enable --now php8.0-fpm
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        systemctl enable --now redis
        systemctl enable --now php-fpm
    fi

    systemctl enable --now cron
    systemctl enable --now mariadb
    systemctl enable --now nginx
}

install_pterodactyl() {
    output "Создание баз данных и установка пароля root ..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, CREATE ROUTINE, ALTER ROUTINE, EXECUTE, PROCESS, RELOAD, LOCK TABLES, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Привязка MariaDB/MySQL к 0.0.0.0"
        if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/mysql/mariadb.conf.d/50-server.cnf
		sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/mysql/mariadb.conf.d/50-server.cnf
		sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Перезапуск MySQL процесса ...'
		service mariadb restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/mysql/my.cnf
		output 'Перезапуск MariaDB процесса...'
		service mariadb restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/my.cnf
		sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/my.cnf
		sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/my.cnf
		output 'Перезапуск MariaDB процесса...'
		service mariadb restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Перезапуск MariaDB процесса...'
		service mariadb restart
    	elif grep -Fqs "bind-address" /etc/my.cnf.d/mariadb-server.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf.d/mariadb-server.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf.d/mariadb-server.cnf
		sed -i '/\[mysqld\]/a ssl-key=/etc/letsencrypt/live/'"${FQDN}"'/privkey.pem' /etc/my.cnf.d/mariadb-server.cnf
		sed -i '/\[mysqld\]/a ssl-ca=/etc/letsencrypt/live/'"${FQDN}"'/chain.pem' /etc/my.cnf.d/mariadb-server.cnf
		sed -i '/\[mysqld\]/a ssl-cert=/etc/letsencrypt/live/'"${FQDN}"'/cert.pem' /etc/my.cnf.d/mariadb-server.cnf
		output 'Перезапуск MariaDB процесса...'
		service mariadb restart
	else
		output 'Файл конфигурации MariaDB не обнаружен! Обратитесь в службу поддержки.'
	fi

    output "Загрузка Pterodactyl..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    if [ ${PANEL} = "latest" ]; then
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    else
        curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz
    fi
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Установка Pterodactyl..."
 
    cp .env.example .env
    composer update --no-interaction
    composer install --no-dev --optimize-autoloader --no-interaction
    
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/New_York --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "Чтобы использовать внутреннюю отправку почты PHP, выберите [mail]. Чтобы использовать собственный SMTP-сервер, выберите [smtp]. Рекомендуется шифрование TLS."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        chown -R nginx:nginx * /var/www/pterodactyl
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi

    output "Создание слушателей очереди панели ..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -

    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
        setsebool -P httpd_can_network_connect 1
	setsebool -P httpd_execmem 1
	setsebool -P httpd_unified 1
    fi
    sudo systemctl daemon-reload
    systemctl enable --now pteroq.service
}

upgrade_pterodactyl(){
    cd /var/www/pterodactyl && php artisan p:upgrade
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" = "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        chown -R nginx:nginx * /var/www/pterodactyl
        restorecon -R /var/www/pterodactyl
    fi
    output "Ваша панель успешно обновлена до версии ${PANEL}"
}

nginx_config() {
    output "Отключение конфигурации по умолчанию ..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка веб-сервера Nginx ..."

echo '
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name '"$FQDN"';
    
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "0";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "upgrade-insecure-requests; block-all-mixed-content; frame-ancestors 'self'" always;
    add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), clipboard-read=(), clipboard-write=(), display-capture=(), document-domain=(), encrypted-media=(), fullscreen=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
' | sudo -E tee /etc/nginx/sites-available/pterodactyl.conf >/dev/null 2>&1
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

nginx_config_redhat(){
    output "Настройка веб-сервера Nginx ..."

echo '
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    
    sendfile off;
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
    ssl_prefer_server_ciphers on;

    add_header Strict-Transport-Security "max-age=15768000; includeSubdomains; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "0";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "upgrade-insecure-requests; block-all-mixed-content; frame-ancestors 'self'" always;
    add_header Permissions-Policy "accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), clipboard-read=(), clipboard-write=(), display-capture=(), document-domain=(), encrypted-media=(), fullscreen=(), geolocation=(), gyroscope=(), hid=(), idle-detection=(), interest-cohort=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), sync-xhr=(), usb=(), xr-spatial-tracking=()" always;
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php-fpm/pterodactyl.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        include /etc/nginx/fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
' | sudo -E tee /etc/nginx/conf.d/pterodactyl.conf >/dev/null 2>&1

    service nginx restart
    chown -R nginx:nginx $(pwd)
    restorecon -R /var/www/pterodactyl
}

php_config(){
    output "Настройка PHP-сокета..."
    bash -c 'cat > /etc/php-fpm.d/www-pterodactyl.conf' <<-'EOF'
[pterodactyl]

user = nginx
group = nginx

listen = /var/run/php-fpm/pterodactyl.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0750

pm = ondemand
pm.max_children = 9
pm.process_idle_timeout = 10s
pm.max_requests = 200
EOF
    systemctl restart php-fpm
}

webserver_config(){
    if [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        nginx_config
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        php_config
        nginx_config_redhat
    chown -R nginx:nginx /var/lib/php/session
    fi
}

setup_pterodactyl(){
    install_dependencies
    install_pterodactyl
    ssl_certs
    webserver_config
}


install_wings() {
    cd /root || exit
    output "Установка зависимостей Pterodactyl Wings ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install curl tar unzip
    fi

    output "Установка Docker"
    if  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        dnf -y install docker-ce --allowerasing
    else
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    fi
    
    systemctl enable --now docker
    output "Установка Pterodactyl wings..."
    mkdir -p /etc/pterodactyl
    cd /etc/pterodactyl || exit
    if [ ${WINGS} = "latest" ]; then
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    else
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    fi
    chmod u+x /usr/local/bin/wings
    
      bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable wings
    output "Wings ${WINGS} установлен в вашей системе."
    output "Вам следует перейти на панель и настроить узел."
    output "Выполните `systemctl start wings` после запуска команды автоматического развертывания."
    if  [ "$lsb_dist" != "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
    output "------------------------------------------------------------------"
    output "ВАЖНОЕ ЗАМЕЧАНИЕ!!!"
    output "Поскольку вы находитесь в системе с целевыми политиками SELinux, вам следует изменить каталог файлов сервера демонов с /var/lib/pterodactyl/volumes на /var/srv/containers/pterodactyl."
    output "------------------------------------------------------------------"
    fi
}


upgrade_wings(){
    if [ ${WINGS} = "latest" ]; then
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    else
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    fi
    chmod u+x /usr/local/bin/wings
    systemctl restart wings
    output "Ваши wings обновлены до версии ${WINGS}."
}

install_phpmyadmin(){
    output "Установка phpMyAdmin..."
    if [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install phpmyadmin
    ln -s /usr/share/phpMyAdmin /var/www/pterodactyl/public/phpmyadmin
    else
        apt -y install phpmyadmin
    ln -s /usr/share/phpmyadmin /var/www/pterodactyl/public/phpmyadmin
    fi
    cd /var/www/pterodactyl/public/phpmyadmin || exit
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com -4)
    BOWFISH=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 34 | head -n 1`
    if [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        bash -c 'cat > /etc/phpMyAdmin/config.inc.php' <<EOF
<?php
/* Servers configuration */
\$i = 0;
/* Server: MariaDB [1] */
\$i++;
\$cfg['Servers'][\$i]['verbose'] = 'MariaDB';
\$cfg['Servers'][\$i]['host'] = '${SERVER_IP}';
\$cfg['Servers'][\$i]['port'] = '3306';
\$cfg['Servers'][\$i]['socket'] = '';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
\$cfg['Servers'][$i]['ssl'] = true;  
\$cfg['ForceSSL'] = true;
/* End of servers configuration */
\$cfg['blowfish_secret'] = '${BOWFISH}';
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '/var/lib/phpMyAdmin/upload';
\$cfg['SaveDir'] = '/var/lib/phpMyAdmin/save';
\$cfg['CaptchaLoginPublicKey'] = '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn';
\$cfg['CaptchaLoginPrivateKey'] = '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5';
\$cfg['AuthLog'] = syslog
?>    
EOF
    chmod 755 /etc/phpMyAdmin
    chmod 644 /etc/phpMyAdmin/config.inc.php
    chown -R nginx:nginx /var/www/pterodactyl
    chown -R nginx:nginx /var/lib/phpMyAdmin/temp
    elif  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        bash -c 'cat > /etc/phpmyadmin/config.inc.php' <<EOF
<?php
/* Servers configuration */
\$i = 0;
/* Server: MariaDB [1] */
\$i++;
\$cfg['Servers'][\$i]['verbose'] = 'MariaDB';
\$cfg['Servers'][\$i]['host'] = '${SERVER_IP}';
\$cfg['Servers'][\$i]['port'] = '3306';
\$cfg['Servers'][\$i]['socket'] = '';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
\$cfg['Servers'][$i]['ssl'] = true;  
\$cfg['ForceSSL'] = true;
/* End of servers configuration */
\$cfg['blowfish_secret'] = '${BOWFISH}';
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '/var/lib/phpmyadmin/upload';
\$cfg['SaveDir'] = '/var/lib/phpmyadmin/save';
\$cfg['CaptchaLoginPublicKey'] = '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn';
\$cfg['CaptchaLoginPrivateKey'] = '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5';
\$cfg['AuthLog'] = syslog
?>    
EOF
    chmod 755 /etc/phpmyadmin
    chmod 644 /etc/phpmyadmin/config.inc.php
    chown -R www-data:www-data /var/www/pterodactyl
    chown -R www-data:www-data /var/lib/phpmyadmin/temp
    fi
    
    bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for one hours:
bantime = 3600
# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport
[sshd]
enabled = true
[phpmyadmin-syslog]
enabled = true
maxentry = 15
EOF
    service fail2ban restart
}

ssl_certs(){
    output "Установка Let's Encrypt и создание SSL-сертификата ..."
    cd /root || exit
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install certbot
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install certbot
    fi
    
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install python3-certbot-nginx
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
            dnf -y install python3-certbot-nginx
        fi
    certbot --nginx --redirect --no-eff-email --email "$email" --agree-tos -d "$FQDN"
    setfacl -Rdm u:mysql:rx /etc/letsencrypt
    setfacl -Rm u:mysql:rx /etc/letsencrypt
    systemctl restart mariadb
    fi
    
    if [ "$installoption" = "2" ]; then
    certbot certonly --standalone --no-eff-email --email "$email" --agree-tos -d "$FQDN" --non-interactive
    fi
    systemctl enable --now certbot.timer
}

firewall(){
    output "Настройка Fail2Ban..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install fail2ban
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install fail2ban
    fi 
    systemctl enable fail2ban
    bash -c 'cat > /etc/fail2ban/jail.local' <<-'EOF'
[DEFAULT]
# Ban hosts for ten hours:
bantime = 36000
# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport
[sshd]
enabled = true

EOF
    service fail2ban restart

    output "Настройка брандмауэра..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install ufw
        ufw allow 22
        if [ "$installoption" = "1" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "2" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "3" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        fi
        yes | ufw enable 
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        dnf -y install firewalld
        systemctl enable firewalld
        systemctl start firewalld
        if [ "$installoption" = "1" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "2" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --zone=trusted --change-interface=pterodactyl0
            firewall-cmd --zone=trusted --add-masquerade --permanent
        elif [ "$installoption" = "3" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
	    firewall-cmd --permanent --zone=trusted --change-interface=pterodactyl0
	    firewall-cmd --zone=trusted --add-masquerade --permanent
        fi
    fi
}

harden_linux(){
    curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/modprobe.d/30_security-misc.conf >> /etc/modprobe.d/30_security-misc.conf
    curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_security-misc.conf >> /etc/sysctl.d/30_security-misc.conf
    sed -i 's/kernel.yama.ptrace_scope=2/kernel.yama.ptrace_scope=3/g' /etc/sysctl.d/30_security-misc.conf
    curl https://raw.githubusercontent.com/Whonix/security-misc/master/etc/sysctl.d/30_silent-kernel-printk.conf >> /etc/sysctl.d/30_silent-kernel-printk.conf
}

database_host_reset(){
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com -4)
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="SET old_passwords=0;"
    Q1="SET PASSWORD FOR 'admin'@'$SERVER_IP' = PASSWORD('$adminpassword');"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}"
    mysql mysql -e "$SQL"
    output "###############################################################"
    output "Информация о новом хосте базы данных:"
    output "Хост: $SERVER_IP"
    output "Порт: 3306"
    output "Пользователь: admin"
    output "Пароль: $adminpassword"
    output "###############################################################"
}

broadcast(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        broadcast_database
    fi
    output "###############################################################"
    output "ИНФОРМАЦИЯ О БРАНДМАУЭРЕ"
    output ""
    output "Все ненужные порты по умолчанию заблокированы."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        output "Используйте 'ufw allow <порт>' для включения нужных вам портов."
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "rocky" ] || [ "$lsb_dist" = "almalinux" ]; then
        output "Используйте 'firewall-cmd --permanent --add-port=<порт>/tcp' для включения нужных вам портов."
    fi
    output "###############################################################"
    output ""
}

broadcast_database(){
    output "###############################################################"
    output "ИНФОРМАЦИЯ о MARIADB/MySQL"
    output ""
    output "Ваш пароль root для MariaDB/MySQL: $rootpassword"
    output ""
    output "Создайте в панеле базу данных со следующей информацией:"
    output "Хост: $SERVER_IP"
    output "Порт: 3306"
    output "Пользователь: admin"
    output "Пароль: $adminpassword"
    output "###############################################################"
    output ""
}

#Исполнение
preflight
install_options
case $installoption in 
    1)  repositories_setup
        required_infos
        firewall
        harden_linux
        setup_pterodactyl
        broadcast
        broadcast_database
        ;;
    2)  repositories_setup
        required_infos
        firewall
        harden_linux
        ssl_certs
        install_wings
        broadcast
        broadcast_database
        ;;
    3)  repositories_setup
        required_infos
        firewall
        harden_linux
        setup_pterodactyl
        install_wings
        broadcast
        ;;
    4)  upgrade_pterodactyl
        ;;
    5)  upgrade_wings
        ;;
    6)  upgrade_pterodactyl
        upgrade_wings
        ;;
    7)  install_phpmyadmin
        ;;
    8)  curl -sSL https://raw.githubusercontent.com/stashenko/mariadb.sh/master/mariadb.sh | sudo bash
        ;;
    9)  database_host_reset
        ;;
esac
