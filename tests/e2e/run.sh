#!/bin/bash

set -euo pipefail

PULL_USER="backup_puller"
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
TMP_DIR="${ROOT_DIR}/tests/tmp"
CLIENT_HOME="${TMP_DIR}/client_home"
CLIENT_TESTDATA="${CLIENT_HOME}/testdata"
ENCRYPTED_STAGE="${TMP_DIR}/encrypted_stage"
SERVER_REPO="${TMP_DIR}/server_repo"
RESTIC_PASSWORD_VALUE=${RESTIC_PASSWORD_VALUE:-e2e-restic-password}
SECRET_MARKER="E2E_SECRET_TEST_PAYLOAD"
PROJECT_NAME=${PROJECT_NAME:-poc_backup_e2e}
export PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-e2e-test-password}
FORMAT="\n\e[1;94m-> %s\e[0m\n"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker wird benötigt, ist aber nicht verfügbar." >&2
    exit 1
fi

COMPOSE_COMMAND="docker compose"
if ! docker compose version >/dev/null 2>&1; then
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_COMMAND="docker-compose"
    else
        echo "Weder 'docker compose' noch 'docker-compose' ist verfügbar." >&2
        exit 1
    fi
fi

LOCAL_UID=${LOCAL_UID:-$(id -u)}
LOCAL_GID=${LOCAL_GID:-$(id -g)}
export LOCAL_UID LOCAL_GID

cleanup() {
    printf "${FORMAT}" "Bereinige Test-Workspace..."
    ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" down -v >/dev/null 2>&1 || true
    sudo rm -rf "${TMP_DIR}"
    printf "${FORMAT}" "Bereinigung abgeschlossen."
}
# trap cleanup EXIT

printf "${FORMAT}" "Vorbereitung des Test-Workspaces..."
cleanup
# mkdir -p "${CLIENT_TESTDATA}" "${ENCRYPTED_STAGE}" "${SERVER_REPO}"
# cat > "${CLIENT_TESTDATA}/report.txt" <<EOF
# Vertrauliche Testdaten
# Marker=${SECRET_MARKER}
# EOF
# echo "Weitere Daten ${SECRET_MARKER} $(date -Is)" > "${CLIENT_TESTDATA}/notes.log"

# export CLIENT_USER_HOME_VOLUME="${CLIENT_HOME}"
# export CLIENT_ENCRYPTED_VOLUME="${ENCRYPTED_STAGE}"
# export SERVER_REPO_VOLUME="${SERVER_REPO}"

printf "${FORMAT}" "Baue und starte Test-Stack..."
# ohne Cache bauen
# ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" build --no-cache
# ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" up -d
# standard mit Cache bauen und starten
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" up -d --build


printf "${FORMAT}" "Führe Client-Setup durch..."
# Setup ausführen und Ausgabe erfassen
CLIENT_SETUP_OUTPUT=$(${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u user client bash -c "echo 123456 | sudo -S ~/setup_client.sh")

# Das Passwort aus der Ausgabe extrahieren (mit den Markern <: und :>)
PULL_USER_PASSWORD_EXTRACTED=$(echo "${CLIENT_SETUP_OUTPUT}" | grep "<:" | awk -F':' '{print $2}')
export PULL_USER_PASSWORD="${PULL_USER_PASSWORD_EXTRACTED}" # Überschreibe die globale Export-Variable

echo "${CLIENT_SETUP_OUTPUT}" # Zeige die restliche Setup-Ausgabe an den Benutzer

printf "${FORMAT}" "Starte SSHD..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -d client /usr/sbin/sshd -D

printf "${FORMAT}" "Prüfe, ob der Client-SSHD läuft..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "until pgrep -f 'sshd' >/dev/null; do sleep 1; done"


printf "${FORMAT}" "Führe Server-Setup durch..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u root -e "PULL_USER_PASSWORD=${PULL_USER_PASSWORD}" server /usr/local/bin/setup_server.sh

# printf "${FORMAT}" "Prüfe authorized_keys-Restriktion (rsync-only)..."
# ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "grep -F 'rsync --server --sender' /home/${PULL_USER}/.ssh/authorized_keys | grep -F 'restrict,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty'"

printf "${FORMAT}" "Verifiziere, dass andere Kommandos scheitern..."
if ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u "${PULL_USER}" server sh -c "timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=~/.ssh/known_hosts -i ~/.ssh/id_ed25519 -p 22 ${PULL_USER}@client 'echo should-fail'"; then
    echo "Unerwarteter Erfolg: SSH-Command ohne rsync wurde akzeptiert." >&2
    exit 1
fi


printf "${FORMAT}" "Setze ACL-Berechtigungen (ACLs) zur Laufzeit..."
# 'backup_encoder' erlauben, /home/user zu betreten UND /home/user/testdata zu lesen. 
# redundant, da in setup_client.sh schon gesetzt, aber muss zur Laufzeit ausgeführt werden,
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T --user root client bash -c " \
    setfacl -R -m u:backup_encoder:rX /home/user && \
    setfacl -R -m d:u:backup_encoder:rX /home/user && \
    setfacl -R -m u:backup_puller:rX /data/encrypted_stage && \
    setfacl -R -m d:u:backup_puller:rX /data/encrypted_stage"

printf "${FORMAT}" "Initialisiere Restic-Repository und erstelle Backup..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u backup_encoder client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; if [ ! -f /data/encrypted_stage/config ]; then restic -r /data/encrypted_stage init --no-cache; fi"
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u backup_encoder client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; restic -r /data/encrypted_stage backup /home/user/testdata --no-cache"
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u backup_encoder client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; restic -r /data/encrypted_stage snapshots --no-cache"

printf "${FORMAT}" "Korrigiere ACL-Maske für rsync..."
# restric setzt überschreibt die ACL-Maske, daher hier korrigieren
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u backup_encoder client setfacl -R -m u:backup_puller:rX /data/encrypted_stage

printf "${FORMAT}" "Synchronisiere Restic-Repository..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T -u "${PULL_USER}" server /usr/local/bin/pull_restic_repo.sh

printf "${FORMAT}" "Prüfe synchronisierte Dateien..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server test -f /data/restic_repo/config
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server sh -c "ls -A /data/restic_repo/snapshots | grep -q ."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server sh -c "! grep -R '${SECRET_MARKER}' /data/restic_repo"

printf "${FORMAT}" "End-to-End-Test erfolgreich abgeschlossen."
