# Pterodactyl-Panel-Install
Этот скрипт установит Pterodactyl-Panel в вашей системе Ubuntu 18.x.

У вас есть выбор: установить Nginx или Apache.

Этот скрипт должен быть запущен на правильно настроенном сервере, а не под пользователем root.

curl -Lo install.sh https://raw.githubusercontent.com/stashenko/Pterodactyl-Panel-Install/master/install.sh
bash install.sh -i [nginx] [apache]
Пример: bash install.sh -i nginx

Вам будет предложено ввести адрес электронной почты, FDQN, часовой пояс и пароль портала.

Это установит все необходимые файлы и обновит систему, включая SSL.
