#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-prod}"
PROJETO="final-equipe10"
POOL="pool-final"

if [[ "$ENV" == "prod" ]]; then
    PREFIXO=""
elif [[ "$ENV" == "dev" ]]; then
    PREFIXO="dev-"
else
    echo "Erro: use ENV=prod ou ENV=dev"
    exit 1
fi

if ! lxc project show "$PROJETO" >/dev/null 2>&1; then
    echo "Projeto $PROJETO não existe."
    exit 1
fi

lxc project switch "$PROJETO"

for nome in "${PREFIXO}proxy" "${PREFIXO}app" "${PREFIXO}db"; do
    if lxc info "$nome" >/dev/null 2>&1; then
        echo "Removendo $nome..."
        lxc delete "$nome" --force
    fi
done

if [[ "${1:-}" == "--volumes" ]]; then
    VOLUME="${PREFIXO}vol-db"

    if lxc storage volume show "$POOL" "$VOLUME" >/dev/null 2>&1; then
        echo "Removendo volume $VOLUME..."
        lxc storage volume delete "$POOL" "$VOLUME"
    fi
fi

echo "Ambiente $ENV removido."
