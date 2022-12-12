#!/bin/bash
set -e

help() {
    echo "Flags :"
    echo "--help, -h"
    echo "--domainname <Domain name>"
    echo "--nossl"
    echo "--emailusername <Email address without domain>"
    exit 0
}

ARGS=$(getopt -o "h" -l "help,domainname:,nossl,emailusername:" -n "$0" -- "$@")

if [ $? -ne 0 ]; then
    exit 0
fi

eval set -- $ARGS
unset ARGS

while true; do
    case "$1" in
        --help|-h)
            help
            shift;;
        --nossl)
            NOSSL=true
            shift;;
        --domainname)
            DOMAIN=$2
            shift 2;;
        --emailusername)
            EMAILUSERNAME=$2
            shift 2;;
        --)
            shift
            break;;
    esac
done

if [ -z $DOMAIN ]; then
    read -p "Please enter server domain name : " DOMAIN
fi

if [ -z $EMAILUSERNAME ]; then
    read -p "Please enter main email address without domain : " EMAILUSERNAME
fi

echo "--- Configuring terminal ---"
if ! grep -q "cd ~" .bashrc; then
    echo -e "" >> .bashrc
    echo "PS1='\${debian_chroot:+(\$debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ '" >> .bashrc
    echo -e "\ncd ~" >> .bashrc
    echo -e "\nalias ls=\"ls -al\"\nalias rm=\"rm -rf\"" >> .bashrc
fi

echo "--- Updating machine... ---"
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

echo "--- Installing utilities... ---"
apt-get install sudo curl wget git unzip tar net-tools ca-certificates gnupg lsb-release apt-transport-https software-properties-common -y

echo "--- Installing firewall... ---"
apt-get install ufw -y
ufw allow 22 # SSH
ufw allow 2022 # FTP Ptero
ufw allow 8080 # Wings Ptero
ufw allow 80 # HTTP
ufw allow 443 # HTTPS
ufw allow 3306 # MySQL
ufw allow 25 # SMTP
ufw allow 110 # POP3
ufw allow 143 # IMAP
ufw allow 465 # SMTPS
ufw allow 587 # MSA
ufw allow 993 # IMAPS
ufw allow 995 # POP3S
ufw allow 4190 # Sieve
ufw allow 25565 # Minecraft
ufw allow in on pterodactyl0 to 172.18.0.1 port 25000:25100 proto tcp # Servers Ptero
ufw --force enable

echo "--- Installing fail2ban... ---"
apt-get install fail2ban -y

echo "--- Installing webserver... ---"
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt-get update
apt-get install apache2 php php-{cli,gd,mysql,mbstring,tokenizer,bcmath,xml,curl,zip} python3-certbot-apache -y

echo "--- Configuring webserver... ---"
sed -i -e "s/ServerSignature On/ServerSignature Off/" /etc/apache2/conf-available/security.conf
sed -i -e "s/ServerTokens OS/ServerTokens Prod/" /etc/apache2/conf-available/security.conf
OLDDIRCONFIG="<Directory \\/>\r\tOptions FollowSymLinks\r\tAllowOverride None\r\tRequire all denied\r<\\/Directory>\r\r<Directory \\/usr\\/share>\r\tAllowOverride None\r\tRequire all granted\r<\\/Directory>\r\r<Directory \\/var\\/www\\/>\r\tOptions Indexes FollowSymLinks\r\tAllowOverride None\r\tRequire all granted\r<\\/Directory>\r\r#<Directory \\/srv\\/>\r#	Options Indexes FollowSymLinks\r#	AllowOverride None\r#	Require all granted\r#<\\/Directory>\r\r\r"
NEWDIRCONFIG="<Directory \\/>\r\tAllowOverride None\r\tRequire all denied\r<\\/Directory>\r\r<Directory \\/var\\/www\\/>\r\tAllowOverride All\r\tRequire all granted\r<\\/Directory>"
cat /etc/apache2/apache2.conf | tr '\n' '\r' | sed -e "s/$OLDDIRCONFIG/$NEWDIRCONFIG/" | tr '\r' '\n' > temp.txt && mv temp.txt /etc/apache2/apache2.conf
rm /var/www/html/*
service apache2 restart

echo "--- Installing database... ---"
apt-get install mariadb-server -y

echo "--- Securing database... ---"
ROOTPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
mysql --user=root -e "DELETE FROM mysql.global_priv WHERE User='';"
mysql --user=root -e "DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql --user=root -e "DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql --user=root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOTPASS'; FLUSH PRIVILEGES;"

echo "--- Installing composer... ---"
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo "--- Installing Docker... ---"
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl enable --now docker
sed -i -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/GRUB_CMDLINE_LINUX_DEFAULT=\"swapaccount=1\"/" /etc/default/grub
update-grub

echo "--- Installing mailserver... ---"
MAILPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
docker run -td \
    --name mailserver \
    --hostname mail.$DOMAIN \
    --volume /root/mailserver:/data \
    --restart always \
    --env TZ=Europe/Paris \
    --env HTTPS=OFF \
    --publish 8000:80 \
    --publish 25:25 \
    --publish 110:110 \
    --publish 143:143 \
    --publish 465:465 \
    --publish 587:587 \
    --publish 993:993 \
    --publish 995:995 \
    --publish 4190:4190 \
    analogic/poste.io
WEBMAILVHOST="<VirtualHost *:80>\n\n    ServerName webmail.$DOMAIN\n\n    Alias /.well-known /var/www/html/.well-known\n\n    ProxyPass /.well-known "'!'"\n    ProxyPass / http://127.0.0.1:8000/\n    ProxyPassReverse / http://127.0.0.1:8000/\n\n</VirtualHost>"
echo -e $WEBMAILVHOST > /etc/apache2/sites-available/webmail.$DOMAIN.conf
a2enmod proxy proxy_http
a2ensite webmail.$DOMAIN
service apache2 restart
if [ "$NOSSL" != true ]; then
    certbot --email $EMAILUSERNAME@$DOMAIN --agree-tos --no-eff-email -d webmail.$DOMAIN -w /var/www/html
fi
echo "Waiting for mailserver starting..."
sleep 10
curl http://127.0.0.1:8000/admin/install/server -d "install%5Bhostname%5D=mail.$DOMAIN&install%5BsuperAdmin%5D=$EMAILUSERNAME%40$DOMAIN&install%5BsuperAdminPassword%5D=$MAILPASS"

echo "--- Installing PhpMyAdmin... ---"
curl -s https://raw.githubusercontent.com/Raraph84/PhpMyAdmin-Installer/master/install_phpmyadmin.sh | bash -s $ROOTPASS

echo "--- Downloading panel... ---"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

echo "--- Configuring Pterodactyl database... ---"
PTERODBPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
mysql --user=root --password=$ROOTPASS -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '$PTERODBPASS'; CREATE DATABASE panel; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"

echo "--- Installing panel... ---"
PTEROPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
cp .env.example .env
echo "yes" | composer install --no-dev --optimize-autoloader
php artisan key:generate --force
echo -e "$EMAILUSERNAME@$DOMAIN\nhttps://ptero.$DOMAIN\nEurope/Paris\n\n\n\n\nno\n" | php artisan p:environment:setup
echo -e "\n\n\n\n$PTERODBPASS\n" | php artisan p:environment:database
echo -e "\nmail.$DOMAIN\n465\n$EMAILUSERNAME@$DOMAIN\n$MAILPASS\n$EMAILUSERNAME@$DOMAIN\n\nssl\n" | php artisan p:environment:mail
php artisan migrate --seed --force
set +e # This command exit with an error but works perfectly
echo -e "yes\n$EMAILUSERNAME@$DOMAIN\nAdmin\nAdmin\nAdmin\n$PTEROPASS\n" | php artisan p:user:make
set -e
chown -R www-data:www-data /var/www/pterodactyl/*
(crontab -l; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | sort -u | crontab -
PTEROQSERVICE="# Pterodactyl Queue Worker File\n# ----------------------------------\n\n[Unit]\nDescription=Pterodactyl Queue Worker\nAfter=redis-server.service\n\n[Service]\n# On some systems the user and group might be different.\n# Some systems use \`apache\` or \`nginx\` as the user and group.\nUser=www-data\nGroup=www-data\nRestart=always\nExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3\nStartLimitInterval=180\nStartLimitBurst=30\nRestartSec=5s\n\n[Install]\nWantedBy=multi-user.target"
echo -e $PTEROQSERVICE > /etc/systemd/system/pteroq.service
systemctl enable --now pteroq.service

echo "--- Configuring panel virtual host... ---"
PTEROVHOST="<VirtualHost *:80>\n\n    ServerName panel.$DOMAIN\n    DocumentRoot /var/www/pterodactyl/public\n\n    AllowEncodedSlashes On\n\n    php_value upload_max_filesize 100M\n    php_value post_max_size 100M\n\n</VirtualHost>"
echo -e $PTEROVHOST > /etc/apache2/sites-available/panel.$DOMAIN.conf
a2enmod rewrite
a2ensite panel.$DOMAIN
service apache2 restart
if [ "$NOSSL" != true ]; then
    certbot -d panel.$DOMAIN -w /var/www/pterodactyl/public
fi

echo "--- Installing wings... ---"
mkdir -p /etc/pterodactyl
curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
chmod u+x /usr/local/bin/wings
echo -e "\n\nRECAPTCHA_ENABLED=false" >> /var/www/pterodactyl/.env
WINGSSERVICE="[Unit]\nDescription=Pterodactyl Wings Daemon\nAfter=docker.service\nRequires=docker.service\nPartOf=docker.service\n\n[Service]\nUser=root\nWorkingDirectory=/etc/pterodactyl\nLimitNOFILE=4096\nPIDFile=/var/run/wings/daemon.pid\nExecStart=/usr/local/bin/wings\nRestart=on-failure\nStartLimitInterval=180\nStartLimitBurst=30\nRestartSec=5s\n\n[Install]\nWantedBy=multi-user.target"
echo -e $WINGSSERVICE > /etc/systemd/system/wings.service

echo "--- Installation finished ---"
echo "Database root password is $ROOTPASS"
echo "Database pterodactyl password is $PTERODBPASS"
echo "Email is $EMAILUSERNAME@$DOMAIN and password is $MAILPASS"
echo "Pterodactyl admin is $EMAILUSERNAME@$DOMAIN and password is $PTEROPASS"
