#!/usr/bin/env bash
# Installation automatique (partie locale). Lancer : cd /opt/backup-platform && ./scripts/install.sh
set -euo pipefail
cd /opt/backup-platform

echo "== 1/8 Paquets =="
sudo apt update
sudo apt install -y docker.io docker-compose-v2 restic openssl curl apache2-utils
DC="sudo docker compose"

echo "== 2/8 Secrets (.env) =="
if [ ! -f .env ]; then
  cat > .env <<ENV
REST_USER=backup
REST_PASSWORD=$(openssl rand -hex 16)
GRAFANA_ADMIN_PASSWORD=$(openssl rand -hex 12)
ENV
  chmod 600 .env
fi
set -a; source .env; set +a

echo "== 3/8 Certificat TLS =="
mkdir -p certs rest
if [ ! -f certs/public.crt ]; then
  openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
    -keyout certs/private.key -out certs/public.crt -subj "/CN=rest-server" \
    -addext "subjectAltName=DNS:rest-server,DNS:localhost,IP:127.0.0.1"
  chmod 644 certs/private.key certs/public.crt
fi
htpasswd -B -b -c rest/.htpasswd "$REST_USER" "$REST_PASSWORD"
chmod 644 rest/.htpasswd

echo "== 4/8 Démarrage des conteneurs =="
sudo mkdir -p /var/lib/backup-metrics && sudo chmod 755 /var/lib/backup-metrics
$DC up -d --remove-orphans
sleep 8
$DC ps

echo "== 5/8 Configuration restic =="
sudo mkdir -p /etc/backup-platform && sudo chmod 700 /etc/backup-platform
if [ ! -f /etc/backup-platform/restic.pass ]; then
  openssl rand -base64 32 | sudo tee /etc/backup-platform/restic.pass >/dev/null
  sudo chmod 600 /etc/backup-platform/restic.pass
fi
sudo tee /etc/backup-platform/backup.env >/dev/null <<ENV
export RESTIC_REPOSITORY=rest:https://$REST_USER:$REST_PASSWORD@localhost:8000/
export RESTIC_PASSWORD_FILE=/etc/backup-platform/restic.pass
export RESTIC_CACERT=/opt/backup-platform/certs/public.crt
export SOURCES="/home /etc /var/www"
ENV
sudo tee /etc/backup-platform/admin.env >/dev/null <<ENV
export RESTIC_REPOSITORY=rest:https://$REST_USER:$REST_PASSWORD@localhost:8001/
export RESTIC_PASSWORD_FILE=/etc/backup-platform/restic.pass
export RESTIC_CACERT=/opt/backup-platform/certs/public.crt
ENV
sudo bash -c 'chmod 600 /etc/backup-platform/*.env'

echo "== 6/8 Dépôt restic chiffré =="
sudo bash -c 'source /etc/backup-platform/backup.env; restic cat config >/dev/null 2>&1 || restic init'

echo "== 7/8 systemd =="
chmod +x scripts/*.sh
sudo cp systemd/backup.* systemd/backup-maintenance.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now backup.timer backup-maintenance.timer

echo "== 8/8 Premier test =="
sudo systemctl start backup.service || true
journalctl -u backup.service -n 15 --no-pager || true

echo
echo "TERMINE. Mot de passe Grafana (utilisateur admin) : $GRAFANA_ADMIN_PASSWORD"
echo "SAUVEGARDE HORS DE LA VM le mot de passe restic :"
sudo cat /etc/backup-platform/restic.pass
echo "Étape suivante : partie cloud Azure (README.md, section 'Partie cloud')."
