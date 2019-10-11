#!/bin/bash
################################################################################
# Author:   The_stas
# Web:      https://spigotmc.ru
#
# Program:
#   Install Pterodactyl-Panel on Ubuntu 18.04
#
################################################################################


clear
# получить имя сервера os: Ubuntu или Centos
server_name=`lsb_release -ds | awk -F ' ' '{printf $1}' | tr A-Z a-z`
version_name=`lsb_release -cs`
usage() {
  echo 'Usage: '$0' [-i|--install] [nginx] [apache]'
  exit 1;
}

output() {
    printf "\E[0;33;40m"
    echo $1
    printf "\E[0m"
}

displayErr() {
    echo
    echo $1;
    echo
    exit 1;
}
    # получить пользовательские данные
server_setup() {
    clear
    output "Надеюсь, вам понравится этот скрипт установки, созданный https://spigotmc.ru. Пожалуйста, введите информацию. "
    read -p "Введите email админа (пример admin@example.com) : " EMAIL
    read -p "Введите название сервера (пример portal.example.com) : " SERVNAME
    read -p "Введите временную зону (пример Europe/Moscow) : " TIME
    read -p "Пароль портала : " PORTALPASS
}

initial() {
    output "Обновление всех пакетов"
    # обновить пакет и обновить Ubuntu
    sudo apt-get -y update 
    sudo apt-get -y upgrade
    sudo apt-get -y autoremove
    output "Переключение на Aptitude"
    sudo apt-get -y install aptitude
    sudo aptitude update -y
    whoami=`whoami`
}

install_nginx() {
    output "Установка Nginx server."
    sudo aptitude -y install nginx
    sudo service nginx start
    sudo service cron start
}

install_apache() {
    output "Установка Apache server."
    sudo aptitude -y install apache2
    sudo service apache2 start
    sudo service cron start
}

install_mariadb() {
    output "Установка Mariadb Server."
    # создание случайного пароля
    rootpasswd=$(openssl rand -base64 12)
    export DEBIAN_FRONTEND="noninteractive"
    sudo aptitude -y install mariadb-server
    
    # добавление пользователя в группу, создание структуры каталогов, установка разрешений
    sudo mkdir -p /var/www/pterodactyl/html
    sudo chown -R $whoami:$whoami /var/www/pterodactyl/html
    sudo chmod -R 775 /var/www/pterodactyl/html
}

install_dependencies() {
    output "Установка PHP и зависимостей."
    sudo aptitude -y install php7.2 php7.2-cli php7.2-gd php7.2-mysql php7.2-common php7.2-mbstring php7.2-tokenizer php7.2-bcmath php7.2-xml php7.2-fpm php7.2-curl
}

install_dependencies_apache() {
    output "Установка PHP и зависимостей."
    sudo aptitude -y install php7.2 php7.2-cli php7.2-gd php7.2-mysql php7.2-common php7.2-mbstring php7.2-tokenizer php7.2-bcmath php7.2-xml php7.2-fpm php7.2-curl libapache2-mod-php
}

install_timezone() {
    output "Обновление часовой пояс по умолчанию."
    output "Спасибо за использование этого установочного скрипта."
    # check if link file
    sudo [ -L /etc/localtime ] &&  sudo unlink /etc/localtime
    # update time zone
    sudo ln -sf /usr/share/zoneinfo/$TIME /etc/localtime
    sudo aptitude -y install ntpdate
    sudo ntpdate time.stdtime.gov.tw
    # write time to clock.
    sudo hwclock -w
}

server() {
    output "Установка серверных пакетов."
    # установка большего количества файлов сервера
    sudo aptitude -y install curl
    sudo aptitude -y install tar
    sudo aptitude -y install unzip
    sudo aptitude -y install git
    sudo aptitude -y install python-pip
    pip install --upgrade pip
    sudo aptitude -y install supervisor
    sudo aptitude -y install make
    sudo aptitude -y install g++
    sudo aptitude -y install python-minimal
    sudo aptitude -y install gcc
    sudo aptitude -y install libssl-dev
}

pterodactyl() {
    output "Установка Pterodactyl-Panel."
    # Установка панели
    cd /var/www/pterodactyl/html
    curl -Lo v0.7.15.tar.gz https://github.com/Pterodactyl/Panel/archive/v0.7.15.tar.gz
    tar --strip-components=1 -xzvf v0.7.15.tar.gz
    sudo chmod -R 777 storage/* bootstrap/cache
    curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
    composer setup
    # create mysql structure
    # create database
    password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`  
    Q1="CREATE DATABASE IF NOT EXISTS pterodactyl;"
    Q2="GRANT ALL ON *.* TO 'panel'@'localhost' IDENTIFIED BY '$password';"
    Q3="FLUSH PRIVILEGES;"
    SQL="${Q1}${Q2}${Q3}"
    
    sudo mysql -u root -p="" -e "$SQL"

    output "База данных 'pterodactyl' и пользовательская 'panel', созданные с паролем $password"
}
pterodactyl_1() {
     clear
     output "Настройка среды"
     php artisan pterodactyl:env --dbhost=localhost --dbport=3306 --dbname=pterodactyl --dbuser=panel --dbpass=$password --url=http://$SERVNAME --timezone=$TIME
     output "Настройка почты"
     # php artisan pterodactyl:mail 
     output "Настройка базы данных"
     php artisan migrate --force
     output "Заполнение базы данных"
     php artisan db:seed --force
     output "Создание первого пользователя"
     php artisan pterodactyl:user --email="$EMAIL" --password=$PORTALPASS --admin=1
     sudo service cron restart
     sudo service supervisor start
     

   output "Создание конфигурационных файлов"
sudo bash -c 'cat > /etc/supervisor/conf.d/pterodactyl-worker.conf' <<-'EOF'
[program:pterodactyl-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/pterodactyl/html/artisan queue:work database --queue=high,standard,low --sleep=3 --tries=3
autostart=true
autorestart=true
user=www-data
numprocs=2
redirect_stderr=true
stdout_logfile=/var/www/pterodactyl/html/storage/logs/queue-worker.log
EOF
    output "Обновление Supervisor"
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start pterodactyl-worker:*
    sudo systemctl enable supervisor.service
}

pterodactyl_niginx() {
    output "Создание исходного файла конфигурации веб-сервера"
echo '
    server {
        listen 80;
        listen [::]:80;
        server_name '"${SERVNAME}"';
    
        root "/var/www/pterodactyl/html/public";
        index index.html index.htm index.php;
        charset utf-8;
    
        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }
    
        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }
    
        access_log off;
        error_log  /var/log/nginx/pterodactyl.app-error.log error;
    
        # allow larger file uploads and longer script runtimes
            client_max_body_size 100m;
        client_body_timeout 120s;
    
        sendfile off;
    
        location ~ \.php$ {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_intercept_errors off;
            fastcgi_buffer_size 16k;
            fastcgi_buffers 4 16k;
            fastcgi_connect_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_read_timeout 300;
        }
    
        location ~ /\.ht {
            deny all;
        }
        location ~ /.well-known {
            allow all;
        }
    }
' | sudo -E tee /etc/nginx/sites-available/pterodactyl.conf >/dev/null 2>&1

    sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    output "Установка LetsEncrypt и настройка SSL"
    sudo service nginx restart
    sudo aptitude -y install letsencrypt
    sudo letsencrypt certonly -a webroot --webroot-path=/var/www/pterodactyl/html/public --email "$EMAIL" --agree-tos -d "$SERVNAME"
    sudo rm /etc/nginx/sites-available/pterodactyl.conf
    sudo openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    echo '
        server {
            listen 80;
            listen [::]:80;
            server_name '"${SERVNAME}"';
            # enforce https
            return 301 https://$server_name$request_uri;
        }
        
        server {
            listen 443 ssl http2;
            listen [::]:443 ssl http2;
            server_name '"${SERVNAME}"';
        
            root /var/www/pterodactyl/html/public;
            index index.php;
        
            access_log /var/log/nginx/pterodactyl.app-accress.log;
            error_log  /var/log/nginx/pterodactyl.app-error.log error;
        
            # allow larger file uploads and longer script runtimes
            client_max_body_size 100m;
            client_body_timeout 120s;
            
            sendfile off;
        
            # strengthen ssl security
            ssl_certificate /etc/letsencrypt/live/'"${SERVNAME}"'/fullchain.pem;
            ssl_certificate_key /etc/letsencrypt/live/'"${SERVNAME}"'/privkey.pem;
            ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
            ssl_prefer_server_ciphers on;
            ssl_session_cache shared:SSL:10m;
            ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
            ssl_dhparam /etc/ssl/certs/dhparam.pem;
        
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
                fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
                fastcgi_index index.php;
                include fastcgi_params;
                fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
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

    sudo service nginx restart
}

pterodactyl_apache() {
    output "Создание исходного файла конфигурации веб-сервера"
    echo '
<VirtualHost *:80>
    ServerName '"${SERVNAME}"'
    DocumentRoot "/var/www/pterodactyl/html/public"
    AllowEncodedSlashes On
      <Directory "/var/www/pterodactyl/html/public">
        AllowOverride all
      </Directory>
</VirtualHost>
' | sudo -E tee /etc/apache2/sites-available/pterodactyl.conf >/dev/null 2>&1

    sudo ln -s /etc/apache2/sites-available/pterodactyl.conf /etc/apache2/sites-enabled/pterodactyl.conf
    sudo a2enmod rewrite
    sudo service apache2 restart
    output "Установка LetsEncrypt и настройка SSL"
    sudo aptitude -y install letsencrypt
    sudo letsencrypt certonly -a webroot --webroot-path=/var/www/pterodactyl/html/public --email $EMAIL --agree-tos -d $SERVNAME

    echo '
<VirtualHost *:80>
    ServerName '"${SERVNAME}"'
    DocumentRoot "/var/www/pterodactyl/html/public"
    AllowEncodedSlashes On
       <Directory "/var/www/pterodactyl/html/public">
          AllowOverride all
       </Directory>
</VirtualHost>
    NameVirtualHost *:443
<VirtualHost *:443>=
	  DocumentRoot "/var/www/pterodactyl/html/public"
    ServerName '"${SERVNAME}"'
    <Directory "/var/www/pterodactyl/html/public">
      AllowOverride all
    </Directory>
SSLEngine on
SSLCertificateFile    /etc/letsencrypt/live/'"${SERVNAME}"'/cert.pem
SSLCertificateKeyFile /etc/letsencrypt/live/'"${SERVNAME}"'/privkey.pem
SSLCertificateChainFile /etc/letsencrypt/live/'"${SERVNAME}"'/fullchain.pem
</VirtualHost>
' | sudo -E tee /etc/apache2/sites-available/pterodactyl_ssl.conf >/dev/null 2>&1
    sudo ln -s /etc/apache2/sites-available/pterodactyl_ssl.conf /etc/apache2/sites-enabled/pterodactyl_ssl.conf
    sudo a2enmod ssl
    sudo service apache2 restart
}

pterodactyl_daemon() {
    output "Установка демона! Почти всё сделано!!"
    sudo aptitude -y install linux-image-extra-$(uname -r) linux-image-extra-virtual
    sudo aptitude update -y
    sudo aptitude upgrade -y
    curl -sSL https://get.docker.com/ | sh
    sudo usermod -aG docker $whoami
    sudo systemctl enable docker
    output "Установка Nodejs"
    curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -
    sudo aptitude -y install nodejs
    output "Убедиться, что мы не пропустили никаких зависимостей "
    sudo aptitude -y install tar unzip make gcc g++ python-minimal
    output "Хорошо, теперь установка файлов демона"
    sudo mkdir -p /srv/daemon /srv/daemon-data
    sudo chown -R $whoami:$whoami /srv/daemon
    cd /srv/daemon
    curl -Lo v0.3.7.tar.gz https://github.com/Pterodactyl/Daemon/archive/v0.3.7.tar.gz
    tar --strip-components=1 -xzvf v0.3.7.tar.gz
    npm install --only=production

    output "Этот шаг требует, чтобы вы создали свой первый узел через панель, продолжайте только после того, как вы получите основной код"
    output "Вставьте код в файл и затем нажмите CTRL + o, затем CTRL + x."
    read -p "Нажмите Enter, чтобы продолжить" nothing
    sudo nano /srv/daemon/config/core.json
sudo bash -c 'cat > /etc/systemd/system/wings.service' <<-EOF
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

      sudo systemctl daemon-reload
      sudo systemctl enable wings
      sudo systemctl start wings
      sudo service wings start

      sudo usermod -aG www-data $whoami
      sudo chown -R www-data:www-data /var/www/pterodactyl/html
      sudo chown -R www-data:www-data /srv/daemon
      sudo chmod -R 775 /var/www/pterodactyl/html
      sudo chmod -R 775 /srv/daemon
      echo '
[client]
user=root
password='"${rootpasswd}"'
[mysql]
user=root
password='"${rootpasswd}"'
' | sudo -E tee ~/.my.cnf >/dev/null 2>&1
      sudo chmod 0600 ~/.my.cnf
      output "Установка пароля root для mysql"
      sudo mysqladmin -u root password $rootpasswd    
      (crontab -l ; echo "* * * * * php /var/www/pterodactyl/html/artisan schedule:run >> /dev/null 2>&1")| crontab -
      
      output "Пожалуйста, перезагрузите сервер, чтобы применить новые разрешения"
    
    
}

# Process command line...
while [ $# -gt 0 ]; do
    case $1 in
        --help | -h)
            usage $0
        ;;
        --install | -i)
            shift
            action=$1
            shift
            ;;
        *)
            usage $0
            ;;
    esac
done
test -z $action && usage $0
case $action in
  "nginx")
    server_setup
    initial
    install_nginx
    install_mariadb
    install_dependencies
    install_timezone
    server
    pterodactyl
    pterodactyl_1
    pterodactyl_niginx
    pterodactyl_daemon
    ;;
    "apache")
      server_setup
      initial
      install_apache
      install_mariadb
      install_dependencies_apache
      install_timezone
      server
      pterodactyl
      pterodactyl_1
      pterodactyl_apache
      pterodactyl_daemon
      ;;
  *)
    usage $0
    ;;
esac
exit 1;
