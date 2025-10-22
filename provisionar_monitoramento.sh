#!/bin/bash

# --- Variáveis de Configuração ---
PHP_TIMEZONE="America/Sao_Paulo"

# --- Verificação de Root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script precisa ser executado como root. Use 'su -' e tente novamente."
  exit 1
fi

echo ">>> INICIANDO PROVISIONAMENTO AUTOMATIZADO (Zabbix 7.4 + Grafana)"

# --- Etapa 1: Instalar Dependências e Repositórios ---
echo ">>> Instalando dependências e chaves GPG..."
apt update
apt install -y wget gpg ca-certificates

# 1.1 Repositório Zabbix 7.4
wget -q https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.4+debian13_all.deb
dpkg -i zabbix-release_latest_7.4+debian13_all.deb
rm zabbix-release_latest_7.4+debian13_all.deb

# 1.2 Repositório Grafana
install -m 0755 -d /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

# --- Etapa 2: Instalação dos Pacotes ---
echo ">>> Atualizando repositórios e instalando todos os pacotes..."
apt update
apt install -y \
  zabbix-server-pgsql \
  zabbix-frontend-php \
  zabbix-nginx-conf \
  zabbix-sql-scripts \
  zabbix-agent \
  postgresql \
  nginx \
  grafana

# --- Etapa 3: Gerar Senha e Configurar PostgreSQL ---
echo ">>> Gerando senha segura para o banco de dados..."
# Gera uma senha aleatória de 24 caracteres
DB_PASSWORD=$(openssl rand -base64 24)

# Salva a senha para o usuário (necessário para o setup web)
echo "Senha do banco de dados Zabbix: $DB_PASSWORD" > /opt/zabbix_db_password.txt
chmod 400 /opt/zabbix_db_password.txt

echo ">>> Configurando PostgreSQL (usuário e banco)..."
# Cria o usuário 'zabbix' com a senha gerada (não interativo)
su - postgres -c "psql -c \"CREATE USER zabbix WITH PASSWORD '$DB_PASSWORD';\""
# Cria o banco 'zabbix'
su - postgres -c "createdb -O zabbix zabbix"

# --- Etapa 4: Importar Schema do Zabbix ---
echo ">>> Importando schema do Zabbix (isso pode levar um minuto)..."
# Usa a variável PGPASSWORD para passar a senha de forma não-interativa
PGPASSWORD="$DB_PASSWORD" zcat /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz | psql -U zabbix -d zabbix -h localhost

# --- Etapa 5: Configurar Arquivos (Zabbix, PHP, Nginx) ---
echo ">>> Configurando zabbix_server.conf..."
# Encontra a linha '# DBPassword=' e a substitui, inserindo a senha
sed -i "s/# DBPassword=/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf

echo ">>> Configurando PHP 8.4 (Timezone)..."
# Usa '|' como separador do sed por causa das barras no nome do timezone
sed -i "s|;date.timezone =|date.timezone = $PHP_TIMEZONE|" /etc/php/8.4/fpm/php.ini

echo ">>> Configurando Nginx (Porta 80)..."
# Descomenta e altera a porta 8080 para 80
sed -i 's/#   listen          8080;/    listen          80;/' /etc/zabbix/nginx.conf
# Descomenta e altera o server_name para '_'
sed -i 's/#   server_name     example.com;/    server_name     _;/' /etc/zabbix/nginx.conf

# --- Etapa 6: Iniciar e Habilitar Serviços ---
echo ">>> Iniciando e habilitando todos os serviços..."
systemctl restart zabbix-server zabbix-agent nginx php8.4-fpm grafana-server
systemctl enable zabbix-server zabbix-agent nginx php8.4-fpm grafana-server

# --- Conclusão ---
echo "--------------------------------------------------------"
echo "--- PROVISIONAMENTO AUTOMATIZADO CONCLUÍDO ---"
echo ""
echo "!!! IMPORTANTE !!!"
echo "A senha do banco de dados foi gerada e salva em:"
echo "/opt/zabbix_db_password.txt"
echo ""
echo "Você precisará desta senha ao acessar o setup web do Zabbix."
echo "--------------------------------------------------------"
echo "Acesse o Zabbix: http://<ip_do_servidor>"
echo "Acesse o Grafana: http://<ip_do_servidor>:3000"
echo "--------------------------------------------------------"
