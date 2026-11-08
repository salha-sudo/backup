# Plateforme cloud sécurisée de sauvegarde et restauration

Architecture hybride 100 % gratuite :

```
 VM Ubuntu (site local)                                   Cloud (Azure for Students)
 ┌────────────────────────────────────┐   restic copy   ┌──────────────────────────┐
 │ restic (chiffrement AES-256 client)│ ──────────────► │ Blob Storage (versioning,│
 │   └─► rest-server S3 en TLS (écriture    │   HTTPS/TLS     │ soft-delete 30 j, privé) │
 │        seule, versioning)          │                 │ créé avec Terraform      │
 │ systemd timers (02:00 / 03:30)     │                 └──────────────────────────┘
 │ Prometheus + Grafana (alertes)     │
 │ ufw + fail2ban + SSH par clés      │
 └────────────────────────────────────┘
```

Les données sont chiffrées **avant** de quitter la VM : Azure ne voit jamais rien en clair.
Règle 3-2-1 : données d'origine + dépôt rest-server + copie Azure (2 supports, 1 hors site).

## 1. Partie locale (VM)

1. Crée une VM Ubuntu Server 24.04 (VirtualBox : 2 CPU, 4 Go RAM, 30 Go).
2. Copie le projet dans `/opt/backup-platform` :
   ```bash
   sudo mkdir -p /opt/backup-platform && sudo chown $USER: /opt/backup-platform
   sudo apt install -y unzip
   unzip backup-platform.zip -d /opt/backup-platform     # adapte le chemin si besoin
   cd /opt/backup-platform
   ```
   (le zip contient directement le contenu du projet ; vérifie avec `ls` que `scripts/` est bien dans `/opt/backup-platform`)
3. Lance l'installation : `./scripts/install.sh`
4. **Note** le mot de passe restic affiché (Bitwarden). Sans lui, les sauvegardes sont irrécupérables.
5. Vérifie : `docker compose ps` et `systemctl list-timers | grep backup`.

Accès aux interfaces depuis ton PC (tunnel SSH) :
`ssh -L 3000:localhost:3000 -L 9090:localhost:9090 user@ip_vm`
→ Grafana `http://localhost:3000`, Prometheus `http://localhost:9090`.

## 2. Partie cloud (Azure for Students + Terraform)

1. Active ton offre sur https://azure.microsoft.com/free/students (mail universitaire, sans carte).
2. Sur la VM, installe Azure CLI et Terraform :
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   sudo snap install terraform --classic
   ```
3. Connecte-toi : `az login --use-device-code` (ouvre le lien sur ton PC).
4. Récupère l'ID d'abonnement : `az account show --query id -o tsv`
5. Déploie :
   ```bash
   cd /opt/backup-platform/terraform
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars          # colle ton subscription_id
   terraform init
   terraform apply                # tape "yes"
   ```
   Si la région est refusée, change `location` (swedencentral, northeurope...).
6. Active la copie hors site automatique :
   ```bash
   cd /opt/backup-platform && ./scripts/setup-azure.sh
   ```
7. Vérifie dans le portail Azure (Comptes de stockage → conteneur `offsite`) que des blobs sont apparus.

Sécurité côté cloud : TLS 1.2 minimum, HTTPS obligatoire, accès public interdit, versioning et suppression
récupérable 30 jours. Pour aller plus loin : activer l'immutabilité (WORM) du conteneur dans le portail,
et créer un budget d'alerte (Cost Management).

Après la démo, supprime tout : `cd terraform && terraform destroy`.

## 3. Utilisation

| Action | Commande |
|---|---|
| Sauvegarde manuelle | `sudo systemctl start backup.service` |
| Copie hors site manuelle | `sudo systemctl start offsite.service` |
| Lister les snapshots | `sudo bash -c 'source /etc/backup-platform/backup.env; restic snapshots'` |
| Restaurer (tout) | `sudo ./scripts/restore.sh latest /restore` |
| Restaurer (un dossier) | `sudo ./scripts/restore.sh latest /restore /etc/ssh` |
| Restaurer depuis le cloud (PRA) | `sudo ./scripts/restore-from-cloud.sh latest /restore-cloud` |
| Test auto + RTO | `sudo ./scripts/verify.sh` |
| Durcissement VM | `./scripts/hardening.sh` (ajoute ta clé SSH avant !) |

Reprise après sinistre complète : nouvelle VM, recopier le projet, recréer `/etc/backup-platform/restic.pass`
(depuis ton gestionnaire de mots de passe) et `azure.env`, puis `restore-from-cloud.sh`.

## 4. Tests à documenter (captures)

1. Sauvegarde + snapshot créé
2. Restauration complète / partielle
3. `verify.sh` (RTO mesuré)
4. `restic check` sans erreur
5. **Ransomware** : avec les identifiants de sauvegarde, toute suppression est refusée (mode append-only) :
   ```bash
   sudo bash -c 'source /etc/backup-platform/backup.env
   ID=$(restic snapshots --json | python3 -c "import sys,json;print(json.load(sys.stdin)[0][\"short_id\"])")
   restic forget $ID'
   ```
   Résultat attendu : erreur *403 Forbidden* (ou « permission denied »). Variante :
   ```bash
   source /opt/backup-platform/.env
   curl -sk -u "$REST_USER:$REST_PASSWORD" -X DELETE https://localhost:8000/config -o /dev/null -w "%{http_code}\n"
   ```
   doit afficher `403`.
6. Sinistre : supprimer `/home/test`, restaurer ; puis restaurer depuis Azure
7. Alerte Prometheus (`:9090/alerts`) en coupant Docker ou après échec de copie
8. Scan : `sudo ufw status`, `nmap -p- localhost`

## 5. Dashboard Grafana

Dashboards → New → ajoute des panneaux avec :
`backup_last_status`, `time() - backup_last_success_timestamp_seconds`, `backup_last_duration_seconds`,
`offsite_last_status`, `time() - offsite_last_success_timestamp_seconds`, `rest_server_blob_write_bytes_total` (ou tape `rest_server` dans l'explorateur de métriques).

## Notes

- MinIO n'étant plus téléchargeable gratuitement, le stockage local utilise **restic rest-server** (image Docker Hub `restic/rest-server`).
  La maintenance (`maintenance.sh`) démarre brièvement une instance admin sur le port 8001, sans append-only.
- Les certificats sont auto-signés (lab). Ne commit jamais `.env`, `certs/` ni `terraform.tfvars`.
