# Projeto - Cloud Computing

## Serviço
Trilha: API de tarefas com PostgreSQL

## Arquitetura
- proxy: Nginx, IP 10.10.10.10
- app: API FastAPI, IP 10.10.10.11
- db: PostgreSQL, IP 10.10.10.12

## Redes
- PROD: net-prod, 10.10.10.0/24
- DEV: net-dev, 10.10.20.0/24

## Armazenamento
- pool: pool-final
- volume persistente do PostgreSQL: vol-db

## Procedimento de Restauração (Fase 6)
1. Pare a instância do banco de dados antes de restaurar (`lxc stop db`) para evitar corrupção durante a gravação.
2. Restaure o volume persistente a partir do snapshot com `lxc storage volume restore pool-final vol-db snap-volume`.
3. Inicie novamente a instância (`lxc start db`) e valide os dados pela API (`curl -k https://<IP-DA-VM>:8444/api/tarefas`).
4. Para recuperar backups externos (`.tar.gz`), importe a instância (`lxc import`) e o volume (`lxc storage volume import`) antes de anexá-los.
5. Os snapshots automáticos diários com retenção de 7 dias ficam ativos em `db` e `vol-db`.
