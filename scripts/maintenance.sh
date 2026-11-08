#!/usr/bin/env bash
# Rétention + vérification d'intégrité. Démarre temporairement l'instance admin (sans append-only).
set -euo pipefail
cd /opt/backup-platform
docker compose --profile admin up -d rest-server-admin
trap 'docker compose --profile admin stop rest-server-admin >/dev/null 2>&1 || true' EXIT
sleep 4
source /etc/backup-platform/admin.env
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
restic check --read-data-subset=5%
