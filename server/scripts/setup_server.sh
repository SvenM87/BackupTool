#!/bin/sh

set -e

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}
PULL_USER=${PULL_USER:-backup_puller}
PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-"puller-temp-password"}
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}
PUB_KEY_PATH=${PUB_KEY_PATH:-~/.ssh/id_rsa.pub}
KNOWN_HOSTS=${KNOWN_HOSTS:-~/.ssh/known_hosts}

if [ ! -s "${PUB_KEY_PATH}" ]; then
    echo "=> Generiere neues SSH-Schlüsselpaar unter ${SSH_KEY_PATH} ..."
    mkdir -p "$(dirname "${SSH_KEY_PATH}")"
    ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_KEY_PATH}"
fi

if [ ! -s "${PUB_KEY_PATH}" ]; then
    echo "Fehler: Öffentlicher Schlüssel (${PUB_KEY_PATH}) konnte nicht erstellt werden." >&2
    exit 1
fi

PUB_KEY=$(cat "${PUB_KEY_PATH}")
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS} -o PreferredAuthentications=publickey,password"

echo "=> Übertrage öffentlichen Schlüssel zu ${PULL_USER}@${CLIENT_HOST}..."
sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "grep -qxF '${PUB_KEY}' ~/.ssh/authorized_keys || echo '${PUB_KEY}' >> ~/.ssh/authorized_keys"

echo "=> Teste SSH-Anmeldung via Schlüssel..."
ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "echo 'Schlüsselanmeldung erfolgreich.'"

echo "=> Passwort-Login für ${PULL_USER} deaktivieren..."
ssh ${SSH_OPTS} -i "${SSH_KEY_PATH}" -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "sudo passwd -l ${PULL_USER}"

echo "=> Passwort-Login deaktiviert. Zugriff nur noch per Schlüssel möglich."
