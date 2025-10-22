#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_BASE="${ROOT_DIR}/docker-compose.yml"
COMPOSE_TEST="${ROOT_DIR}/docker-compose.test.yml"
TMP_DIR="${ROOT_DIR}/tests/tmp"
ENCRYPTED_STAGE="${TMP_DIR}/encrypted_stage"
CLIENT_AUTH_KEYS="${TMP_DIR}/client_authorized_keys"
SERVER_SSH="${TMP_DIR}/server_ssh"
SERVER_REPO="${TMP_DIR}/server_repo"
FIXTURE_REPO="${ROOT_DIR}/tests/fixtures/restic_repo"

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

PROJECT_NAME=${PROJECT_NAME:-poc_backup_e2e}
export PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-e2e-test-password}

cleanup() {
    ${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" down -v >/dev/null 2>&1 || true
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "=> Vorbereitung des Test-Workspaces..."
rm -rf "${TMP_DIR}"
mkdir -p "${ENCRYPTED_STAGE}" "${SERVER_SSH}" "${SERVER_REPO}"
cp -R "${FIXTURE_REPO}/." "${ENCRYPTED_STAGE}/"
touch "${CLIENT_AUTH_KEYS}"
chmod 600 "${CLIENT_AUTH_KEYS}"
touch "${SERVER_SSH}/known_hosts"
chmod 600 "${SERVER_SSH}/known_hosts"

echo "=> Baue und starte Test-Stack..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" up -d --build

echo "=> Prüfe, ob der Client-SSHD läuft..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" exec -T client bash -c "until pgrep -f 'sshd' >/dev/null; do sleep 1; done"

echo "=> Führe Schlüsseltausch durch..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" exec -T server /usr/local/bin/push_ssh_key.sh

echo "=> Synchronisiere Restic-Repository..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" exec -T server /usr/local/bin/pull_restic_repo.sh

echo "=> Prüfe synchronisierte Dateien..."
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" exec -T server test -f /data/restic_repo/config
${COMPOSE_COMMAND} -p "${PROJECT_NAME}" -f "${COMPOSE_BASE}" -f "${COMPOSE_TEST}" exec -T server test -f /data/restic_repo/test.txt

echo "=> End-to-End-Test erfolgreich abgeschlossen."
