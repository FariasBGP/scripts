#!/bin/bash
#
# Esse script de instalação foi baseado na apostila do curso Wanguard ministrado por Raphael ISP
# https://raphaelisp.com.br/
#  


apt-get -y update
apt-get -y upgrade

# Instalar pacotes
apt-get -y install apt-transport-https
apt-get -y install wget
apt-get -y install gnupg
apt-get -y install python3-pysimplesoap

# time-zone
apt-get -y install ntpdate
apt-get -y install systemd-timesyncd

# Sincronismo data hora
timedatectl set-timezone America/Sao_Paulo
ntpdate a.ntp.br

# config de data hora:
 (
 echo
 echo '[Time]'
 echo 'NTP=200.160.0.8'
 echo 'FallbackNTP=2001:12ff::8'
 echo '#RootDistanceMaxSec=5'
 echo '#PollIntervalMinSec=32'
 echo '#PollIntervalMaxSec=2048'
 echo
 ) > /etc/systemd/timesyncd.conf

 # Atualizar timectl:
 timedatectl set-ntp true
 timedatectl status

# repositorios
wget -O - https://www.andrisoft.com/andrisoft.gpg.key | gpg --dearmor --yes --output /usr/share/keyrings/andrisoft-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/andrisoft-keyring.gpg] https://www.andrisoft.com/files/debian12 bookworm main" > /etc/apt/sources.list.d/andrisoft.list

# Instalar pacotes essenciais:
 apt update
 apt-get -y install wanbgp
 apt-get -y install python3-pip
 apt-get -y install exabgp
 apt-get -y install wanconsole
 apt-get -y install wansupervisor
 apt-get -y install wanfilter

# Fixar timezone no PHP 8 (coloque o mesmo timezone do sistema)
 sed -i 's#;date.timezone.*#date.timezone=America/Sao_Paulo#g' \
 /etc/php/8.2/apache2/php.ini \
 /etc/php/8.2/cli/php.ini

# Config do apache:
 sed -i 's#/var/www/html#/opt/andrisoft/webroot#g' /etc/apache2/sites-available/000-default.conf
 ln -sf /opt/andrisoft/etc/andrisoft_apache.conf /etc/apache2/conf-enabled/andrisoft_apache.conf

# Config mariadb
 mysqladmin -u root password P455w0rd
 sed -i '/^[^#]/ s/\(^.*bind-address.*$\)/#\ \1/' /etc/mysql/mariadb.conf.d/50-server.cnf

# Reiniciar servicos dependentes:
 systemctl restart mariadb
 systemctl restart apache2

#Configuração do wanguard
/opt/andrisoft/bin/install_console
/opt/andrisoft/bin/install_supervisor
systemctl start WANsupervisor
systemctl enable WANsupervisor

#influxdb
wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb
dpkg -i ./influxdb_1.8.10_amd64.deb
cp /etc/influxdb/influxdb.conf /etc/influxdb/influxdb.conf.backup
cp /opt/andrisoft/etc/influxdb.conf /etc/influxdb/influxdb.conf
systemctl restart influxdb
/opt/andrisoft/bin/install_influxdb
