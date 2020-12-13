#!/bin/bash

# Vérifier si le script est lancé en root
if [ "$UID" -ne "0" ]
then
   echo "Merci de lancer le script en root !"
   exit 1
fi

# Demander mot de passe root (MySQL)
read -sp "Tapez votre mot de passe root (MySQL) : " ROOTPASS
echo ""

# Désactiver la configuration apache2
a2disconf phpmyadmin.conf > /dev/null

# Supprimer les fichiers
rm -rf /opt/phpmyadmin/ /etc/apache2/conf-available/phpmyadmin.conf /var/lib/phpmyadmin

# Redémarrer apache2
systemctl restart apache2

# Supprimer le stockage MySQL
mysql --user=root --password=$ROOTPASS -e "DROP DATABASE phpmyadmin;"
mysql --user=root --password=$ROOTPASS -e "DROP USER 'pma'@'localhost';"

echo "PhpMyAdmin a été déinstallé avec succès !"