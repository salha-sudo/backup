#!/usr/bin/env bash
# PRA : restauration depuis Azure si le site local est perdu.
# Usage : sudo ./restore-from-cloud.sh [snapshot_id|latest] [dossier_cible]
set -euo pipefail
source /etc/backup-platform/azure.env
export RESTIC_REPOSITORY="azure:${AZURE_CONTAINER}:/"
export RESTIC_PASSWORD_FILE=/etc/backup-platform/restic.pass
export AZURE_ACCOUNT_NAME AZURE_ACCOUNT_KEY
SNAP=${1:-latest}; TARGET=${2:-/restore-cloud}
mkdir -p "$TARGET"
restic restore "$SNAP" --target "$TARGET"
echo "Restauration cloud dans $TARGET terminée."
