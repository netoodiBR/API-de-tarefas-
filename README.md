# Projeto — Cloud Computing | 

**API de tarefas com FastAPI e PostgreSQL**

## 1. Objetivo

Implantar uma aplicação de tarefas em uma nuvem privada com LXD, separando proxy, aplicação e banco de dados. O projeto demonstra redes PROD e DEV, armazenamento persistente, HTTPS, isolamento de rede, backup e monitoramento.

## 2. Arquitetura

| Componente | Instância | Endereço na rede PROD | Função |
|---|---|---:|---|
| Proxy | `proxy` | `10.10.10.10` | Nginx e publicação HTTP/HTTPS |
| Aplicação | `app` | `10.10.10.11` | API FastAPI |
| Banco | `db` | `10.10.10.12` | PostgreSQL |

- Rede PROD: `net-prod` — `10.10.10.0/24`
- Rede DEV: `net-dev` — `10.10.20.0/24`
- Armazenamento: pool `pool-final`, volume `vol-db`
- Portas publicadas no host: `8081` (HTTP) e `8444` (HTTPS)
- Dados do PostgreSQL: `/dados/pgdata`, dentro do volume `vol-db`

## 3. Pré-requisitos

- VM Ubuntu 24.04 com acesso à internet.
- LXD instalado e inicializado.
- Pelo menos 4 GB de memória livre, conforme o roteiro do projeto.
- Repositório clonado e ferramentas `git`, `curl` e `openssl` disponíveis.

## 4. Preparar uma VM nova

Clone o repositório e entre na pasta do projeto:

```bash
git clone https://github.com/netoodiBR/API-de-tarefas-.git
cd API-de-tarefas-
```

Confira o LXD e os recursos da VM:

```bash
lxc version
lxc project list
lxc storage list
lxc network list
free -h
df -h /
```

Crie e selecione o projeto LXD da equipe:

```bash
lxc project create final-equipe10 -c features.images=false -c features.profiles=false
lxc project switch final-equipe10
```

Crie as redes, o pool e o volume persistente:

```bash
lxc network create net-prod ipv4.address=10.10.10.1/24 ipv4.nat=true ipv6.address=none
lxc network create net-dev ipv4.address=10.10.20.1/24 ipv4.nat=true ipv6.address=none
lxc storage create pool-final dir
lxc storage volume create pool-final vol-db
```

## 5. Criar e validar o serviço

Os perfis e arquivos de configuração ficam nas pastas `profiles/` e `conf/`. Os scripts de implantação e operação ficam em `scripts/`.

Depois de conferir que os arquivos estão presentes e configurados para a Trilha B, execute na raiz do repositório:

```bash
ENV=prod ./scripts/deploy.sh
```

Para criar também o ambiente de desenvolvimento:

```bash
ENV=dev ./scripts/deploy.sh
```

Confira as instâncias:

```bash
lxc list
```

O ambiente PROD deve apresentar `proxy`, `app` e `db` em execução, com os endereços indicados na seção 2.

## 6. Acessar e testar a aplicação

Descubra o IP da VM na interface de rede ativa:

```bash
ip -4 -br addr
```

A API fica disponível pela publicação do proxy em `8081` (HTTP) e `8444` (HTTPS). Como o HTTP pode redirecionar para HTTPS, use preferencialmente o teste abaixo a partir da raiz do repositório, com o certificado público `ca.crt` disponível em `conf/tls/`:

```bash
curl --cacert conf/tls/ca.crt \
  --resolve servico.lab:8444:127.0.0.1 \
  -s https://servico.lab:8444/api/saude

curl --cacert conf/tls/ca.crt \
  --resolve servico.lab:8444:127.0.0.1 \
  -s https://servico.lab:8444/api/tarefas
```

A rota de saúde deve retornar `{"status":"ok"}`; a segunda lista as tarefas cadastradas.

### Acesso pelo navegador

O serviço é acessado em `https://servico.lab:8444`. No computador cliente:

1. Associar o IP atual da VM ao nome `servico.lab` no arquivo `/etc/hosts`.
2. Importar o certificado público `ca.crt` como autoridade certificadora confiável no navegador.

O `ca.crt` pode ser compartilhado com os integrantes. As chaves privadas `ca.key` e `servico.key` devem permanecer protegidas, fora do GitHub. Para reproduzir HTTPS em outra VM, a equipe deve instalar os certificados/chaves por um meio seguro ou gerar um novo par de certificados.

## 7. Persistência e restauração

O PostgreSQL utiliza o volume `vol-db`, montado em `/dados`. Para comprovar a persistência, consulte as tarefas, recrie o container `db` e anexe novamente o mesmo volume. Os registros devem continuar disponíveis pela API.

Para restaurar o snapshot do volume após uma exclusão de dados:

```bash
lxc stop db
lxc storage volume restore pool-final vol-db snap-volume
lxc start db
```

Depois, consulte novamente `/api/tarefas` e confira se os registros do momento do snapshot retornaram. O snapshot `snap-volume` precisa ter sido criado antes da exclusão dos dados.

Para exportar backups em arquivo:

```bash
mkdir -p ~/backup
lxc export db ~/backup/db.tar.gz --instance-only
lxc storage volume export pool-final vol-db ~/backup/vol-db.tar.gz
```

## 8. Monitoramento

Execute o painel de monitoramento disponibilizado no repositório:

```bash
./scripts/monitor.sh
```

## 9. Estrutura do repositório

```text
README.md
scripts/       # implantação, remoção e monitoramento
profiles/      # perfis LXD
conf/          # API, Nginx e configuração do PostgreSQL
docs/evidencias/  # capturas e saídas dos testes
```

## 10. Segurança

- Não versionar senhas, tokens, arquivos `.env` ou chaves privadas (`*.key`).
- Não publicar credenciais do PostgreSQL no README ou nos scripts.
- Compartilhar somente certificados públicos, como `ca.crt`.
