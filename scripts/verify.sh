#!/usr/bin/env bash
set -euo pipefail
source /etc/backup-platform/backup.env
TMP=$(mktemp -d); START=$(date +%s)
restic restore latest --target "$TMP" --include /etc/hostname
if [ -s "$TMP/etc/hostname" ] && diff -q /etc/hostname "$TMP/etc/hostname"; then
  echo "OK : restauration vérifiée en $(( $(date +%s) - START )) s (RTO mesuré)."
else
  echo "ERREUR : restauration invalide" >&2; exit 1
fi
rm -rf "$TMP"
