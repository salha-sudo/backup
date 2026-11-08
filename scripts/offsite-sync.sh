#!/usr/bin/env bash
# Copie hors site : MinIO (local) --> Azure Blob Storage (cloud). Données déjà chiffrées par restic.
set -euo pipefail
source /etc/backup-platform/backup.env
source /etc/backup-platform/azure.env

METRICS_DIR=/var/lib/backup-metrics
STATE=$METRICS_DIR/offsite_last_success
START=$(date +%s)

write_metrics() {
  local tmp="$METRICS_DIR/offsite.prom.$$"
  {
    echo "offsite_last_status $1"
    echo "offsite_last_success_timestamp_seconds $(cat "$STATE" 2>/dev/null || echo 0)"
    echo "offsite_last_duration_seconds $(( $(date +%s) - START ))"
  } > "$tmp"
  chmod 644 "$tmp"; mv "$tmp" "$METRICS_DIR/offsite.prom"
}
trap 'write_metrics 0; echo "ECHEC copie hors site" >&2; exit 1' ERR

# CA bundle = CA système (pour Azure) + certificat auto-signé MinIO
CA=/etc/backup-platform/ca-bundle.crt
cat /etc/ssl/certs/ca-certificates.crt /opt/backup-platform/certs/public.crt > "$CA"
export RESTIC_CACERT="$CA"

# Source = MinIO ; destination = Azure
export RESTIC_FROM_REPOSITORY="$RESTIC_REPOSITORY"
export RESTIC_FROM_PASSWORD_FILE="$RESTIC_PASSWORD_FILE"
export RESTIC_REPOSITORY="azure:${AZURE_CONTAINER}:/"
export AZURE_ACCOUNT_NAME AZURE_ACCOUNT_KEY

if ! restic cat config >/dev/null 2>&1; then
  echo "Initialisation du dépôt Azure..."
  restic init --copy-chunker-params
fi
restic copy
date +%s > "$STATE"
write_metrics 1
echo "[$(date)] Copie hors site terminée."
