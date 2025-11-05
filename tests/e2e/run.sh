#!/bin/bash

set -euo pipefail

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
    echo "=> Bereinige Test-Workspace..."
    ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" down -v >/dev/null 2>&1 || true
    sudo rm -rf "${TMP_DIR}"
    echo "=> Bereinigung abgeschlossen."
}
trap cleanup EXIT

echo "=> Vorbereitung des Test-Workspaces..."
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

echo "=> Baue und starte Test-Stack..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" up -d --build

echo "=> Prüfe, ob der Client-SSHD läuft..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "until pgrep -f 'sshd' >/dev/null; do sleep 1; done"

echo "=> Initialisiere Restic-Repository und erstelle Backup..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; if [ ! -f /data/encrypted_stage/config ]; then restic -r /data/encrypted_stage init; fi"
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; restic -r /data/encrypted_stage backup /home/user/testdata"
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "export RESTIC_PASSWORD='${RESTIC_PASSWORD_VALUE}'; restic -r /data/encrypted_stage snapshots"

echo "=> Führe Schlüsseltausch durch..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server /usr/local/bin/push_ssh_key.sh

echo "=> Synchronisiere Restic-Repository..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server /usr/local/bin/pull_restic_repo.sh

echo "=> Prüfe synchronisierte Dateien..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server test -f /data/restic_repo/config
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server sh -c "ls -A /data/restic_repo/snapshots | grep -q ."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server sh -c "! grep -R '${SECRET_MARKER}' /data/restic_repo"

echo "=> End-to-End-Test erfolgreich abgeschlossen."
