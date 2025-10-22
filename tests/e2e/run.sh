#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml"
TMP_DIR="${ROOT_DIR}/tests/tmp"
CLIENT_HOME="${TMP_DIR}/client_home"
ENCRYPTED_STAGE="${TMP_DIR}/encrypted_stage"
SERVER_REPO="${TMP_DIR}/server_repo"
FIXTURE_REPO="${ROOT_DIR}/tests/fixtures/restic_repo"

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker wird benötigt, ist aber nicht verfügbar." >&2
    exit 1
fi

PROJECT_NAME=${PROJECT_NAME:-poc_backup_e2e}
export PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-e2e-test-password}

cleanup() {
    docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" down -v >/dev/null 2>&1 || true
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "=> Vorbereitung des Test-Workspaces..."
rm -rf "${TMP_DIR}"
mkdir -p "${CLIENT_HOME}" "${ENCRYPTED_STAGE}" "${SERVER_REPO}"
cp -R "${FIXTURE_REPO}/." "${ENCRYPTED_STAGE}/"

export CLIENT_USER_HOME_VOLUME="${CLIENT_HOME}"
export CLIENT_ENCRYPTED_VOLUME="${ENCRYPTED_STAGE}"
export SERVER_REPO_VOLUME="${SERVER_REPO}"

echo "=> Baue und starte Test-Stack..."
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" up -d --build

echo "=> Prüfe, ob der Client-SSHD läuft..."
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T client bash -c "until pgrep -f 'sshd' >/dev/null; do sleep 1; done"

echo "=> Führe Schlüsseltausch durch..."
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server /usr/local/bin/push_ssh_key.sh

echo "=> Synchronisiere Restic-Repository..."
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server /usr/local/bin/pull_restic_repo.sh

echo "=> Prüfe synchronisierte Dateien..."
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server test -f /data/restic_repo/config
docker-compose -p "${PROJECT_NAME}" -f "${COMPOSE_FILE}" exec -T server test -f /data/restic_repo/test.txt

echo "=> End-to-End-Test erfolgreich abgeschlossen."
