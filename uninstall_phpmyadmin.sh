#!/bin/bash

# Demander mot de passe root (MySQL)
echo -n "Tapez votre mot de passe root (MySQL) : "
trap "stty echo" EXIT HUP INT QUIT
stty -echo
read ROOTPASS
stty echo
trap - EXIT HUP INT QUIT
echo "";

# Désactiver la configuration apache2
sudo a2disconf phpmyadmin.conf > /dev/null

# Supprimer les fichiers
sudo rm -rf /opt/phpmyadmin/ /etc/apache2/conf-available/phpmyadmin.conf /var/lib/phpmyadmin

# Redémarrer apache2
sudo systemctl restart apache2

# Supprimer le stockage MySQL
mysql --user=root --password=$ROOTPASS -e "DROP DATABASE phpmyadmin;"
mysql --user=root --password=$ROOTPASS -e "DROP USER 'pma'@'localhost';"

echo "PhpMyAdmin a été déinstallé avec succès !"