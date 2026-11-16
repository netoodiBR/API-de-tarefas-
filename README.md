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
