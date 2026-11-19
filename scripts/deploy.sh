#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-prod}"
PROJETO="final-equipe10"
POOL="pool-final"
IMAGEM="ubuntu:24.04"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DB_PASS="Troque123"
DB_USER="apiuser"
DB_NAME="tarefas"

if [[ "$ENV" == "prod" ]]; then
    REDE="net-prod"
    SUBNET="10.10.10"
    PREFIXO=""
    PORTA_HTTP="8081"
    PORTA_HTTPS="8444"
elif [[ "$ENV" == "dev" ]]; then
    REDE="net-dev"
    SUBNET="10.10.20"
    PREFIXO="dev-"
    PORTA_HTTP="8082"
    PORTA_HTTPS="8445"
else
    echo "Erro: use ENV=prod ou ENV=dev"
    exit 1
fi

DB="${PREFIXO}db"
APP="${PREFIXO}app"
PROXY="${PREFIXO}proxy"

echo "Implantando ambiente: $ENV"

for arquivo in \
    conf/config-postgres.sh \
    conf/instala-api.sh \
    conf/api.py \
    conf/api.service \
    conf/nginx-servico.conf \
    conf/index.html \
; do
    [[ -f "$BASE_DIR/$arquivo" ]] || {
        echo "Arquivo ausente: $arquivo"
        exit 1
    }
done

mkdir -p "$BASE_DIR/conf/tls"

if [[ ! -f "$BASE_DIR/conf/tls/servico.crt" || ! -f "$BASE_DIR/conf/tls/servico.key" ]]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$BASE_DIR/conf/tls/servico.key" \
        -out "$BASE_DIR/conf/tls/servico.crt" \
        -subj "/CN=servico.lab" \
        -addext "subjectAltName=DNS:servico.lab"
    chmod 600 "$BASE_DIR/conf/tls/servico.key"
fi

lxc project show "$PROJETO" >/dev/null 2>&1 || lxc project create "$PROJETO"
lxc project switch "$PROJETO"

lxc network show "$REDE" >/dev/null 2>&1 || \
    lxc network create "$REDE" \
    ipv4.address="$SUBNET.1/24" \
    ipv4.nat=true ipv6.address=none

lxc storage show "$POOL" >/dev/null 2>&1 || \
    lxc storage create "$POOL" dir

lxc storage volume show "$POOL" "${PREFIXO}vol-db" >/dev/null 2>&1 || \
    lxc storage volume create "$POOL" "${PREFIXO}vol-db"

# Preserva os perfis globais existentes.
for p in perfil-base perfil-proxy perfil-app perfil-db; do
    if ! lxc profile show "$p" >/dev/null 2>&1; then
        lxc profile create "$p"
        lxc profile edit "$p" < "$BASE_DIR/profiles/$p.yaml"
    fi
done

criar_instancia() {
    local nome="$1"
    local perfil="$2"
    local ip="$3"

    if lxc info "$nome" >/dev/null 2>&1; then echo "ERRO: $nome já existe. Não será apagado."; exit 1; fi

    lxc init "$IMAGEM" "$nome" \
        -p perfil-base -p "$perfil"

    lxc config device override "$nome" eth0 \
        network="$REDE" ipv4.address="$ip"
}

iniciar() {
    lxc start "$1"
    lxc exec "$1" -- cloud-init status --wait
}

# BANCO DE DADOS
echo "Criando PostgreSQL..."

criar_instancia "$DB" perfil-db "$SUBNET.12"

lxc config device add "$DB" dados disk \
    pool="$POOL" source="${PREFIXO}vol-db" path=/dados

iniciar "$DB"

lxc file push "$BASE_DIR/conf/config-postgres.sh" \
    "$DB/tmp/config-postgres.sh"

lxc exec "$DB" -- bash /tmp/config-postgres.sh \
    "$SUBNET.11" "$DB_NAME" "$DB_USER" "$DB_PASS"

# API
echo "Criando API..."

criar_instancia "$APP" perfil-app "$SUBNET.11"
iniciar "$APP"

lxc file push "$BASE_DIR/conf/api.py" "$APP/root/api.py"
lxc file push "$BASE_DIR/conf/api.service" "$APP/root/api.service"
lxc file push "$BASE_DIR/conf/instala-api.sh" "$APP/root/instala-api.sh"

lxc exec "$APP" -- bash -c \
    "mkdir -p /etc/api &&
    printf 'DB_HOST=%s\nDB_PASS=%s\n' '$SUBNET.12' '$DB_PASS' > /etc/api/api.env &&
    chmod 600 /etc/api/api.env"

lxc exec "$APP" -- bash /root/instala-api.sh

# PROXY NGINX
echo "Criando proxy..."

criar_instancia "$PROXY" perfil-proxy "$SUBNET.10"
iniciar "$PROXY"

lxc file push "$BASE_DIR/conf/index.html" \
    "$PROXY/var/www/html/index.html"

lxc file push "$BASE_DIR/conf/tls/servico.crt" \
    "$PROXY/etc/ssl/certs/servico.crt"

lxc file push "$BASE_DIR/conf/tls/servico.key" \
    "$PROXY/etc/ssl/private/servico.key"

lxc exec "$PROXY" -- chmod 600 /etc/ssl/private/servico.key

TEMP_NGINX="$(mktemp)"
sed -e "s/10.10.10.11/$SUBNET.11/g" \
    -e "s/8444/$PORTA_HTTPS/g" \
    "$BASE_DIR/conf/nginx-servico.conf" > "$TEMP_NGINX"

lxc file push "$TEMP_NGINX" \
    "$PROXY/etc/nginx/sites-available/default"

rm -f "$TEMP_NGINX"

lxc exec "$PROXY" -- nginx -t
lxc exec "$PROXY" -- systemctl restart nginx

# PORTAS EXTERNAS
lxc config device add "$PROXY" porta-http proxy \
    listen="tcp:0.0.0.0:$PORTA_HTTP" \
    connect=tcp:127.0.0.1:80

lxc config device add "$PROXY" porta-https proxy \
    listen="tcp:0.0.0.0:$PORTA_HTTPS" \
    connect=tcp:127.0.0.1:443

IP_VM="$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"

echo
echo "=================================="
echo "AMBIENTE $ENV IMPLANTADO!"
echo "=================================="
echo "HTTP:  http://$IP_VM:$PORTA_HTTP"
echo "HTTPS: https://$IP_VM:$PORTA_HTTPS"
echo "API:   http://$SUBNET.11:8000/api/saude"
