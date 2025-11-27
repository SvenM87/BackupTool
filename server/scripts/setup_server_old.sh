#!/bin/sh
# /home/user/backup-poc/server/scripts/setup_server.sh

set -e

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}
PULL_USER=${PULL_USER:-backup_puller}
PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-"puller-temp-password"}
REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-/data/encrypted_stage}
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
chown -R "${PULL_USER}":"${PULL_USER}" "${SSH_DIR}"

# Host-Schlüssel generieren
if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Generiere neues SSH-Schlüsselpaar unter ${SSH_KEY_PATH} (als ${PULL_USER})..."
    
    # Der gesamte Block muss als PULL_USER ausgeführt werden
    runuser -u "${PULL_USER}" -- ssh-keygen -t ed25519 -N "" -f "${SSH_KEY_PATH}"
    chown -R "${PULL_USER}":"${PULL_USER}" "${SSH_DIR}"
    # chown -R "${PULL_USER}":root "${SSH_DIR}"
fi

if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Fehler: Öffentlicher Schlüssel (${PUB_KEY_PATH}) konnte nicht erstellt werden." >&2
    exit 1
fi

printf "${FORMAT}" "Schlüssel übertragen und testen..."

# .ssh auf dem Client vorbereiten
sshpass -p "${PULL_USER_PASSWORD}" ssh -p "${CLIENT_PORT}" \
    "${PULL_USER}@${CLIENT_HOST}" \
    'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys'

# autorisierte Zeile mit command="..." + Optionen anhängen
PUBKEY_LINE=$(cat "${PUB_KEY_PATH}")
REMOTE_ALLOWED_CMD="/usr/local/bin/rrsync -ro ${REMOTE_REPO_PATH}"

sshpass -p "${PULL_USER_PASSWORD}" ssh -p "${CLIENT_PORT}" \
    "${PULL_USER}@${CLIENT_HOST}" \
    "umask 077; printf '%s\n' \
    'command=\"${REMOTE_ALLOWED_CMD}\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ${PUBKEY_LINE}' \
    >> ~/.ssh/authorized_keys"



	
# PUB_KEY=$(cat "${PUB_KEY_PATH}")
# SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS} -o PreferredAuthentications=publickey,password"
# PASS_ONLY_SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS} -o PreferredAuthentications=password -o PubkeyAuthentication=no"
# RSYNC_FORCE_CMD="rsync --server --sender -logDtpre.iLsfxC --ignore-existing . ${REMOTE_REPO_PATH}/"

# read -r -d '' KEY_OPTS <<'EOF' || true
# command="sh -c 'case "$SSH_ORIGINAL_COMMAND" in rsync --server --sender *) exec "$SSH_ORIGINAL_COMMAND" ;; *) echo Command not allowed >&2; exit 1 ;; esac'"
# EOF
# KEY_OPTS="${KEY_OPTS},restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty"
# KEY_LINE_B64=$(printf "%s %s" "${KEY_OPTS}" "${PUB_KEY}" | base64 -w0)

# printf "${FORMAT}" "Übertrage öffentlichen Schlüssel zu ${PULL_USER}@${CLIENT_HOST}..."
# # runuser -u "${PULL_USER}" -- sshpass -p "${PULL_USER_PASSWORD}" ssh-copy-id -i "${PUB_KEY_PATH}" -p "${CLIENT_PORT}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS} -o PreferredAuthentications=password -o PubkeyAuthentication=no "${PULL_USER}@${CLIENT_HOST}"
# runuser -u "${PULL_USER}" "sshpass ssh-copy-id -i ${PUB_KEY_PATH} ${PULL_USER}@${CLIENT_HOST}"

# printf "${FORMAT}" "Teste Anmeldung mit Key und setze authorized_keys Restriktionen (rsync-only)..."
# # RSYNC_CMD="rsync -az --ignore-existing -e \"ssh\" \"${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH}/\" \"${LOCAL_REPO_PATH}/\""
# # runuser -u "${PULL_USER}" ${RSYNC_CMD}
# sshpass -p "${PULL_USER_PASSWORD}" ssh ${PASS_ONLY_SSH_OPTS} -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "\
#     set -e; \
#     AUTH=~/.ssh/authorized_keys; \
#     mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch \"\${AUTH}\" && chmod 600 \"\${AUTH}\"; \
#     TMP=\$(mktemp); \
#     grep -Fv '${PUB_KEY}' \"\${AUTH}\" > \"\${TMP}\" || true; \
#     printf '%s\n' \"\$(echo '${KEY_LINE_B64}' | base64 -d)\" >> \"\${TMP}\"; \
#     mv \"\${TMP}\" \"\${AUTH}\""

# # printf "${FORMAT}" "Teste SSH-Anmeldung via Schlüssel (rsync handshake)..."
# # chown -R "${PULL_USER}":"${PULL_USER}" "${LOCAL_REPO_PATH}"
# # runuser -u "${PULL_USER}" -- rsync -az --ignore-existing -e "ssh -p ${CLIENT_PORT} -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS}" \
# #     "${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH}/" \
# #     "${LOCAL_REPO_PATH}/" > /dev/null

# printf "${FORMAT}" "Passwort-Login für ${PULL_USER} deaktivieren..."
# sshpass -p "${PULL_USER_PASSWORD}" ssh ${PASS_ONLY_SSH_OPTS} -p "${CLIENT_PORT}" "${PULL_USER}@${CLIENT_HOST}" "sudo passwd -l ${PULL_USER}"

# printf "${FORMAT}" "Passwort-Login deaktiviert. Zugriff nur noch per Schlüssel möglich."
