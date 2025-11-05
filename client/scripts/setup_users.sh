#!/bin/bash
# /home/user/backup-poc/client/scripts/setup_users.sh
# Dieses Skript wird von einem Sudo-Nutzer ausgeführt.

set -e

# Definitionen
# Der Nutzer, der 'sudo' aufgerufen hat, ist der Besitzer der Daten
DATA_OWNER=${SUDO_USER}

ENCODER_USER="backup_encoder"
PULL_USER="backup_puller"
PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-"puller-temp-password"}

SOURCE_DIR="/home/${DATA_OWNER}"
ENCRYPTED_DIR="/data/encrypted_stage"

# Backup-spezifische Nutzer anlegen (benötigt sudo)
echo "=> Lege Backup-System-Nutzer an..."

if ! id -u ${ENCODER_USER} > /dev/null 2>&1; then
    sudo adduser --system --group --no-create-home --shell /bin/false ${ENCODER_USER}
fi

if ! id -u ${PULL_USER} > /dev/null 2>&1; then
    sudo adduser --system --group --home /home/${PULL_USER} --shell /bin/bash ${PULL_USER}
fi

# Temporäres Passwort setzen, damit der Schlüsseltransfer per SSH (Passwort) möglich ist
echo "${PULL_USER}:${PULL_USER_PASSWORD}" | sudo chpasswd

# Verzeichnisse und Berechtigungen anpassen
echo "=> Konfiguriere Verzeichnisse und Berechtigungen..."

# Erstelle das Verzeichnis für verschlüsselte Daten
sudo mkdir -p ${ENCRYPTED_DIR}
sudo chown ${ENCODER_USER}:${ENCODER_USER} ${ENCRYPTED_DIR}
sudo chmod 750 ${ENCRYPTED_DIR}

# Zugriffsrechte einrichten
echo "=> Richte gruppenbasierte Zugriffsrechte ein..."

# 'backup_encoder' darf Daten vom DATA_OWNER lesen
#sudo usermod -aG ${DATA_OWNER} ${ENCODER_USER}
# set access ACLs and default ACLs recursively so existing and new files are readable by the encoder user
sudo setfacl -R -m u:${ENCODER_USER}:rx ${SOURCE_DIR}
sudo setfacl -R -m d:u:${ENCODER_USER}:rx ${SOURCE_DIR}

# 'backup_puller' darf verschlüsselte Daten vom ENCODER_USER lesen
#sudo usermod -aG ${ENCODER_USER} ${PULL_USER}
sudo setfacl -R -m u:${PULL_USER}:r ${ENCRYPTED_DIR}
sudo setfacl -R -m d:u:${PULL_USER}:r ${ENCRYPTED_DIR}

# SSH-Zugang für den Pull-Nutzer vorbereiten
SSH_DIR="/home/${PULL_USER}/.ssh"
AUTH_KEYS_FILE="${SSH_DIR}/authorized_keys"

sudo mkdir -p ${SSH_DIR}
sudo touch ${AUTH_KEYS_FILE}
sudo chown -R ${PULL_USER}:${PULL_USER} ${SSH_DIR}
sudo chmod 700 ${SSH_DIR}
sudo chmod 600 ${AUTH_KEYS_FILE}

# Dem Pull-Nutzer erlauben, das eigene Passwort zu sperren, nachdem der Schlüssel kopiert wurde
SUDOERS_FILE="/etc/sudoers.d/${PULL_USER}"
if [ ! -f ${SUDOERS_FILE} ]; then
    sudo bash -c "echo '${PULL_USER} ALL=(root) NOPASSWD: /usr/bin/passwd -l ${PULL_USER}' > ${SUDOERS_FILE}"
    sudo chmod 440 ${SUDOERS_FILE}
fi

# Passwort-Authentifizierung explizit aktivieren (wird nach dem Schlüsseltransfer wieder deaktiviert)
if sudo grep -qE '^\s*PasswordAuthentication' /etc/ssh/sshd_config; then
    sudo sed -i 's|^\s*PasswordAuthentication.*|PasswordAuthentication yes|' /etc/ssh/sshd_config
else
    echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi

echo "Setup durch ${DATA_OWNER} erfolgreich abgeschlossen."
