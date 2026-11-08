#!/usr/bin/env bash
set -euo pipefail
source /etc/backup-platform/backup.env

METRICS_DIR=/var/lib/backup-metrics
STATE=$METRICS_DIR/last_success
START=$(date +%s)

write_metrics() {
  local tmp="$METRICS_DIR/backup.prom.$$"
  {
    echo "backup_last_status $1"
    echo "backup_last_run_timestamp_seconds $(date +%s)"
    echo "backup_last_success_timestamp_seconds $(cat "$STATE" 2>/dev/null || echo 0)"
    echo "backup_last_duration_seconds $(( $(date +%s) - START ))"
  } > "$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$METRICS_DIR/backup.prom"
}

on_fail() { write_metrics 0; echo "ECHEC de la sauvegarde" >&2; exit 1; }
trap on_fail ERR

echo "[$(date)] Sauvegarde des fichiers..."
restic backup $SOURCES --tag nightly --exclude-caches

# --- Optionnel : base MySQL (décommente et crée un utilisateur 'backup') ---
# mysqldump -u backup --single-transaction --all-databases \
#   | restic backup --stdin --stdin-filename db.sql --tag mysql

date +%s > "$STATE"
write_metrics 1
echo "[$(date)] Sauvegarde terminée avec succès."
