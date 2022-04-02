#!/bin/bash

if [ "$UID" -ne "0" ]; then
   echo "Merci de lancer le script en root !"
   exit 1
fi

read -sp "Tapez votre mot de passe root (MySQL) : " ROOTPASS
echo ""

a2disconf phpmyadmin.conf > /dev/null

rm -rf /opt/phpmyadmin /etc/apache2/conf-available/phpmyadmin.conf /var/lib/phpmyadmin

systemctl restart apache2

mysql --user=root --password=$ROOTPASS -e "DROP DATABASE phpmyadmin;"
mysql --user=root --password=$ROOTPASS -e "DROP USER 'pma'@'localhost';"

echo "PhpMyAdmin a été déinstallé avec succès !"
