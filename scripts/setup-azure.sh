#!/usr/bin/env bash
# Récupère les sorties Terraform et crée /etc/backup-platform/azure.env, puis active la copie hors site.
# À lancer sur la VM, depuis /opt/backup-platform/terraform, après "terraform apply".
set -euo pipefail
cd /opt/backup-platform/terraform
NAME=$(terraform output -raw storage_account_name)
KEY=$(terraform output -raw storage_account_key)
CONT=$(terraform output -raw container_name)
sudo tee /etc/backup-platform/azure.env >/dev/null <<ENV
export AZURE_ACCOUNT_NAME=$NAME
export AZURE_ACCOUNT_KEY=$KEY
export AZURE_CONTAINER=$CONT
ENV
sudo chmod 600 /etc/backup-platform/azure.env
sudo cp /opt/backup-platform/systemd/offsite.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now offsite.timer
sudo systemctl start offsite.service
journalctl -u offsite.service -n 20 --no-pager
