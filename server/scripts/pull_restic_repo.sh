#!/bin/sh

set -eu

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}
PULL_USER="backup_puller"
REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-/data/encrypted_stage}
LOCAL_REPO_PATH=${LOCAL_REPO_PATH:-/data/restic_repo}
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_ed25519}
KNOWN_HOSTS=${KNOWN_HOSTS:-~/.ssh/known_hosts}

SSH_BASE_OPTS="-p ${CLIENT_PORT} -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o UserKnownHostsFile=${KNOWN_HOSTS}"

echo -e "\n=> Synchronisiere Restic-Repository von ${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH} nach ${LOCAL_REPO_PATH} ..."

rsync -az --ignore-existing -e "ssh ${SSH_BASE_OPTS}" \
    "${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH}/" \
    "${LOCAL_REPO_PATH}/"

echo -e "\n=> Setze Append-Only Attribut auf ${LOCAL_REPO_PATH} ..."
chattr -R +a "${LOCAL_REPO_PATH}"

echo -e "\n=> Synchronisierung abgeschlossen."
