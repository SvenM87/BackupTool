#!/bin/sh

set -eu

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}
PULL_USER=${PULL_USER:-backup_puller}
REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-/data/encrypted_stage}
LOCAL_REPO_PATH=${LOCAL_REPO_PATH:-/data/restic_repo}
SSH_KEY_PATH=${SSH_KEY_PATH:-/root/.ssh/id_rsa}
KNOWN_HOSTS=${KNOWN_HOSTS:-/root/.ssh/known_hosts}

SSH_BASE_OPTS="-p ${CLIENT_PORT} -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS}"

echo "=> Synchronisiere Restic-Repository von ${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH} nach ${LOCAL_REPO_PATH} ..."
mkdir -p "${LOCAL_REPO_PATH}"

rsync -az --ignore-existing -e "ssh ${SSH_BASE_OPTS}" \
    "${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH}/" \
    "${LOCAL_REPO_PATH}/"

echo "=> Synchronisierung abgeschlossen."
