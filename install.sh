#!/bin/bash

output(){
    echo -e '\e[36m'$1'\e[0m';
}

warn(){
    echo -e '\e[31m'$1'\e[0m';
}

preflight(){
    output "Сценарий установки и обновления птеродактиля"
    output ""

    output "Обратите внимание, что этот скрипт предназначен для установки на новую ОС. Установка его на не свежую ОС может вызвать проблемы."
    output "Автоматическое обнаружение операционной системы."
    if [ -r /etc/os-release ]; then
        lsb_dist="$(. /etc/os-release && echo "$ID")"
        dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    else
        exit 1
    fi
    output "OS: $lsb_dist $dist_version обнаружено."
    output ""

    if [ "$lsb_dist" =  "ubuntu" ]; then
        if [ "$dist_version" != "19.04" ] && [ "$dist_version" != "18.10" ] && [ "$dist_version" != "18.04" ] && [ "$dist_version" != "16.04" ]; then
            output "Неподдерживаемая версия Ubuntu. Поддерживаются только Ubuntu 19.04, 18.10, 18.04, 16.04."
            exit 2
        fi
    elif [ "$lsb_dist" = "debian" ]; then
        if [ "$dist_version" != "9" ] && [ "$dist_version" != "8" ]; then
            output "Неподдерживаемая версия Debian. Поддерживаются только Debian 9 и 8."
            exit 2
        fi
    elif [ "$lsb_dist" = "fedora" ]; then
        if [ "$dist_version" != "29" ] && [ "$dist_version" != "28" ]; then
            output "Неподдерживаемая версия Fedora. Поддерживаются только Fedora 29 и 28."
            exit 2
        fi
    elif [ "$lsb_dist" = "centos" ]; then
        if [ "$dist_version" != "7" ]; then
            output "Неподдерживаемая версия CentOS. Поддерживается только CentOS 7."
            exit 2
        fi
    elif [ "$lsb_dist" = "rhel" ]; then
        if [ "$dist_version" != "7" ]&&[ "$dist_version" != "7.1" ]&&[ "$dist_version" != "7.2" ]&&[ "$dist_version" != "7.3" ]&&[ "$dist_version" != "7.4" ]&&[ "$dist_version" != "7.5" ]&&[ "$dist_version" != "7.6" ]; then
            output "Неподдерживаемая версия RHEL. Поддерживается только RHEL 7."
            exit 2
        fi
    elif [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "debian" ] && [ "$lsb_dist" != "centos" ] && [ "$lsb_dist" != "rhel" ]; then
        output "Неподдерживаемая операционная система."
        output ""
        output "Поддерживаемые ОС:"
        output "Ubuntu: 19.04 18.10, 18.04, 16.04"
        output "Debian: 9, 8"
        output "Fedora: 29, 28"
        output "CentOS: 7"
        output "RHEL: 7"
        exit 2
    fi

    if [ "$EUID" -ne 0 ]; then
        output "Пожалуйста, запустите от имени пользователя root"
        exit 3
    fi

    output "Автоматическое обнаружение архитектуры инициализировано."
    MACHINE_TYPE=`uname -m`
    if [ ${MACHINE_TYPE} == 'x86_64' ]; then
        output "64-битный сервер обнаружен! Поехали дальше."
        output ""
    else
        output "Обнаружена неподдерживаемая архитектура! Пожалуйста, переключитесь на 64-битный (x86_64)."
        exit 4
    fi

    output "Автоматическое обнаружение виртуализации."
    if [ "$lsb_dist" =  "ubuntu" ]; then
        apt-get update --fix-missing
        apt-get -y install software-properties-common
        add-apt-repository -y universe
        apt-get -y install virt-what
    elif [ "$lsb_dist" =  "debian" ]; then
        apt update --fix-missing
        apt-get -y install software-properties-common virt-what wget
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install virt-what wget
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
        warn "При выделении узла используйте внутренний ip, поскольку Google Cloud использует NAT."
        warn "Возобновление через 10 секунд."
        sleep 10
    else
        output "Виртуализация: $virt_serv обнаружено."
    fi
    output ""
    if [ "$virt_serv" != "" ] && [ "$virt_serv" != "kvm" ] && [ "$virt_serv" != "vmware" ] && [ "$virt_serv" != "hyperv" ] && [ "$virt_serv" != "openvz lxc" ] && [ "$virt_serv" != "xen xen-hvm" ] && [ "$virt_serv" != "xen xen-hvm aws" ]; then
        warn "Unsupported Virtualization method. Please consult with your provider whether your server can run Docker or not. Proceed at your own risk."
        warn "No support would be given if your server breaks at any point in the future."
        warn "Proceed?\n[1] Yes.\n[2] No."
        read choice
        case $choice in 
            1)  output "Процесс..."
                ;;
            2)  output "Отмена установки..."
                exit 5
                ;;
        esac
        output ""
    fi

    output "Обнаружение ядра инициализировано."
    if echo $(uname -r) | grep -q xxxx; then
        output "Ядро OVH обнаружено. Скрипт не будет работать. Пожалуйста, установите ваш сервер с общим ядром / дистрибутивом."
        output "Когда вы переустанавливаете свой сервер, нажмите 'custom installation' и после этого нажмите 'use distribution'."
        output "Вы также можете захотеть сделать пользовательские разделы, удалить раздел /home и дать /all оставшееся пространство."
        output "Пожалуйста, не стесняйтесь обращаться к нам, если вам нужна помощь по этому вопросу."
        exit 6
    elif echo $(uname -r) | grep -q pve; then
        output "Обнаружено ядро Proxmox LXE. Вы решили продолжить на последнем этапе, поэтому мы действуем на свой страх и риск."
        output "Продолжаем рискованную операцию..."
    elif echo $(uname -r) | grep -q stab; then
        if echo $(uname -r) | grep -q 2.6; then 
            output "OpenVZ 6 обнаружен. Этот сервер определенно не будет работать с Docker, независимо от того, что скажет ваш провайдер. Выход, чтобы избежать дальнейших повреждений."
            exit 6
        fi
    elif echo $(uname -r) | grep -q lve; then
        output "Ядро CloudLinux обнаружено. Docker не поддерживается в CloudLinux. Скрипт завершится, чтобы избежать дальнейших повреждений."
        exit 6
    elif echo $(uname -r) | grep -q gcp; then
        output "Обнаружена облачная платформа Google."
        warn "Пожалуйста, убедитесь, что у вас есть статическая настройка ip, иначе система не будет работать после перезагрузки."
        warn "Также убедитесь, что брандмауэр Google позволяет портам, необходимым для нормальной работы сервера."
        warn "При выделении узла используйте внутренний ip, поскольку Google Cloud использует NAT."
        warn "Возобновление через 10 секунд."
        sleep 10
    else
        output "Не обнаружил ни одного плохого ядра. Поехали дальше."
        output ""

    ########ANTILEAK########
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$dist_version" = "19.04" ]; then
        apt -y install docker.io
    else
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
    fi
    systemctl enable docker
    systemctl start docker
    
    ########IF USER IS LEGIT AND RERUN THE LATEST SCRIPT, IT WILL RUN docker swarm leave >/dev/null 2>&1 AND LEAVE########
    fi
    ########ANTILEAK########

    output "Пожалуйста, выберите вариант установки:"
    output "[0] Завершение работы скрипта."
    output "[1] Установка Pterodactyl panel."
    output "[2] Установка Pterodactyl daemon."
    output "[3] Установка Pterodactyl panel и daemon."
    output "[4] Установка standalone SFTP server."
    output "[5] Обновление 0.7.x panel до 0.7.17."
    output "[6] Обновление 0.6.x daemon до 0.6.13."
    output "[7] Обновление panel до 0.7.17 и daemon до 0.6.13"
    output "[8] Обновление standalone SFTP server 1.0.4."
    output "[9] Установка или Обновление phpMyAdmin 5.0.2 (Используйте это только после того, как вы установили панель.)"
    output "[10] Установка тем Pterodactyl."
    output "[11] Аварийный сброс пароля root MariaDB."
    output "[12] Аварийный сброс базы данных."
    read choice
    case $choice in
        1 ) installoption=1
            output "Вы выбрали установку только панели."
            ;;
        2 ) installoption=2
            output "Вы выбрали установку только Демона."
            ;;
        3 ) installoption=3
            output "Вы выбрали установку панели и демона."
            ;;
        4 ) installoption=4
            output "Вы выбрали установку автономного SFTP-сервера."
            ;;
        5 ) installoption=5
            output "Вы решили обновить панель."
            ;;
        6 ) installoption=6
            output "Вы решили обновить демона."
            ;;
        7 ) installoption=7
            output "Вы решили обновить и панель и демон."
            ;;
        8 ) installoption=8
            output "Вы выбрали обновить автономный SFTP."
            ;;
        9 ) installoption=9
            output "Вы выбрали установку или обновления phpMyAdmin."
            ;;
        10 ) installoption=10
            output "Вы решили изменить тему Pterodactyl."
            ;;
        11 ) installoption=11
            output "Вы выбрали сброс пароля root MariaDB."
            ;;
        12 ) installoption=12
            output "Вы выбрали сброс информации о хосте базы данных."
            ;;
    esac
}

webserver_options() {
    output "Пожалуйста, выберите, какой веб-сервер вы хотели бы использовать: \n [1] Nginx (рекомендуется). \n [2] Apache2 / Httpd."
    read choice
    case $choice in
        1 ) webserver=1
            output "Вы выбрали Nginx."
            output ""
            ;;
        2 ) webserver=2
            output "Вы выбрали Apache2 / Httpd."
            output ""
            ;;
        * ) output "Вы не ввели правильный выбор."
            webserver_options
    esac
}

theme_options() {
    output "Хотите установить темы Fonix?"
    output "[1] Нет."
    output "[2] Tango Twist."
    output "[3] Blue Brick."
    output "[4] Minecraft Madness."
    output "[5] Lime Stitch."
    output "[6] Red Ape."
    output "[7] BlackEnd Space."
    output "[8] Nothing But Graphite."
    output ""
    output "Вы можете узнать о темах Fonix здесь: https://github.com/TheFonix/Pterodactyl-Themes"
    read choice
    case $choice in
        1 ) themeoption=1
            output "Вы выбрали для установки vanilla Pterodactyl."
            output ""
            ;;
        2 ) themeoption=2
            output "Вы выбрали для установки Fonix's Tango Twist."
            output ""
            ;;
        3 ) themeoption=3
            output "Вы выбрали для установки Fonix's Blue Brick."
            output ""
            ;;
        4 ) themeoption=4
            output "Вы выбрали для установки Fonix's Minecraft Madness."
            output ""
            ;;
        5 ) themeoption=5
            output "Вы выбрали для установки Fonix's Lime Stitch."
            output ""
            ;;
        6 ) themeoption=6
            output "Вы выбрали для установки Fonix's Red Ape."
            output ""
            ;;
        7 ) themeoption=7
            output "Вы выбрали для установки Fonix's BlackEnd Space."
            output ""
            ;;
        8 ) themeoption=8
            output "Вы выбрали для установки Fonix's Nothing But Graphite."
            output ""
            ;;        
        * ) output "Вы не ввели правильный выбор"
            theme_options
    esac
}   

required_infos() {
    output "Пожалуйста, введите желаемый адрес электронной почты пользователя:"
    read email
    dns_check
}

ssl_option(){
    output "Вы хотите использовать SSL? [Y/n]: "
    output "Если у вас есть домен, установите для него 'yes' для максимальной безопасности."
    output "Если вы выберете 'no', сервер будет доступен через IP без SSL. Пожалуйста, имейте в виду, что это очень ненадежно и не рекомендуется!"
    output "Если у вашей панели есть SSL, ваш демон также должен иметь SSL."
    read RESPONSE
    USE_SSL=true
    if [[ "${RESPONSE}" =~ ^([nN][oO]|[nN])+$ ]]; then
        USE_SSL=false
    fi

    if [ $USE_SSL = "true" ]; then
        dns_check
    fi
}

dns_check(){
    output "Пожалуйста, введите ваш FQDN (panel.yourdomain.com):"
    read FQDN

    output "Проверка разрешения DNS."
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    DOMAIN_RECORD=$(dig +short ${FQDN})
    if [ "${SERVER_IP}" != "${DOMAIN_RECORD}" ]; then
        output ""
        output "Введенный домен не преобразуется в первичный общедоступный IP-адрес этого сервера."
        output "Пожалуйста, сделайте запись A, указывающую на ip вашего сервера. Например, если вы создаете запись A, называемую 'panel', указывающую на IP-адрес вашего сервера, ваше полное доменное имя будет panel.yourdomain.tld"
        output "Если вы используете Cloudflare, отключите оранжевое облако."
        output "Если у вас нет домена, вы можете получить бесплатный по адресу https://www.freenom.com/en/index.html?lang=en."
        dns_check
    else 
        output "Домен разрешен правильно. Поехали дальше."
    fi
}

theme() {
    output "Тема установки инициализирована."
    cd /var/www/pterodactyl
    if [ "$themeoption" = "1" ]; then
        output "Сохранение ванильной темы Птеродактиля."
    elif [ "$themeoption" = "2" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/TangoTwist/build.sh | sh
    elif [ "$themeoption" = "3" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlueBrick/build.sh | sh
    elif [ "$themeoption" = "4" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/MinecraftMadness/build.sh | sh 
    elif [ "$themeoption" = "5" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/LimeStitch/build.sh | sh
    elif [ "$themeoption" = "6" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/RedApe/build.sh | sh
    elif [ "$themeoption" = "7" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/BlackEndSpace/build.sh | sh
    elif [ "$themeoption" = "8" ]; then
        curl https://raw.githubusercontent.com/TheFonix/Pterodactyl-Themes/master/MasterThemes/NothingButGraphite/build.sh | sh
    fi
    php artisan view:clear
    php artisan cache:clear
}

repositories_setup(){
    output "Конфигурирование ваших репозиториев."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install sudo
        apt-get -y install software-properties-common
        echo 'Acquire::ForceIPv4 "true";' | sudo tee /etc/apt/apt.conf.d/99force-ipv4
        apt-get -y update 
        if [ "$lsb_dist" =  "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
            add-apt-repository -y ppa:chris-lea/redis-server
            add-apt-repository -y ppa:certbot/certbot
            add-apt-repository -y ppa:nginx/development
            if [ "$dist_version" = "18.10" ]; then
                apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
                add-apt-repository 'deb [arch=amd64] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/ubuntu cosmic main'
                apt -y install tuned
                tuned-adm profile latency-performance
            elif [ "$dist_version" = "18.04" ]; then
                apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
                add-apt-repository -y 'deb [arch=amd64,arm64,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/ubuntu bionic main'
                apt -y install tuned
                tuned-adm profile latency-performance
            elif [ "$dist_version" = "16.04" ]; then
                apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8
                add-apt-repository 'deb [arch=amd64,arm64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/ubuntu xenial main'    
                apt -y install tuned
                tuned-adm profile latency-performance   
            fi
        elif [ "$lsb_dist" =  "debian" ]; then
            apt-get -y install ca-certificates apt-transport-https
            if [ "$dist_version" = "9" ]; then
                apt-get install -y software-properties-common dirmngr
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                sudo echo "deb https://packages.sury.org/php/ stretch main" | sudo tee /etc/apt/sources.list.d/php.list
                sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
                sudo add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/debian stretch main'
                apt -y install tuned
                tuned-adm profile latency-performance
            elif [ "$dist_version" = "8" ]; then
                wget -q https://packages.sury.org/php/apt.gpg -O- | sudo apt-key add -
                echo "deb https://packages.sury.org/php/ jessie main" | sudo tee /etc/apt/sources.list.d/php.list
                apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
                add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://nyc2.mirrors.digitalocean.com/mariadb/repo/10.3/debian jessie main'
            fi
        fi
        apt-get -y update 
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean   
        apt-get -y install dnsutils curl
    elif  [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        if  [ "$lsb_dist" =  "fedora" ] && [ "$dist_version" = "29" ]; then

            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/fedora29-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[heffer-nginx-mainline]
name=Copr repo for nginx-mainline owned by heffer
baseurl=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

            dnf -y install  http://rpms.remirepo.net/fedora/remi-release-29.rpm
            dnf -y install dnf-plugins-core
            dnf config-manager --set-enabled remi-php73
            dnf config-manager --set-enabled remi

        elif  [ "$lsb_dist" =  "fedora" ] && [ "$dist_version" = "28" ]; then

            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/fedora28-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[heffer-nginx-mainline]
name=Copr repo for nginx-mainline owned by heffer
baseurl=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
            dnf -y install http://rpms.remirepo.net/fedora/remi-release-28.rpm
            dnf -y install dnf-plugins-core
            dnf config-manager --set-enabled remi-php73
            dnf config-manager --set-enabled remi

        elif  [ "$lsb_dist" =  "centos" ] && [ "$dist_version" = "7" ]; then

            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[heffer-nginx-mainline]
name=Copr repo for nginx-mainline owned by heffer
baseurl=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/epel-7-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF

            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
        elif  [ "$lsb_dist" =  "rhel" ]; then
            
            bash -c 'cat > /etc/yum.repos.d/mariadb.repo' <<-'EOF'        
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/rhel7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

            bash -c 'cat > /etc/yum.repos.d/nginx.repo' <<-'EOF'
[heffer-nginx-mainline]
name=Copr repo for nginx-mainline owned by heffer
baseurl=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/epel-7-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://copr-be.cloud.fedoraproject.org/results/heffer/nginx-mainline/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
EOF
            yum -y install epel-release
            yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm
        fi
        yum -y install yum-utils tuned
        tuned-adm profile latency-performance
        yum-config-manager --enable remi-php72
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
        yum -y install curl bind-utils
    fi
}

install_dependencies(){
    output "Установка зависимостей."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        if [ "$webserver" = "1" ]; then
            apt-get -y install php7.3 php7.3-cli php7.3-gd php7.3-mysql php7.3-pdo php7.3-mbstring php7.3-tokenizer php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip curl tar unzip git redis-server nginx git wget expect jq
        elif [ "$webserver" = "2" ]; then
            apt-get -y install php7.3 php7.3-cli php7.3-gd php7.3-mysql php7.3-pdo php7.3-mbstring php7.3-tokenizer php7.3-bcmath php7.3-xml php7.3-fpm php7.3-curl php7.3-zip curl tar unzip git redis-server apache2 libapache2-mod-php7.3 redis-server git wget expect jq
        fi
        sh -c "DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server"
    elif [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            yum -y install php php-common php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache mariadb-server redis nginx git policycoreutils-python-utils libsemanage-devel unzip wget expect jq
        elif [ "$webserver" = "2" ]; then
            yum -y install php php-common php-fpm php-cli php-json php-mysqlnd php-mcrypt php-gd php-mbstring php-pdo php-zip php-bcmath php-dom php-opcache mariadb-server redis httpd git policycoreutils-python-utils libsemanage-devel mod_ssl unzip wget expect jq
        fi
    fi

    output "Включение Сервисов."
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
    service cron start
    service mariadb start
}

install_pterodactyl() {
    output "Создание баз данных и установка пароля root."
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q0="DROP DATABASE IF EXISTS test;"
    Q1="CREATE DATABASE IF NOT EXISTS panel;"
    Q2="GRANT ALL ON panel.* TO 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$password';"
    Q3="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, EXECUTE, PROCESS, RELOAD, CREATE USER ON *.* TO 'admin'@'$SERVER_IP' IDENTIFIED BY '$adminpassword' WITH GRANT OPTION;"
    Q4="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$rootpassword');"
    Q5="SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('$rootpassword');"
    Q6="SET PASSWORD FOR 'root'@'::1' = PASSWORD('$rootpassword');"
    Q7="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    Q8="DELETE FROM mysql.user WHERE User='';"
    Q9="DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    Q10="FLUSH PRIVILEGES;"
    SQL="${Q0}${Q1}${Q2}${Q3}${Q4}${Q5}${Q6}${Q7}${Q8}${Q9}${Q10}"
    mysql -u root -e "$SQL"

    output "Привязка MariaDB к 0.0.0.0."
	if [ -f /etc/mysql/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/mysql/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/mysql/my.cnf
		output 'Перезапуск процесса MySQL...'
		service mariadb restart
	elif [ -f /etc/my.cnf ] ; then
        sed -i -- 's/bind-address/# bind-address/g' /etc/my.cnf
		sed -i '/\[mysqld\]/a bind-address = 0.0.0.0' /etc/my.cnf
		output 'Перезапуск процесса MySQL...'
		service mariadb restart
	else 
		output 'Файл my.cnf не найден! Пожалуйста, свяжитесь со службой поддержки.'
	fi
    
    output "Загрузка Pterodactyl."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/download/v0.7.17/panel.tar.gz
    tar --strip-components=1 -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    output "Установка Pterodactyl."
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    cp .env.example .env
    if [ "$lsb_dist" =  "rhel" ]; then
        yum -y install composer
        composer update
    else
        composer install --no-dev --optimize-autoloader
    fi
    php artisan key:generate --force
    php artisan p:environment:setup -n --author=$email --url=https://$FQDN --timezone=America/New_York --cache=redis --session=database --queue=redis --redis-host=127.0.0.1 --redis-pass= --redis-port=6379
    php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password=$password
    output "Чтобы использовать внутреннюю отправку почты PHP, выберите [mail]. Чтобы использовать собственный SMTP-сервер, выберите [smtp]. Шифрование TLS рекомендуется."
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

    output "Создание слушателей очереди панели"
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
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
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
    fi
    sudo systemctl daemon-reload
    systemctl enable pteroq.service
    systemctl start pteroq
}

upgrade_pterodactyl(){
    cd /var/www/pterodactyl
    php artisan down
    curl -L https://github.com/pterodactyl/panel/releases/download/v0.7.17/panel.tar.gz | tar --strip-components=1 -xzv
    unzip panel
    chmod -R 755 storage/* bootstrap/cache
    composer install --no-dev --optimize-autoloader
    php artisan view:clear
    php artisan migrate --force
    php artisan db:seed --force
    chown -R www-data:www-data * /var/www/pterodactyl
    if [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
    output "Ваша панель обновлена до версии 0.7.17."
    php artisan up
    php artisan queue:restart
}

nginx_config() {
    output "Отключение конфигурации по умолчанию"
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка Nginx Webserver"
    
echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2;
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

    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

nginx_config_nossl() {
    output "Отключение конфигурации по умолчанию"
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка Nginx Webserver"
    
echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80 default_server;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
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

    ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    service nginx restart
}

apache_config() {
    output "Отключение конфигурации по умолчанию"
    rm -rf /etc/nginx/sites-enabled/default
    output "Настройка Apache2"
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
    output "Настройка Nginx Webserver"
    
echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80;
    server_name '"$FQDN"';
    return 301 https://$server_name$request_uri;
}
server {
    listen 443 ssl http2;
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

nginx_config_redhat_nossl(){
    output "Настройка Nginx Webserver"
    
echo '
server_tokens off;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2c0f:f248::/32;
set_real_ip_from 2a06:98c0::/29;
real_ip_header X-Forwarded-For;
server {
    listen 80 default_server;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;
    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;
    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;
    
    sendfile off;
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
    output "Настройка Apache2"
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
    output "Настройка PHP сокета."
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
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        if [ "$webserver" = "1" ]; then
            nginx_config
        elif [ "$webserver" = "2" ]; then
            apache_config
        fi
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        if [ "$webserver" = "1" ]; then
            php_config
            nginx_config_redhat
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
    theme
}

install_daemon() {
    cd /root
    output "Установка зависимостей Pterodactyl Daemon."
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        apt-get -y install curl tar unzip
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        yum -y install curl tar unzip
    fi
    output "Включение поддержки Swap для Docker и установка NodeJS."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& swapaccount=1/' /etc/default/grub
    if  [ "$lsb_dist" =  "ubuntu" ] ||  [ "$lsb_dist" =  "debian" ]; then
        sudo update-grub
        curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
        apt -y install nodejs make gcc g++ node-gyp
        apt-get -y update 
        apt-get -y upgrade
        apt-get -y autoremove
        apt-get -y autoclean
    elif  [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        grub2-mkconfig -o "$(readlink /etc/grub2.conf)"
        curl --silent --location https://rpm.nodesource.com/setup_10.x | sudo bash -
        yum -y install nodejs gcc-c++ make
        yum -y upgrade
        yum -y autoremove
        yum -y clean packages
    fi
    output "Установка Птеродактиль Демона."
    mkdir -p /srv/daemon /srv/daemon-data
    cd /srv/daemon
    curl -L https://github.com/pterodactyl/daemon/releases/download/v0.6.13/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install --only=production
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
    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        kernel_modifications_d8
    fi

    output "Установка демона почти завершена. Перейдите на панель и получите команду 'Auto deploy' на вкладке конфигурации узла."
    output "Вставьте команду автоматического развертывания ниже: "
    read AUTODEPLOY
    ${AUTODEPLOY}
    service wings start
}

upgrade_daemon(){
    cd /srv/daemon
    service wings stop
    curl -L https://github.com/pterodactyl/daemon/releases/download/v0.6.13/daemon.tar.gz | tar --strip-components=1 -xzv
    npm install -g npm
    npm install --only=production
    service wings restart
    output "Ваш демон обновлен до версии 0.6.13."
    output "npm был обновлен до последней версии."
}

install_standalone_sftp(){
    cd /srv/daemon
    if [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "null" ]; then
        output "Обновление конфига для включения sftp-сервера."
        cat /srv/daemon/config/core.json | jq '.sftp.enabled |= false' > /tmp/core
        cat /tmp/core > /srv/daemon/config/core.json
        rm -rf /tmp/core
    elif [ $(cat /srv/daemon/config/core.json | jq -r '.sftp.enabled') == "false" ]; then
       output "Конфиг уже настроен для sftp server."
    else 
       output "Возможно, вы установили для sftp значение true, и это не удастся."
    fi
    service wings restart
    output "Установка автономного SFTP-сервера."
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.4/sftp-server
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
    output "Отключение автономного SFTP-сервера."
    service pterosftp stop
    curl -Lo sftp-server https://github.com/pterodactyl/sftp-server/releases/download/v1.0.4/sftp-server
    chmod +x sftp-server
    service pterosftp start
    output "Ваш автономный SFTP-сервер обновлён до версии 1.0.4"
}

install_phpmyadmin(){
    output "Установка phpMyAdmin."
    cd /var/www/pterodactyl/public
    rm -rf phpmyadmin
    wget https://files.phpmyadmin.net/phpMyAdmin/5.0.2/phpMyAdmin-5.0.2-all-languages.zip
    unzip phpMyAdmin-5.0.2-all-languages
    mv phpMyAdmin-5.0.2-all-languages phpmyadmin
    rm -rf phpMyAdmin-5.0.2-all-languages.zip
    cd /var/www/pterodactyl/public/phpmyadmin

    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
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
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        chown -R apache:apache * /var/www/pterodactyl
        chown -R nginx:nginx * /var/www/pterodactyl
        semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/pterodactyl/storage(/.*)?"
        restorecon -R /var/www/pterodactyl
    fi
}

kernel_modifications_d8(){
    output "Модификация Grub."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& cgroup_enable=memory/' /etc/default/grub  
    output "Добавление репозитория backport." 
    echo deb http://http.debian.net/debian jessie-backports main > /etc/apt/sources.list.d/jessie-backports.list
    echo deb http://http.debian.net/debian jessie-backports main contrib non-free > /etc/apt/sources.list.d/jessie-backports.list
    output "Обновление серверных пакетов."
    apt-get -y update
    apt-get -y upgrade
    apt-get -y autoremove
    apt-get -y autoclean
    output"Установка нового ядра"
    apt install -t jessie-backports linux-image-4.9.0-0.bpo.7-amd64
    output "Модификация Docker."
    sed -i 's,/usr/bin/dockerd,/usr/bin/dockerd --storage-driver=overlay2,g' /lib/systemd/system/docker.service
    systemctl daemon-reload
    service docker start
}

ssl_certs(){
    output "Установка LetsEncrypt и создание SSL-сертификата."
    cd /root
    if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
            wget https://dl.eff.org/certbot-auto
            chmod a+x certbot-auto
        else
            apt-get -y install certbot
        fi
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        yum -y install certbot
    fi
    if [ "$webserver" = "1" ]; then
        service nginx stop
    elif [ "$webserver" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            service apache2 stop
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
            service httpd stop
        fi
    fi

    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        ./certbot-auto certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
    else
        certbot certonly --standalone --email "$email" --agree-tos -d "$FQDN" --non-interactive
    fi
    if [ "$installoption" = "2" ]; then
        if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
            ufw deny 80
        elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
            firewall-cmd --permanent --remove-port=80/tcp
            firewall-cmd --reload
        fi
    else
        if [ "$webserver" = "1" ]; then
            service nginx restart
        elif [ "$webserver" = "2" ]; then
            if  [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
                service apache2 restart
            elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
                service httpd restart
            fi
        fi
    fi

    if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
        apt -y install cronie
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * ./certbot-auto renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * ./certbot-auto renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1")| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            (crontab -l ; echo "0 0,12 * * * ./certbot-auto renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
        elif [ "$installoption" = "3" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * ./certbot-auto renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * ./certbot-auto renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            fi
        fi            
    elif [ "$lsb_dist" =  "debian" ] || [ "$lsb_dist" =  "ubuntu" ]; then
        apt -y install cronie
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --post-hook "service apache2 restart" >> /dev/null 2>&1")| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "ufw allow 80" --pre-hook "service wings stop" --post-hook "ufw deny 80" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
        elif [ "$installoption" = "3" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service apache2 stop" --pre-hook "service wings stop" --post-hook "service apache2 restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            fi
        fi    
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "rhel" ]; then
        yum -y install cronie
        if [ "$installoption" = "1" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service nginx stop" --post-hook "service nginx restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service httpd stop" --post-hook "service httpd restart" >> /dev/null 2>&1")| crontab -
            fi
        elif [ "$installoption" = "2" ]; then
            (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "firewall-cmd --add-port=80/tcp && firewall-cmd --reload" --pre-hook "service wings stop" --post-hook "firewall-cmd --remove-port=80/tcp && firewall-cmd --reload" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
        elif [ "$installoption" = "3" ]; then
            if [ "$webserver" = "1" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service nginx stop" --pre-hook "service wings stop" --post-hook "service nginx restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            elif [ "$webserver" = "2" ]; then
                (crontab -l ; echo "0 0,12 * * * certbot renew --pre-hook "service httpd stop" --pre-hook "service wings stop" --post-hook "service httpd restart" --post-hook "service wings restart" >> /dev/null 2>&1")| crontab -
            fi
        fi    
    fi
    service cron restart
}

firewall(){
    rm -rf /etc/rc.local
    printf '%s\n' '#!/bin/bash' 'exit 0' | sudo tee -a /etc/rc.local
    chmod +x /etc/rc.local

    iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP
    iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
    iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP 
    iptables -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
    iptables -A INPUT -p tcp -m connlimit --connlimit-above 1000 --connlimit-mask 32 --connlimit-saddr -j REJECT --reject-with tcp-reset
    iptables -t mangle -A PREROUTING -f -j DROP
    /sbin/iptables -N port-scanning 
    /sbin/iptables -A port-scanning -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s --limit-burst 2 -j RETURN 
    /sbin/iptables -A port-scanning -j DROP  
    sh -c "iptables-save > /etc/iptables.conf"
    sed -i -e '$i \iptables-restore < /etc/iptables.conf\n' /etc/rc.local

    output "Настройка Fail2Ban"
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        apt -y install fail2ban
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "rhel" ]; then
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

    output "Настройка вашего брандмауэра."
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
        yes |ufw enable 
    elif [ "$lsb_dist" =  "centos" ] || [ "$lsb_dist" =  "fedora" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        yum -y install firewalld
        systemctl enable firewalld
        systemctl start firewalld
        if [ "$installoption" = "1" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --add-service=mysql --permanent 
        elif [ "$installoption" = "2" ]; then
            firewall-cmd --permanent --add-port=80/tcp
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
        elif [ "$installoption" = "3" ]; then
            firewall-cmd --add-service=http --permanent
            firewall-cmd --add-service=https --permanent 
            firewall-cmd --permanent --add-port=2022/tcp
            firewall-cmd --permanent --add-port=8080/tcp
            firewall-cmd --add-service=mysql --permanent 
        fi
        firewall-cmd --reload
    fi
}

mariadb_root_reset(){
    service mariadb stop
    mysqld_safe --skip-grant-tables >res 2>&1 &
    sleep 5
    rootpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q1="UPDATE user SET plugin='';"
    Q2="UPDATE user SET password=PASSWORD('$rootpassword') WHERE user='root';"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"
    mysql mysql -e "$SQL"
    pkill mysqld
    service mariadb restart
    output "Ваш пароль root для MariaDB $rootpassword"
}

database_host_reset(){
    SERVER_IP=$(curl -s http://checkip.amazonaws.com)
    service mariadb stop
    mysqld_safe --skip-grant-tables >res 2>&1 &
    sleep 5
    adminpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
    Q1="UPDATE user SET plugin='';"
    Q2="UPDATE user SET password=PASSWORD('$adminpassword') WHERE user='admin';"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"
    mysql mysql -e "$SQL"
    pkill mysqld
    service mariadb restart
    output "Новая информация о хосте базы данных:"
    output "Хост: $SERVER_IP"
    output "Порт: 3306"
    output "Пользователь: admin"
    output "Пароль: $adminpassword"
}

broadcast(){
    if [ "$installoption" = "1" ] || [ "$installoption" = "3" ]; then
        output "###############################################################"
        output "Информация MARIADB"
        output ""
        output "Ваш пароль root для MariaDB $rootpassword"
        output ""
        output "Создайте свой хост MariaDB со следующей информацией:"
        output "Хост: $SERVER_IP"
        output "Порт: 3306"
        output "Пользователь: admin"
        output "Пароль: $adminpassword"
        output "###############################################################"
        output ""
    fi
    output "###############################################################"
    output "ИНФОРМАЦИЯ ФЕЙЕРВЕРЛ"
    output ""
    output "Все ненужные порты заблокированы по умолчанию."
    if [ "$lsb_dist" =  "ubuntu" ] || [ "$lsb_dist" =  "debian" ]; then
        output "Используйте 'ufw allow <port>' чтобы включить желаемые порты"
    elif [ "$lsb_dist" =  "fedora" ] || [ "$lsb_dist" =  "centos" ] ||  [ "$lsb_dist" =  "rhel" ]; then
        output "Используйте 'firewall-cmd --permanent --add-port=<port>/tcp' чтобы включить желаемые порты."
        semanage permissive -a httpd_t
        semanage permissive -a redis_t
    fi
    output "###############################################################"
    output ""

    if [ "$installoption" = "2" ] || [ "$installoption" = "3" ]; then
        if [ "$lsb_dist" =  "debian" ] && [ "$dist_version" = "8" ]; then
            output "Пожалуйста, перезапустите демон сервера, чтобы применить необходимые изменения ядра в Debian 8."
        fi
    fi
                         
}

#Execution
preflight
case $installoption in 
    1)  webserver_options
        theme_options
        repositories_setup
        required_infos
        firewall
        setup_pterodactyl
        broadcast
        ;;
    2)  repositories_setup
        required_infos
        firewall
        ssl_certs
        install_daemon
        broadcast
        ;;
    3)  webserver_options
        theme_options
        repositories_setup
        required_infos
        firewall
        setup_pterodactyl
        install_daemon
        broadcast
        ;;
    4)  install_standalone_sftp
        ;;
    5)  theme_options
        upgrade_pterodactyl
        theme
        ;;
    6)  upgrade_daemon
        ;;
    7)  theme_options
        upgrade_pterodactyl
        theme
        upgrade_daemon
        ;;
    8)  upgrade_standalone_sftp
        ;;
    9)  install_phpmyadmin
        ;;
    10)  theme_options
        if [ "$themeoption" = "1" ]; then
            upgrade_pterodactyl
        fi
        theme
        ;;
    11) mariadb_root_reset
        ;;
    12) database_host_reset
        ;;
esac

