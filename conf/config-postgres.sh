#!/usr/bin/env bash
set -euo pipefail

APP_IP="$1"
BASE="$2"
USUARIO="$3"
SENHA="$4"
VER=$(ls /etc/postgresql)
CONF=/etc/postgresql/$VER/main

/usr/bin/pg_ctlcluster "$VER" main stop || true

if [ ! -d /dados/pgdata ]; then
	mkdir /dados/pgdata
	cp -a /var/lib/postgresql/$VER/main/. /dados/pgdata/
fi

chown -R postgres:postgres /dados/pgdata
chmod 700 /dados/pgdata

sed -i "s#^[#]*data_directory.*#data_directory = '/dados/pgdata'#" "$CONF/postgresql.conf"
sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" $CONF/postgresql.conf

grep -q "$APP_IP" $CONF/pg_hba.conf || echo "host $BASE $USUARIO $APP_IP/32 scram-sha-256" >> $CONF/pg_hba.conf

/usr/bin/pg_ctlcluster "$VER" main start

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$USUARIO'" | grep -q 1 ||
sudo -u postgres psql -c "CREATE ROLE $USUARIO LOGIN ENCRYPTED PASSWORD '$SENHA';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$BASE'" | grep -q 1 ||
sudo -u postgres psql -c "CREATE DATABASE $BASE OWNER $USUARIO;"

sudo -u postgres psql -d "$BASE" -c "CREATE TABLE IF NOT EXISTS tarefas (id SERIAL PRIMARY KEY, titulo TEXT NOT NULL, feita BOOLEAN DEFAULT false); ALTER TABLE tarefas OWNER TO $USUARIO;"

