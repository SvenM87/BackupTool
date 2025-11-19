#!/bin/sh
# /home/user/backup-poc/server/scripts/setup_server.sh

set -e

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}
PULL_USER=${PULL_USER:-backup_puller}
PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-"puller-temp-password"}
SSH_DIR="/home/${PULL_USER}/.ssh"
SSH_KEY_PATH="/home/${PULL_USER}/.ssh/id_ed25519"
PUB_KEY_PATH="/home/${PULL_USER}/.ssh/id_ed25519.pub"
KNOWN_HOSTS="/home/${PULL_USER}/.ssh/known_hosts"
LOCAL_REPO_PATH=${LOCAL_REPO_PATH:-/data/restic_repo}
FORMAT="\n\e[1;94m=> %s\e[0m\n"

# Benötigte Pakete installieren
printf "${FORMAT}" "Installiere benötigte Pakete..."
apt-get update > /dev/null
apt-get install -y openssh-client sshpass rsync > /dev/null

if ! id -u ${PULL_USER} > /dev/null 2>&1; then
    printf "${FORMAT}" "Erstelle PULL_USER '${PULL_USER}'..."
    # Erstellen als Systemnutzer (Server braucht keine interaktive Shell)
    useradd --system --create-home --shell /bin/false ${PULL_USER}
fi

printf "${FORMAT}" "Lege Verzeichnisse an und setze Berechtigungen..."
mkdir -p "${LOCAL_REPO_PATH}" "${SSH_DIR}"
chown "${PULL_USER}":"${PULL_USER}" "${LOCAL_REPO_PATH}"
chmod 750 "${LOCAL_REPO_PATH}"
chmod 700 "${SSH_DIR}"

# Host-Schlüssel generieren
if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Generiere neues SSH-Schlüsselpaar unter ${SSH_KEY_PATH} (als ${PULL_USER})..."
    
    # Der gesamte Block muss als PULL_USER ausgeführt werden
    ssh-keygen -t ed25519 -N "" -f "${SSH_KEY_PATH}"
    # chown -R "${PULL_USER}":"${PULL_USER}" "${SSH_DIR}"
    chown -R "${PULL_USER}":root "${SSH_DIR}"
fi

if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Fehler: Öffentlicher Schlüssel (${PUB_KEY_PATH}) konnte nicht erstellt werden." >&2
    exit 1
fi

PUB_KEY=$(cat "${PUB_KEY_PATH}")
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS} -o PreferredAuthentications=publickey,password"

printf "${FORMAT}" "Übertrage öffentlichen Schlüssel zu ${PULL_USER}@${CLIENT_HOST}..."
sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "grep -qxF '${PUB_KEY}' ~/.ssh/authorized_keys || echo '${PUB_KEY}' >> ~/.ssh/authorized_keys"

printf "${FORMAT}" "Teste SSH-Anmeldung via Schlüssel..."
ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "echo 'Schlüsselanmeldung erfolgreich.'"

printf "${FORMAT}" "Passwort-Login für ${PULL_USER} deaktivieren..."
ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "sudo passwd -l ${PULL_USER}"

printf "${FORMAT}" "Passwort-Login deaktiviert. Zugriff nur noch per Schlüssel möglich."