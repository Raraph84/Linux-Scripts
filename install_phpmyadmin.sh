#!/bin/bash

# Télécharger PhpMyAdmin
wget -q https://files.phpmyadmin.net/phpMyAdmin/5.0.4/phpMyAdmin-5.0.4-all-languages.zip

# Dézipper
sudo unzip -q phpMyAdmin-5.0.4-all-languages.zip -d /opt

# Supprimer l'archive
rm phpMyAdmin-5.0.4-all-languages.zip

# Déplacer et donner les permissions
sudo mv /opt/phpMyAdmin-5.0.4-all-languages /opt/phpmyadmin
sudo chown -R www-data:www-data /opt/phpmyadmin

# Créer le fichier de configuration
sudo cp /opt/phpmyadmin/config.sample.inc.php /opt/phpmyadmin/config.inc.php

# Activer le système d'utilisateur de stockage
STRING1="\/\/ \$cfg\['Servers'\]\[\$i\]"
STRING2="\$cfg\['Servers'\]\[\$i\]"
sudo sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

# Mot de passe du stockage
PMAPASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
sudo sed -i -e "s/pmapass/$PMAPASS/g" /opt/phpmyadmin/config.inc.php

# Désactiver les lignes qui ne servent pas
STRING1="\$cfg\['Servers'\]\[\$i\]\['controlhost'\] = '';"
STRING2="\/\/ \$cfg\['Servers'\]\[\$i\]\['controlhost'\] = '';"
sudo sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php
STRING1="\$cfg\['Servers'\]\[\$i\]\['controlport'\] = '';"
STRING2="\/\/ \$cfg\['Servers'\]\[\$i\]\['controlport'\] = '';"
sudo sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

# Créer le stockage et son utilisateur
#sudo mysql -u root -p < /opt/phpmyadmin/sql/create_tables.sql
#sudo mysql -u root -p -e "GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'localhost' IDENTIFIED BY '$PMAPASS';"

# Ajouter le code des cookies
COOKIESECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
STRING1="\$cfg\['blowfish_secret'\] = '';"
STRING2="\$cfg\['blowfish_secret'\] = '$COOKIESECRET';"
sudo sed -i -e "s/$STRING1/$STRING2/g" /opt/phpmyadmin/config.inc.php

# Ajouter le dossier des fichiers temporaires, et le configurer
sudo mkdir -p /var/lib/phpmyadmin/tmp
sudo chown -R www-data:www-data /var/lib/phpmyadmin
STRING="\n\$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';"
echo "$STRING" | sudo tee -a /opt/phpmyadmin/config.inc.php > /dev/null

# Créer la configuration apache2 et l'activer
STRING="Alias /phpmyadmin /opt/phpmyadmin\n\n<Directory /opt/phpmyadmin>\n\n  Options FollowSymLinks\n\n  AllowOverride all\n\n  Require all granted\n\n</Directory>"
echo "$STRING" | sudo tee /etc/apache2/conf-available/phpmyadmin.conf > /dev/null
sudo a2enconf phpmyadmin.conf > /dev/null

# Redémarrer apache2
sudo systemctl restart apache2