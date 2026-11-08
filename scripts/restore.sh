#!/usr/bin/env bash
# Usage : sudo ./restore.sh [snapshot_id|latest] [dossier_cible] [chemin_a_restaurer]
set -euo pipefail
source /etc/backup-platform/backup.env
SNAP=${1:-latest}; TARGET=${2:-/restore}; INCLUDE=${3:-}
mkdir -p "$TARGET"
if [ -n "$INCLUDE" ]; then restic restore "$SNAP" --target "$TARGET" --include "$INCLUDE"
else restic restore "$SNAP" --target "$TARGET"; fi
echo "Restauration dans $TARGET terminée."
