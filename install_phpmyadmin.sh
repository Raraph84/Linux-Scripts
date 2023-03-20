#!/bin/bash

if [ "$UID" -ne "0" ]; then
    echo "Please run script with root !"
    exit 1
fi

if [ -z $1 ]; then
    read -sp "Database root password : " ROOTPASS
    echo ""
else
    ROOTPASS=$1
fi

if ! echo SELECT 1 | mysql --user=root --password=$ROOTPASS &> /dev/null; then
    echo "Invalid database root password !"
    exit 1
fi

echo "--- Installing additionnal packages... ---"

apt-get -qq install libapache2-mod-php php-mysql php-mbstring unzip -y

echo "--- Downloading PhpMyAdmin... ---"
wget -q https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip -q phpMyAdmin-5.2.1-all-languages.zip -d /opt
mv /opt/phpMyAdmin-5.2.1-all-languages /opt/phpmyadmin
rm phpMyAdmin-5.2.1-all-languages.zip
chown -R www-data:www-data /opt/phpmyadmin

echo "--- Configuring PhpMyAdmin... ---"
cp /opt/phpmyadmin/config.sample.inc.php /opt/phpmyadmin/config.inc.php

STRING1="\/\/ \$cfg\['Servers'\]\[\$i\]"
STRING2="\$cfg\['Servers'\]\[\$i\]"
sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

PMAPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sed -i -e "s/pmapass/$PMAPASS/g" /opt/phpmyadmin/config.inc.php

STRING1="\$cfg\['Servers'\]\[\$i\]\['controlhost'\] = '';"
STRING2="\/\/ \$cfg\['Servers'\]\[\$i\]\['controlhost'\] = '';"
sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php
STRING1="\$cfg\['Servers'\]\[\$i\]\['controlport'\] = '';"
STRING2="\/\/ \$cfg\['Servers'\]\[\$i\]\['controlport'\] = '';"
sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

COOKIESECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
STRING1="\$cfg\['blowfish_secret'\] = '';"
STRING2="\$cfg\['blowfish_secret'\] = '$COOKIESECRET';"
sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

mkdir -p /var/lib/phpmyadmin/tmp
chown -R www-data:www-data /var/lib/phpmyadmin
STRING="\n\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';"
echo -e "$STRING" >> /opt/phpmyadmin/config.inc.php

echo "--- Configuring database for PhpMyAdmin... ---"
mysql --user=root --password=$ROOTPASS < /opt/phpmyadmin/sql/create_tables.sql
mysql --user=root --password=$ROOTPASS -e "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '$PMAPASS';"

echo "--- Configuring Apache for PhpMyAdmin... ---"
STRING="Alias /phpmyadmin /opt/phpmyadmin\n\n<Directory /opt/phpmyadmin>\n\n  Options FollowSymLinks\n\n  AllowOverride all\n\n  Require all granted\n\n</Directory>"
echo -e "$STRING" > /etc/apache2/conf-available/phpmyadmin.conf
a2enconf phpmyadmin.conf > /dev/null
systemctl restart apache2

echo "--- Installation finished ---"
echo "Database pma password is $PMAPASS"
