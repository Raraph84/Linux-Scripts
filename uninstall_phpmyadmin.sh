# Désactiver la configuration apache2
sudo a2disconf phpmyadmin.conf > /dev/null

# Supprimer les fichiers
sudo rm -rf /opt/phpmyadmin/ /etc/apache2/conf-available/phpmyadmin.conf /var/lib/phpmyadmin

# Redémarrer apache2
sudo systemctl restart apache2

# Supprimer le stockage MySQL
echo "Entrer le mot de passe root (MySQL) deux fois :"
mysql -u root -p -e "DROP DATABASE phpmyadmin;"
mysql -u root -p -e "DROP USER 'pma'@'localhost';"

echo "PhpMyAdmin a été déinstallé avec succès !"