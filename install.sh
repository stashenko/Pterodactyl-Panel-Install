#!/bin/bash

output(){
    echo -e '\e[36m'$1'\e[0m';
}

warn(){
    echo -e '\e[31m'$1'\e[0m';
}

PANEL=v1.6.1
WINGS=v1.4.6
PANEL_LEGACY=v0.7.19
DAEMON_LEGACY=v0.6.13
PHPMYADMIN=5.1.1

preflight(){
    output "Скрипт установки и обновления Pterodactyl"
    output "Copyright © 2021 The_stas <spigotmc.ru>."
    output ""

    output "Обратите внимание, что этот сценарий предназначен для установки на новую ОС. Установка на не новую ОС может вызвать проблемы."
    output "Автоматическое определение операционной системы ..."

    os_check

    if [ "$EUID" -ne 0 ]; then
        output "Пожалуйста, запустите как пользователь root."
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
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
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
        output "Виртуализация: $virt_serv ."
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
        if [ "$lsb_dist" = "rhel" ]; then
            dist_version="$(echo $dist_version | awk -F. '{print $1}')"
        fi
    else
        exit 1
    fi
    
    if [ "$lsb_dist" =  "ubuntu" ]; then
        if  [ "$dist_version" != "20.04" ] && [ "$dist_version" != "18.04" ]; then
            output "Неподдерживаемая версия Ubuntu. Поддерживаются только Ubuntu 20.04 и 18.04."
            exit 2
        fi
    elif [ "$lsb_dist" = "debian" ]; then
        if [ "$dist_version" != "10" ]; then
            output "Неподдерживаемая версия Debian. Поддерживается только Debian 10."
            exit 2
        fi
    elif [ "$lsb_dist" = "fedora" ]; then
        if [ "$dist_version" != "33" ] && [ "$dist_version" != "32" ]; then
            output "Неподдерживаемая версия Fedora. Поддерживаются только Fedora 33 и 32."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "8" ]; then
            output "Неподдерживаемая версия CentOS. Поддерживаются только CentOS Stream и 8."
            exit 2
        fi
    elif [ "$lsb_dist" = "rhel" ]; then
        if  [ $dist_version != "8" ]; then
            output "Неподдерживаемая версия RHEL. Поддерживается только RHEL 8."
            exit 2
        fi
    elif [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "debian" ] && [ "$lsb_dist" != "centos" ]; then
        output "Неподдерживаемая операционная система."
        output ""
        output "Поддерживаемая ОС:"
        output "Ubuntu: 20.04, 18.04"
        output "Debian: 10"
        output "Fedora: 33, 32"
        output "CentOS: 8, 7"
        output "RHEL: 8"
        exit 2
    fi
}

install_options(){
    output "Выберите вариант установки:"
    output "[1] Установить панель ${PANEL}."
    output "[2] Установить панель ${PANEL_LEGACY}."
    output "[3] Установить wings ${WINGS}."
    output "[4] Установить daemon ${DAEMON_LEGACY}."
    output "[5] Установить панель ${PANEL} и wings ${WINGS}."
    output "[6] Установить панель ${PANEL_LEGACY} и daemon ${DAEMON_LEGACY}."
    output "[7] Установить standalone SFTP server."
    output "[8] Обновить (1.x) панель до ${PANEL}."
    output "[9] Обновить (0.7.x) панель до ${PANEL}."
    output "[10] Обновить (0.7.x) панель до ${PANEL_LEGACY}."
    output "[11] Обновить (0.6.x) daemon до ${DAEMON_LEGACY}."
    output "[12] Миграция daemon в wings."
    output "[13] Обновить панель до ${PANEL} и миграция в wings"
    output "[14] Обновить панель до ${PANEL_LEGACY} и daemon до ${DAEMON_LEGACY}"
    output "[15] Обновить standalone SFTP server до (1.0.5)."
    output "[16] Сделать Pterodactyl совместимым с мобильным приложением (используйте это только после того, как вы установили панель - Используйте https://pterodactyl.cloud для получения дополнительной информации)."
    output "[17] Обновить мобильную совместимость."
    output "[18] Установка или обновление phpMyAdmin (${PHPMYADMIN}) (используйте это только после того, как вы установили панель)."
    output "[19] Установить автономный хост базы данных (только для использования в установках с daemon)."
    output "[20] Установка тем Pterodactyl (Только для панели ${PANEL_LEGACY} )."
    output "[21] Аварийный сброс пароля root MariaDB."
    output "[22] Аварийный сброс пароля базы данных."
    read -r choice
    case $choice in
        1 ) installoption=1
            output "Вы выбрали установку только панели ${PANEL}."
            ;;
        2 ) installoption=2
            output "Вы выбрали установку только панели ${PANEL_LEGACY}."
            ;;
        3 ) installoption=3
            output "Вы выбрали установку только  wings ${WINGS}."
            ;;
        4 ) installoption=4
            output "Вы выбрали установку только  daemon ${DAEMON_LEGACY}."
            ;;
        5 ) installoption=5
            output "Вы выбрали установку панели ${PANEL} и wings ${WINGS}."
            ;;
        6 ) installoption=6
            output "Вы выбрали установку панели ${PANEL_LEGACY} и daemon."
            ;;
        7 ) installoption=7
            output "Вы выбрали установку автономного сервера SFTP."
            ;;
        8 ) installoption=8
            output "Вы выбрали обновление панели до ${PANEL}."
            ;;
        9 ) installoption=9
            output "Вы выбрали обновление панели до ${PANEL}."
            ;;
        10 ) installoption=10
            output "Вы выбрали обновление панели до ${PANEL_LEGACY}."
            ;;
        11 ) installoption=11
            output "Вы выбрали обновление  daemon до ${DAEMON_LEGACY}."
            ;;
        12 ) installoption=12
            output "Вы выбрали миграцию daemon ${DAEMON_LEGACY} в wings ${WINGS}."
            ;;
        13 ) installoption=13
            output "Вы выбрали обновление панели до ${PANEL} и миграцию в wings ${WINGS}."
            ;;
        14 ) installoption=14
            output "Вы выбрали обновление панели до ${PANEL} и daemon до ${DAEMON_LEGACY}."
            ;;
        15 ) installoption=15
            output "Вы выбрали обновление автономного SFTP."
            ;;
        16 ) installoption=16
            output "Вы активировали совместимость мобильного приложения."
            ;;
        17 ) installoption=17
            output "Вы выбрали обновление совместимости мобильного приложения."
            ;;
        18 ) installoption=18
            output "Вы выбрали установку или обновление phpMyAdmin ${PHPMYADMIN}."
            ;;
        19 ) installoption=19
            output "Вы выбрали установку хоста базы данных."
            ;;
        20 ) installoption=20
            output "Вы решили изменить Pterodactyl ${PANEL_LEGACY}."
            ;;
        21 ) installoption=21
            output "Вы выбрали сброс пароля root MariaDB."
            ;;
        22 ) installoption=22
            output "Вы выбрали сброс пароля базы данных."
            ;;
        * ) output "Вы ввели неверный выбор."
            install_options
    esac
}

webserver_options() {
    output "Выберите, какой веб-сервер вы хотите использовать:\n[1] Nginx (рекомендуется).\n[2]  Apache2/httpd."
    read -r choice
    case $choice in
        1 ) webserver=1
            output "Вы выбрали Nginx."
            output ""
            ;;
        2 ) webserver=2
            output "Вы выбрали Apache2/httpd."
            output ""
            ;;
        * ) output "Вы ввели неверный выбор."
            webserver_options
    esac
}

theme_options() {
    output "Хотите установить одну из тем Fonix?"
    warn "СЕЙЧАС FONIX НЕ ОБНОВЛЯЕТ СВОЮ ТЕМУ ДО 0.7.19, ЧТОБЫ ИСПРАВИТЬ XSS EXPLOIT В PTERODACTYL <= 0.7.18. НЕ ИСПОЛЬЗУЙТЕ ЭТО. НАСТОЯТЕЛЬНО РЕКОМЕНДУЮ ВЫБРАТЬ [1]."
    output "[1] НЕТ."
    output "[2] Super Pink и Fluffy."
    output "[3] Tango Twist."
    output "[4] Blue Brick."
    output "[5] Minecraft Madness."
    output "[6] Lime Stitch."
    output "[7] Red Ape."
    output "[8] BlackEnd Space."
    output "[9] Nothing But Graphite."
    output ""
    output "Вы можете узнать о темах Fonix здесь: https://github.com/TheFonix/Pterodactyl-Themes"
    read -r choice
    case $choice in
        1 ) themeoption=1
            output "Вы выбрали для установки стандартную тему Pterodactyl."
            output ""
            ;;
        2 ) themeoption=2
            output "Вы выбрали для установки Fonix's Super Pink и Fluffy."
            output ""
            ;;
        3 ) themeoption=3
            output "Вы выбрали для установки Fonix's Tango Twist."
            output ""
            ;;
        4 ) themeoption=4
            output "Вы выбрали для установки Fonix's Blue Brick."
            output ""
            ;;
        5 ) themeoption=5
            output "Вы выбрали для установки Fonix's Minecraft Madness."
            output ""
            ;;
        6 ) themeoption=6
            output "Вы выбрали для установки Fonix's Lime Stitch."
            output ""
            ;;
        7 ) themeoption=7
            output "Вы выбрали для установки Fonix's Red Ape."
            output ""
            ;;
        8 ) themeoption=8
            output "Вы выбрали для установки Fonix's BlackEnd Space."
            output ""
            ;;
        9 ) themeoption=9
            output "Вы выбрали для установки Fonix's Nothing But Graphite."
            output ""
            ;;
        * ) output "Вы ввели неверный выбор."
            theme_options
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
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
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

theme() {
    output "Инициализация установки темы..."
    cd /var/www/pterodactyl || exit
    if [ "$themeoption" = "1" ]; then
        output "Сохранение стандартной темы Pterodactyl."
    elif [ "$themeoption" = "2" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/PinkAnFluffy/build.sh | sh
    elif [ "$themeoption" = "3" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/TangoTwist/build.sh | sh
    elif [ "$themeoption" = "4" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlueBrick/build.sh | sh
    elif [ "$themeoption" = "5" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/MinecraftMadness/build.sh | sh
    elif [ "$themeoption" = "6" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/LimeStitch/build.sh | sh
    elif [ "$themeoption" = "7" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/RedApe/build.sh | sh
    elif [ "$themeoption" = "8" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlackEndSpace/build.sh | sh
    elif [ "$themeoption" = "9" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/NothingButGraphite/build.sh | sh
    fi
    php artisan view:clear
    php artisan cache:clear
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
            add-apt-repository -y ppa:chris-lea/redis-server
            if [ "$dist_version" != "20.04" ]; then
                add-apt-repository -y ppa:certbot/certbot
                add-apt-repository -y ppa:nginx/development
            fi
	        apt -y install tuned dnsutils
                tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            if [ "$dist_version" = "10" ]; then
                apt -y install dirmngr
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
                apt -y install tuned
                tuned-adm profile latency-performance
        fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
        apt-get -y install curl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ]; then
        if  [ "$lsb_dist" =  "fedora" ] ; then
            if [ "$dist_version" = "34" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-34.rpm
            elif [ "$dist_version" = "33" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-33.rpm
            fi
            dnf -y install dnf-plugins-core python2 libsemanage-devel
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
	    dnf -y module enable nginx:mainline/common
	    dnf -y module enable mariadb:14/server
        elif  [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
            dnf -y install epel-release boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
    fi
            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
            yum -y install policycoreutils-python yum-utils libsemanage-devel
            yum-config-manager --enable remi
            yum-config-manager --enable remi-php80
	        yum-config-manager --enable nginx-mainline
	        yum-config-manager --enable mariadb
        elif  [ "$lsb_dist" =  "rhel" ] && [ "$dist_version" = "8" ]; then
            dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            dnf -y install boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
        fi
        yum -y install yum-utils tuned
        tuned-adm profile latency-performance
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
        yum -y install curl bind-utils cronie
    fi
}

repositories_setup_0.7.19(){
    output "Настройка репозиториев ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common dnsutils gpg-agent
        dpkg --remove-architecture i386
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update
	  curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            add-apt-repository -y ppa:chris-lea/redis-server
            if [ "$dist_version" != "20.04" ]; then
                add-apt-repository -y ppa:certbot/certbot
                add-apt-repository -y ppa:nginx/development
            fi
	        apt -y install tuned dnsutils
                tuned-adm profile latency-performance
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list
            if [ "$dist_version" = "10" ]; then
                apt -y install dirmngr
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
                apt -y install tuned
                tuned-adm profile latency-performance
        fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
        apt-get -y install curl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ]; then
        if  [ "$lsb_dist" =  "fedora" ] ; then
            if [ "$dist_version" = "34" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-34.rpm
            elif [ "$dist_version" = "33" ]; then
                dnf -y install  http://rpms.remirepo.net/fedora/remi-release-33.rpm
            fi
            dnf -y install dnf-plugins-core python2 libsemanage-devel
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
	    dnf -y module enable nginx:mainline/common
	    dnf -y module enable mariadb:14/server
        elif  [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
            dnf -y install epel-release boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
    fi
            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.5/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
            yum -y install policycoreutils-python yum-utils libsemanage-devel
            yum-config-manager --enable remi
            yum-config-manager --enable remi-php80
	        yum-config-manager --enable nginx-mainline
	        yum-config-manager --enable mariadb
        elif  [ "$lsb_dist" =  "rhel" ] && [ "$dist_version" = "8" ]; then
            dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            dnf -y install boost-program-options
            dnf -y install http://rpms.remirepo.net/enterprise/remi-release-8.rpm
            dnf config-manager --set-enabled remi
            dnf -y module enable php:remi-8.0
            dnf -y module enable nginx:mainline/common
	    curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
	    dnf config-manager --set-enabled mariadb
        fi
        yum -y install yum-utils tuned
        tuned-adm profile latency-performance
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
        yum -y install curl bind-utils cronie
    fi
}

install_dependencies(){
    output "Установка зависимостей ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        if [ "$webserver" = "1" ]; then
            apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} nginx tar unzip git redis-server nginx git wget expect
        elif [ "$webserver" = "2" ]; then
             apt -y install php8.0 php8.0-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} curl tar unzip git redis-server apache2 libapache2-mod-php8.0 redis-server git wget expect
        fi
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated mariadb-server"
    else
	if [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$dist_version" = "8" ]; then
	        dnf -y install MariaDB-server MariaDB-client --disablerepo=AppStream
        fi
	else
	    dnf -y install MariaDB-server
	fi
	dnf -y module install php:remi-8.0
        if [ "$webserver" = "1" ]; then
            dnf -y install redis nginx git policycoreutils-python-utils unzip wget expect jq php-mysql php-zip php-bcmath tar
        elif [ "$webserver" = "2" ]; then
            dnf -y install redis httpd git policycoreutils-python-utils mod_ssl unzip wget expect jq php-mysql php-zip php-mcmath tar
        fi
    fi

    output "Включение служб ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        systemctl enable redis-server
        service redis-server start
        systemctl enable php8.0-fpm
        service php8.0-fpm start
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        systemctl enable redis
        service redis start
        systemctl enable php-fpm
        service php-fpm start
    fi

    systemctl enable cron
    systemctl enable mariadb

    if [ "$webserver" = "1" ]; then
        systemctl enable nginx
        service nginx start
    elif [ "$webserver" = "2" ]; then
        if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            systemctl enable apache2
            service apache2 start
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            systemctl enable httpd
            service httpd start
        fi
    fi
    service mysql start
}

install_dependencies_0.7.19(){
    output "Установка зависимостей ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        if [ "$webserver" = "1" ]; then
            apt-get -y install php7.3 php7.3-cli php7.3-gd php7.3-mysql php7.3-pdo php7.3-mbstring php7.3-tokenizer php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip curl tar unzip git redis-server nginx git wget expect
        elif [ "$webserver" = "2" ]; then
            apt-get -y install php7.3 php7.3-cli php7.3-gd php7.3-mysql php7.3-pdo php7.3-mbstring php7.3-tokenizer php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip curl tar unzip git redis-server apache2 libapache2-mod-php7.3 redis-server git wget expect
        fi
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-unauthenticated mariadb-server"
    else
	if [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$dist_version" = "8" ]; then
	        dnf -y install MariaDB-server MariaDB-client --disablerepo=AppStream
        fi
	else
	    dnf -y install MariaDB-server
	fi
	dnf -y module install php:remi-7.3
        if [ "$webserver" = "1" ]; then
            dnf -y install redis nginx git policycoreutils-python-utils unzip wget expect jq php-mysql php-zip php-bcmath tar
        elif [ "$webserver" = "2" ]; then
            dnf -y install redis httpd git policycoreutils-python-utils mod_ssl unzip wget expect jq php-mysql php-zip php-mcmath tar
        fi
    fi

    output "Включение служб ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        systemctl enable redis-server
        service redis-server start
        systemctl enable php7.3-fpm
        service php7.3-fpm start
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        systemctl enable redis
        service redis start
        systemctl enable php-fpm
        service php-fpm start
    fi

    systemctl enable cron
    systemctl enable mariadb

    if [ "$webserver" = "1" ]; then
        systemctl enable nginx
        service nginx start
    elif [ "$webserver" = "2" ]; then
        if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            systemctl enable apache2
            service apache2 start
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            systemctl enable httpd
            service httpd start
        fi
    fi
    service mysql start
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
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, EXECUTE, PROCESS, RELOAD, LOCK TABLES, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Привязка MariaDB/MySQL к 0.0.0.0."
        if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	else
		output 'Не удалось обнаружить файл конфигурации MySQL! Обратитесь в службу поддержки.'
	fi

    output "Загрузка Pterodactyl..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Установка Pterodactyl..."
    if [ "$installoption" = "2" ] || [ "$installoption" = "6" ]; then
    	curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer --version=1.10.16
    else
        curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    fi
    cp .env.example .env
    /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/New_York --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "Чтобы использовать внутреннюю отправку почты PHP, выберите [mail]. Чтобы использовать собственный SMTP-сервер, выберите [smtp]. Рекомендуется шифрование TLS."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            chown -R nginx:nginx * /var/www/pterodactyl
        elif [ "$webserver" = "2" ]; then
            chown -R apache:apache * /var/www/pterodactyl
        fi
	semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi

    output "Создание слушателей очереди панели ..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    service cron restart

    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        elif [ "$webserver" = "2" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=apache
Group=apache
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        fi
        setsebool -P httpd_can_network_connect 1
	setsebool -P httpd_execmem 1
	setsebool -P httpd_unified 1
    fi
    sudo systemctl daemon-reload
    systemctl enable pteroq.service
    systemctl start pteroq
}

install_pterodactyl_0.7.19() {
    output "Создание баз данных и установка пароля root ..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, EXECUTE, PROCESS, RELOAD, LOCK TABLES, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Привязка MariaDB/MySQL к 0.0.0.0."
        if grep -Fqs "bind-address" /etc/mysql/mariadb.conf.d/50-server.cnf ; then
		sed -i -- '/bind-address/s/#//g' /etc/mysql/mariadb.conf.d/50-server.cnf
 		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/mysql/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	elif grep -Fqs "bind-address" /etc/my.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/my.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
    	elif grep -Fqs "bind-address" /etc/mysql/my.conf.d/mysqld.cnf ; then
        	sed -i -- '/bind-address/s/#//g' /etc/mysql/my.conf.d/mysqld.cnf
		sed -i -- '/bind-address/s/127.0.0.1/0.0.0.0/g' /etc/mysql/my.conf.d/mysqld.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	else
		output 'Не удалось обнаружить файл конфигурации MySQL! Обратитесь в службу поддержки.'
	fi

    output "Загрузка Pterodactyl..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl || exit
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/${PANEL_LEGACY}/panel.tar.gz
    tar --strip-components=1 -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Установка Pterodactyl..."
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    cp .env.example .env
    /usr/local/bin/composer install --no-dev --optimize-autoloader
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/New_York --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "Чтобы использовать внутреннюю отправку почты PHP, выберите [mail]. Чтобы использовать собственный SMTP-сервер, выберите [smtp]. Рекомендуется шифрование TLS."
    php artisan p:environment:mail
    php artisan migrate --seed --force
    php artisan p:user:make --email=$email --admin=1
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            chown -R nginx:nginx * /var/www/pterodactyl
        elif [ "$webserver" = "2" ]; then
            chown -R apache:apache * /var/www/pterodactyl
        fi
	semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi

    output "Создание слушателей очереди панели ..."
    (crontab -l ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1")| crontab -
    service cron restart

    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        elif [ "$webserver" = "2" ]; then
            cat > /etc/systemd/system/pteroq.service <<- 'EOF'
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=apache
Group=apache
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
[Install]
WantedBy=multi-user.target
EOF
        fi
        setsebool -P httpd_can_network_connect 1
	setsebool -P httpd_execmem 1
	setsebool -P httpd_unified 1
    fi
    sudo systemctl daemon-reload
    systemctl enable pteroq.service
    systemctl start pteroq
}

upgrade_pterodactyl(){
    cd /var/www/pterodactyl || exit
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Ваша панель успешно обновлена до версии ${PANEL}"
    php artisan up
    php artisan queue:restart
}

upgrade_pterodactyl_1.0(){
    cd /var/www/pterodactyl || exit
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL}/panel.tar.gz | tar --strip-components=1 -xzv
    rm -rf $(find app public resources -depth | head -n -1 | grep -Fv "$(tar -tf panel.tar.gz)")
    tar -xzvf panel.tar.gz && rm -f panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Ваша панель успешно обновлена до версии ${PANEL}"
    php artisan up
    php artisan queue:restart
}

upgrade_pterodactyl_0.7.19(){
    cd /var/www/pterodactyl || exit
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/${PANEL_LEGACY}/panel.tar.gz | tar --strip-components=1 -xzv
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan config:clear
    php artisan migrate --force
    php artisan db:seed --force
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Ваша панель успешно обновлена до версии ${PANEL_LEGACY}."
    php artisan up
    php artisan queue:restart
}

nginx_config() {
    output "Отключение конфигурации по умолчанию ..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка веб-сервера Nginx ..."

echo '
server_tokens off;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
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
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;
    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
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
    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        sed -i 's/http2//g' /etc/nginx/sites-available/pterodactyl.conf
    fi
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

nginx_config_0.7.19() {
    output "Отключение конфигурации по умолчанию ..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка веб-сервера Nginx ..."

echo '
server_tokens off;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
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
    ssl_protocols TLSv1.2;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256';
    ssl_prefer_server_ciphers on;
    # See https://hstspreload.org/ before uncommenting the line below.
    # add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy same-origin;
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
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
    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        sed -i 's/http2//g' /etc/nginx/sites-available/pterodactyl.conf
    fi
    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

apache_config() {
    output "Отключение конфигурации по умолчанию ..."
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка веб-сервера Apache2 ..."
echo '
<VirtualHost *:80>
  ServerName '"$FQDN"'
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
  ServerName '"$FQDN"'
  DocumentRoot "/var/www/pterodactyl/public"
  AllowEncodedSlashes On
  php_value upload_max_filesize 100M
  php_value post_max_size 100M
  <Directory "/var/www/pterodactyl/public">
    AllowOverride all
  </Directory>
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/'"$FQDN"'/privkey.pem
</VirtualHost>
' | sudo -E tee /etc/apache2/sites-available/pterodactyl.conf >/dev/null 2>&1

    ln -s /etc/apache2/sites-available/pterodactyl.conf /etc/apache2/sites-enabled/pterodactyl.conf
    a2enmod ssl
    a2enmod rewrite
    service apache2 restart
}

nginx_config_redhat(){
    output "Настройка веб-сервера Nginx ..."

echo '
server_tokens off;
server {
    listen 80 default_server;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2 default_server;
    server_name '"$FQDN"';
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;
    # strengthen ssl security
    ssl_certificate /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/'"$FQDN"'/privkey.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";

    # See the link below for more SSL information:
    #     https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
    #
    # ssl_dhparam /etc/ssl/certs/dhparam.pem;
    # Add headers to serve security related headers
    add_header Strict-Transport-Security "max-age=15768000; preload;";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header Content-Security-Policy "frame-ancestors 'self'";
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
    semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
    restorecon -R /var/www/pterodactyl
}

apache_config_redhat() {
    output "Настройка веб-сервера Apache2 ..."
echo '
<VirtualHost *:80>
  ServerName '"$FQDN"'
  RewriteEngine On
  RewriteCond %{HTTPS} !=on
  RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
  ServerName '"$FQDN"'
  DocumentRoot "/var/www/pterodactyl/public"
  AllowEncodedSlashes On
  <Directory "/var/www/pterodactyl/public">
    AllowOverride all
  </Directory>
  SSLEngine on
  SSLCertificateFile /etc/letsencrypt/live/'"$FQDN"'/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/'"$FQDN"'/privkey.pem
</VirtualHost>
' | sudo -E tee /etc/httpd/conf.d/pterodactyl.conf >/dev/null 2>&1
    service httpd restart
}

php_config(){
    output "Настройка сокета PHP ..."
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
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "3" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "4" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                nginx_config_0.7.19
            elif [ "$webserver" = "2" ]; then
                apache_config
            fi
        fi
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            php_config
            nginx_config_redhat
	    chown -R nginx:nginx /var/lib/php/session
        elif [ "$webserver" = "2" ]; then
            apache_config_redhat
        fi
    fi
}

setup_pterodactyl(){
    install_dependencies
    install_pterodactyl
    ssl_certs
    webserver_config
}


setup_pterodactyl_0.7.19(){
    install_dependencies_0.7.19
    install_pterodactyl_0.7.19
    ssl_certs
    webserver_config
    theme
}

install_wings() {
    cd /root || exit
    output "Установка зависимостей Pterodactyl Wings ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install curl tar unzip
    fi

    output "Установка Docker"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash

    service docker start
    systemctl enable docker
    output "Включение поддержки SWAP для Docker."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    output "Установка Pterodactyl wings..."
    mkdir -p /etc/pterodactyl /srv/daemon-data
    cd /etc/pterodactyl || exit
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable wings
    systemctl start wings
    output "Wings ${WINGS} установлен в вашей системе."
}

install_daemon() {
    cd /root || exit
    output "Установка зависимостей Pterodactyl Daemon ..."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install curl tar unzip
    fi

    output "Установка Docker"
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash

    service docker start
    systemctl enable docker
    output "Включение поддержки SWAP для Docker и установка NodeJS ..."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        update-grub
        curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
            if [ "$lsb_dist" =  "ubuntu" ] && [ "$dist_version" = "20.04" ]; then
                apt -y install nodejs make gcc g++
                npm install node-gyp
            elif [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "10" ]; then
                apt -y install nodejs make gcc g++
            else
                apt -y install nodejs make gcc g++ node-gyp
            fi
        apt-get -y update
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ]; then
        grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
        if [ "$lsb_dist" =  "fedora" ]; then
            dnf -y module install nodejs:12/minimal
	          dnf install -y tar unzip make gcc gcc-c++ python2
	      fi
	  elif [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "8" ]; then
	      dnf -y module install nodejs:12/minimal
	      dnf install -y tar unzip make gcc gcc-c++ python2
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
    fi
    output "Установка Pterodactyl daemon..."
    mkdir -p /srv/daemon /srv/daemon-data
    cd /srv/daemon || exit
    curl -L https://github.com/pterodactyl/daemon/releases/download/${DAEMON_LEGACY}/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install --only=production --no-audit --unsafe-perm
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
[Service]
User=root
#Group=some_group
WorkingDirectory=/srv/daemon
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/bin/node /srv/daemon/src/index.js
Restart=on-failure
StartLimitInterval=600
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings

    output "Установка Daemon почти завершена, перейдите на панель и получите команду «Автоматическое развертывание» на вкладке конфигурации узла."
    output "Вставьте команду автоматического развертывания ниже: "
    read AUTODEPLOY
    ${AUTODEPLOY}
    service wings start
    output "Daemon ${DAEMON_LEGACY} установлен в вашей системе."
}

migrate_wings(){
    mkdir -p /etc/pterodactyl
    curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/download/${WINGS}/wings_linux_amd64
    chmod u+x /usr/local/bin/wings
    systemctl stop wings
    rm -rf /srv/daemon
    systemctl disable --now pterosftp
    rm /etc/systemd/system/pterosftp.service
    bash -c 'cat > /etc/systemd/system/wings.service' <<-'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now wings
    output "Ваш daemon перенесен в wings."
}

upgrade_daemon(){
    cd /srv/daemon
    service wings stop
    curl -L https://github.com/pterodactyl/daemon/releases/download/${DAEMON_LEGACY}/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install -g npm
    npm install --only=production --no-audit --unsafe-perm
    service wings restart
    output "Ваш daemon обновлен до версии ${DAEMON_LEGACY}."
    output "npm обновлен до последней версии."
}

install_standalone_sftp(){
    os_check
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install jq
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ]; then
        yum -y install jq
    fi
    if [ ! -f /srv/daemon/config/core.json ]; then
        warn "ПЕРЕД УСТАНОВКОЙ АВТОНОМНОГО SFTP-СЕРВЕРА ВЫ ДОЛЖНЫ НАСТРОИТЬ ДЕЙМОН ДОЛЖНЫМ ОБРАЗОМ!"
        exit 11
    fi
    cd /srv/daemon
    if [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "null" ]; then
        output "Обновление конфигурации для включения sftp-сервера ..."
        cat /srv/daemon/config/core.json | jq '.sftp.enabled |= false' > /tmp/core
        cat /tmp/core > /srv/daemon/config/core.json
        rm -rf /tmp/core
    elif [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "false" ]; then
       output "Конфигурация уже настроена для SFTP-сервера."
    else 
       output "Возможно, вы намеренно установили для SFTP значение true, что приведет к сбою."
    fi
    service wings restart
    output "Установка автономного SFTP-сервера ..."
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.5/sftp-server
    chmod +x sftp-server
    bash -c 'cat > /etc/systemd/system/pterosftp.service' <<-'EOF'
[Unit]
Description=Pterodactyl Standalone SFTP Server
After=wings.service
[Service]
User=root
WorkingDirectory=/srv/daemon
LimitNOFILE=4096
PIDFile=/var/run/wings/sftp.pid
ExecStart=/srv/daemon/sftp-server
Restart=on-failure
StartLimitInterval=600
[Install]
WantedBy=multi-user.target
EOF
    systemctl enable pterosftp
    service pterosftp restart
}

upgrade_standalone_sftp(){
    output "Отключение автономного сервера SFTP ..."
    service pterosftp stop
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.5/sftp-server
    chmod +x sftp-server
    service pterosftp start
    output "Ваш автономный сервер SFTP успешно обновлен до версии 1.0.5."
}

install_mobile(){
    cd /var/www/pterodactyl || exit
    composer config repositories.cloud composer https://packages.pterodactyl.cloud
    composer require pterodactyl/mobile-addon --update-no-dev --optimize-autoloader
    php artisan migrate --force
}

upgrade_mobile(){
    cd /var/www/pterodactyl || exit
    composer update pterodactyl/mobile-addon
    php artisan migrate --force
}

install_phpmyadmin(){
    output "Установка phpMyAdmin..."
    cd /var/www/pterodactyl/public || exit
    rm -rf phpmyadmin
    wget https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN}/phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    unzip phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    mv phpMyAdmin-${PHPMYADMIN}-all-languages phpmyadmin
    rm -rf phpMyAdmin-${PHPMYADMIN}-all-languages.zip
    cd /var/www/pterodactyl/public/phpmyadmin || exit

    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    BOWFISH=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 34 | head -n 1`
    bash -c 'cat > /var/www/pterodactyl/public/phpmyadmin/config.inc.php' <<EOF
<?php
/* Servers configuration */
\$i = 0;
/* Server: MariaDB [1] */
\$i++;
\$cfg['Servers'][\$i]['verbose'] = 'MariaDB';
\$cfg['Servers'][\$i]['host'] = '${SERVER_IP}';
\$cfg['Servers'][\$i]['port'] = '';
\$cfg['Servers'][\$i]['socket'] = '';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['user'] = 'root';
\$cfg['Servers'][\$i]['password'] = '';
/* End of servers configuration */
\$cfg['blowfish_secret'] = '${BOWFISH}';
\$cfg['DefaultLang'] = 'en';
\$cfg['ServerDefault'] = 1;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['CaptchaLoginPublicKey'] = '6LcJcjwUAAAAAO_Xqjrtj9wWufUpYRnK6BW8lnfn';
\$cfg['CaptchaLoginPrivateKey'] = '6LcJcjwUAAAAALOcDJqAEYKTDhwELCkzUkNDQ0J5'
?>    
EOF
    output "Установка завершена."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        chown -R www-data:www-data * /var/www/pterodactyl
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
}

ssl_certs(){
    output "Установка Let's Encrypt и создание SSL-сертификата ..."
    cd /root || exit
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install certbot
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install certbot
    fi
    if [ "$webserver" = "1" ]; then
        service nginx stop
    elif [ "$webserver" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            service apache2 stop
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            service httpd stop
        fi
    fi

    certbot certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
    
    if [ "$installoption" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            ufw deny 80
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
            firewall-cmd --permanent --remove-port=80/tcp
            firewall-cmd --reload
        fi
    else
        if [ "$webserver" = "1" ]; then
            service nginx restart
        elif [ "$webserver" = "2" ]; then
            if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
                service apache2 restart
            elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
                service httpd restart
            fi
        fi
    fi
       
        if [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "3" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "4" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        fi
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --post-hook "service httpd restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --post-hook "service httpd restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "3" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "firewall-cmd --add-port=80/tcp && firewall-cmd --reload" --pre-hook "service wings stop" --post-hook "firewall-cmd --remove-port=80/tcp && firewall-cmd --reload" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "4" ]; then
            (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "firewall-cmd --add-port=80/tcp && firewall-cmd --reload" --pre-hook "service wings stop" --post-hook "firewall-cmd --remove-port=80/tcp && firewall-cmd --reload" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "5" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        elif [ "$installoption" = "6" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo '0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1')| crontab -
            fi
        fi
    fi
}

firewall(){
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install iptables
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "cloudlinux" ]; then
        yum -y install iptables
    fi

    curl -sSL https://raw.githubusercontent.com/tommytran732/Anti-DDOS-Iptables/master/iptables-no-prompt.sh | sudo bash
    block_icmp
    javapipe_kernel
    output "Настройка Fail2Ban ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install fail2ban
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install fail2ban
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

    output "Настройка брандмауэра ..."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install ufw
        ufw allow 22
        if [ "$installoption" = "1" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "2" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 3306
        elif [ "$installoption" = "3" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "4" ]; then
            ufw allow 80
            ufw allow 8080
            ufw allow 2022
        elif [ "$installoption" = "5" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        elif [ "$installoption" = "6" ]; then
            ufw allow 80
            ufw allow 443
            ufw allow 8080
            ufw allow 2022
            ufw allow 3306
        fi
        yes |ufw enable 
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install firewalld
        systemctl enable firewalld
        systemctl start firewalld
        if [ "$installoption" = "1" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "2" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent
            firewall-cmd --add-service=mysql --permanent
        elif [ "$installoption" = "3" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
        elif [ "$installoption" = "4" ]; then
            firewall-cmd --permanent --add-service=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
        elif [ "$installoption" = "5" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
        elif [ "$installoption" = "6" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --permanent --add-service=mysql
        fi
    fi
}

block_icmp(){
    output "Блокировать пакеты ICMP (Ping)?"
    output "Вы должны выбрать [1], если вы не используете систему мониторинга, и [2] в противном случае."
    output "[1] Да."
    output "[2] Нет."
    read icmp
    case $icmp in
        1 ) /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP
            (crontab -l ; echo "@reboot /sbin/iptables -t mangle -A PREROUTING -p icmp -j DROP >> /dev/null 2>&1")| crontab - 
            ;;
        2 ) output "Правило пропуска ..."
            ;;
        * ) output "Вы ввели неверный выбор."
            block_icmp
    esac    
}

javapipe_kernel(){
    output "Применить конфигурации ядра JavaPipe (https://javapipe.com/blog/iptables-ddos-protection)?"
    output "[1] да."
    output "[2] Нет."
    read javapipe
    case $javapipe in
        1)  sh -c "$(curl -sSL https://raw.githubusercontent.com/tommytran732/Anti-DDOS-Iptables/master/javapipe_kernel.sh)"
            ;;
        2)  output "Изменения ядра JavaPipe не применяются."
            ;;
        * ) output "Вы ввели неверный выбор."
            javapipe_kernel
    esac 
}

install_database() {
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install mariadb-server
	elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if [ "$dist_version" = "8" ]; then
	        dnf -y install MariaDB-server MariaDB-client --disablerepo=AppStream
        fi
	else 
	    dnf -y install MariaDB-server
	fi

    output "Создание баз данных и установка пароля root ..."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="SET old_passwords=0;"
    Q3="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q4="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, EXECUTE, PROCESS, RELOAD, LOCK TABLES, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q5="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q6="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q7="DELETE FROM mysql.user WHERE User='';"
    Q8="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q9="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}"
    mysql -u root -e "$SQL"

    output "Привязка MariaDB/MySQL к 0.0.0.0."
	if [ -f /etc/mysql/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/mysql/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	elif [ -f /etc/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
    	elif [ -f /etc/mysql/my.conf.d/mysqld.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/my.cnf
		output 'Перезапуск MySQL процесса ...'
		service mysql restart
	else 
		output 'Файл my.cnf не найден! Обратитесь в службу поддержки.'
	fi

    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        yes | ufw allow 3306
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "rhel" ]; then
        firewall-cmd --permanent --add-service=mysql
        firewall-cmd --reload
    fi 

    broadcast_database
}

database_host_reset(){
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="SET old_passwords=0;"
    Q1="SET PASSWORD FOR 'admin'@'$SERVER_IP' = PASSWORD('$adminpassword');"
    Q2="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}"
    mysql mysql -e "$SQL"
    output "Информация о новом хосте базы данных:"
    output "Хост: $SERVER_IP"
    output "Порт: 3306"
    output "Пользователь: admin"
    output "Пароль: $adminpassword"
}

broadcast(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        broadcast_database
    fi
    output "###############################################################"
    output "БРАНДМАУЭР ИНФОРМАЦИЯ"
    output ""
    output "По умолчанию все ненужные порты заблокированы."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        output "Используйте 'ufw allow <порт>' для включения нужных портов."
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] && [ "$dist_version" != "8" ]; then
        output "Используйте 'firewall-cmd --permanent --add-port=<port>/tcp', чтобы включить нужные порты"
    fi
    output "###############################################################"
    output ""
}

broadcast_database(){
        output "###############################################################"
        output "MARIADB/MySQL ИНФОРМАЦИЯ"
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

#Execution
preflight
install_options
case $installoption in 
        1)   webserver_options
             repositories_setup
             required_infos
             firewall
             setup_pterodactyl
             broadcast
	     broadcast_database
             ;;
        2)   webserver_options
             theme_options
             repositories_setup_0.7.19
             required_infos
             firewall
             setup_pterodactyl_0.7.19
             broadcast
             ;;
        3)   repositories_setup
             required_infos
             firewall
             ssl_certs
             install_wings
             broadcast
	     broadcast_database
             ;;
        4)   repositories_setup_0.7.19
             required_infos
             firewall
             ssl_certs
             install_daemon
             broadcast
             ;;
        5)   webserver_options
             repositories_setup
             required_infos
             firewall
             ssl_certs
             setup_pterodactyl
             install_wings
             broadcast
             ;;
        6)   webserver_options
             theme_options
             repositories_setup_0.7.19
             required_infos
             firewall
             setup_pterodactyl_0.7.19
             install_daemon
             broadcast
             ;;
        7)   install_standalone_sftp
             ;;
        8)   upgrade_pterodactyl
             ;;
        9)   upgrade_pterodactyl_1.0
             ;;
        10)  theme_options
             upgrade_pterodactyl_0.7.19
             theme
             ;;
        11)  upgrade_daemon
             ;;
        12)  migrate_wings
             ;;
        13)  upgrade_pterodactyl_1.0
             migrate_wings
             ;;
        14)  theme_options
             upgrade_pterodactyl_0.7.19
             theme
             upgrade_daemon
             ;;
        15)  upgrade_standalone_sftp
             ;;
        16)  install_mobile
             ;;
        17)  upgrade_mobile
             ;;
        18)  install_phpmyadmin
             ;;
        19)  repositories_setup
             install_database
             ;;
        20)  theme_options
             if [ "$themeoption" = "1" ]; then
             	upgrade_pterodactyl_0.7.19
             fi
             theme
            ;;
        21) curl -sSL https://raw.githubusercontent.com/tommytran732/MariaDB-Root-Password-Reset/master/mariadb-104.sh | sudo bash
            ;;
        22) database_host_reset
            ;;
esac
