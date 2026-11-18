#!/bin/bash
set -euo pipefail
: "${MYSQL_ROOT_PASSWORD:?Define MYSQL_ROOT_PASSWORD}"
: "${MYSQL_APP_PASSWORD:?Define MYSQL_APP_PASSWORD}"
mkdir -p /opt/bitss
test -f /opt/bitss/init.sql
dnf install -y docker
systemctl enable --now docker
docker volume create bitss-mysql-data
docker network create bitss-db-net 2>/dev/null || true
docker rm -f mysql 2>/dev/null || true
docker run -d --name mysql --restart unless-stopped --network bitss-db-net -p 3306:3306 -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" -v bitss-mysql-data:/var/lib/mysql -v /opt/bitss/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro mysql:8.4
until docker exec mysql mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do sleep 5; done
docker exec mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS 'bitss_app'@'%' IDENTIFIED BY '${MYSQL_APP_PASSWORD}'; GRANT ALL PRIVILEGES ON usuario_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON catalogo_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON carro_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON gestion_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON pagos_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON coleccion_db.* TO 'bitss_app'@'%'; GRANT ALL PRIVILEGES ON notificaciones_db.* TO 'bitss_app'@'%'; FLUSH PRIVILEGES;"
