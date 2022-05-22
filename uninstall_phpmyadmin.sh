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

echo "--- Removing PhpMyAdmin from Apache... ---"
a2disconf phpmyadmin.conf > /dev/null
systemctl restart apache2

echo "--- Removing PhpMyAdmin files... ---"
rm -rf /opt/phpmyadmin /etc/apache2/conf-available/phpmyadmin.conf /var/lib/phpmyadmin

echo "--- Removing PhpMyAdmin databases... ---"
mysql --user=root --password=$ROOTPASS -e "DROP DATABASE phpmyadmin;"
mysql --user=root --password=$ROOTPASS -e "DROP USER 'pma'@'localhost';"

echo "--- Uninstallation finished ---"
