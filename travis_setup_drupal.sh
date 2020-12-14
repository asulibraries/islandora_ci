#!/bin/bash
echo "Setup database for Drupal"
mysql -u root -e 'create database drupal;'
mysql -u root -e "GRANT ALL PRIVILEGES ON drupal.* To 'drupal'@'127.0.0.1' IDENTIFIED BY 'drupal';"

echo "Composer install drupal site"
cd /opt
composer create-project drupal/recommended-project:9.1.0 drupal
cd drupal
if [ -z "$COMPOSER_PATH" ]; then
  composer install
else
  php -dmemory_limit=-1 $COMPOSER_PATH install
fi

sudo ln -s /opt/vendor/bin/phpcs /usr/bin/phpcs
sudo ln -s /opt/vendor/bin/phpcpd /usr/bin/phpcpd
phpenv rehash
phpcs --config-set installed_paths /opt/vendor/drupal/coder/coder_sniffer

composer require drush/drush
echo "Setup Drush"
sudo ln -s /opt/drupal/vendor/bin/drush /usr/bin/drush
phpenv rehash

echo "Drush setup drupal site"
cd web
drush si --db-url=mysql://drupal:drupal@127.0.0.1/drupal --yes
drush runserver 127.0.0.1:8282 &
until curl -s 127.0.0.1:8282; do true; done > /dev/null
echo "Enable simpletest module"
drush --uri=127.0.0.1:8282 en -y simpletest

# Install pdfjs
cd /opt/drupal
if [ -z "$COMPOSER_PATH" ]; then
  composer require "zaporylie/composer-drupal-optimizations:^1.0" "drupal/pdf:1.x-dev"
else
  php -dmemory_limit=-1 $COMPOSER_PATH require "zaporylie/composer-drupal-optimizations:^1.0" "drupal/pdf:1.x-dev"
fi

cd web
mkdir libraries
cd libraries
wget "https://github.com/mozilla/pdf.js/releases/download/v2.0.943/pdfjs-2.0.943-dist.zip"
mkdir pdf.js
unzip pdfjs-2.0.943-dist.zip -d pdf.js
rm pdfjs-2.0.943-dist.zip

cd ..
drush -y en pdf

echo "Setup ActiveMQ"
cd /opt
wget "http://archive.apache.org/dist/activemq/5.14.3/apache-activemq-5.14.3-bin.tar.gz"
tar -xzf apache-activemq-5.14.3-bin.tar.gz
apache-activemq-5.14.3/bin/activemq start
