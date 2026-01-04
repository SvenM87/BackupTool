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
mkdir -p "${LOCAL_REPO_PATH}"

# If running as root, ensure the target dir belongs to the pull user and is accessible
if [ "$(id -u)" -eq 0 ]; then
    chown "${PULL_USER}":"${PULL_USER}" "${LOCAL_REPO_PATH}"
    chmod 750 "${LOCAL_REPO_PATH}"
fi

echo -e "\n=> Synchronisiere Restic-Repository von ${PULL_USER}@${CLIENT_HOST}:${REMOTE_REPO_PATH} nach ${LOCAL_REPO_PATH} ..."

RSYNC_CMD="rsync -az --ignore-existing -e \"ssh ${SSH_BASE_OPTS}\" \"${PULL_USER}@${CLIENT_HOST}:/\" \"${LOCAL_REPO_PATH}/\""

if [ "$(id -u)" -eq 0 ]; then
    # Drop to pull user for rsync so files are created with correct ownership
    su -s /bin/sh -c "${RSYNC_CMD}" "${PULL_USER}"
else
    eval "${RSYNC_CMD}"
fi

# echo -e "\n=> Setze Append-Only Attribut auf ${LOCAL_REPO_PATH} ..."
# chattr -R +a "${LOCAL_REPO_PATH}"

echo -e "\n=> Synchronisierung abgeschlossen."
