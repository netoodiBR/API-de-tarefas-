#!/usr/bin/env bash
set -euo pipefail

mkdir -p /opt/api

python3 -m venv /opt/api/venv

/opt/api/venv/bin/pip install --quiet fastapi uvicorn psycopg2-binary

cp /root/api.py /opt/api/api.py
cp /root/api.service /etc/systemd/system/api.service

systemctl daemon-reload
systemctl enable --now api
