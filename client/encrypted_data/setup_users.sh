#!/bin/bash
# /home/user/backup-poc/client/scripts/setup_users.sh
# Dieses Skript wird von einem Sudo-Nutzer ausgeführt.

set -e

# --- 1. Definitionen ---
# Der Nutzer, der 'sudo' aufgerufen hat, ist der Besitzer der Daten
DATA_OWNER=${SUDO_USER}

ENCODER_USER="backup_encoder"
PULL_USER="backup_puller"

SOURCE_DIR="/home/${DATA_OWNER}"
ENCRYPTED_DIR="/data/encrypted_stage"

# --- 2. Backup-spezifische Nutzer anlegen (benötigt sudo) ---
echo "=> Lege Backup-System-Nutzer an..."

if ! id -u ${ENCODER_USER} > /dev/null 2>&1; then
    sudo adduser --system --group --no-create-home --shell /bin/false ${ENCODER_USER}
fi

if ! id -u ${PULL_USER} > /dev/null 2>&1; then
    sudo adduser --system --group --home /home/${PULL_USER} --shell /bin/bash ${PULL_USER}
fi

# --- 3. Verzeichnisse und Berechtigungen anpassen ---
echo "=> Konfiguriere Verzeichnisse und Berechtigungen..."

# Erstelle das Verzeichnis für verschlüsselte Daten
sudo mkdir -p ${ENCRYPTED_DIR}
sudo chown ${ENCODER_USER}:${ENCODER_USER} ${ENCRYPTED_DIR}
sudo chmod 750 ${ENCRYPTED_DIR}

# --- 4. Zugriffsrechte einrichten ---
echo "=> Richte gruppenbasierte Zugriffsrechte ein..."

# 'backup_encoder' darf Daten vom DATA_OWNER lesen
#sudo usermod -aG ${DATA_OWNER} ${ENCODER_USER}
sudo setfacl -m u:${ENCODER_USER}:r-x ${SOURCE_DIR}

# 'backup_puller' darf verschlüsselte Daten vom ENCODER_USER lesen
#sudo usermod -aG ${ENCODER_USER} ${PULL_USER}
sudo setfacl -m u:${PULL_USER}:r-x ${ENCRYPTED_DIR}

# --- 5. SSH-Zugang für den Pull-Nutzer vorbereiten ---
SSH_DIR="/home/${PULL_USER}/.ssh"
AUTH_KEYS_FILE="${SSH_DIR}/authorized_keys"

sudo mkdir -p ${SSH_DIR}
sudo touch ${AUTH_KEYS_FILE}
sudo chown -R ${PULL_USER}:${PULL_USER} ${SSH_DIR}
sudo chmod 700 ${SSH_DIR}
sudo chmod 600 ${AUTH_KEYS_FILE}

echo "Setup durch ${DATA_OWNER} erfolgreich abgeschlossen."
