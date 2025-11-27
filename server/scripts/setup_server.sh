#!/bin/sh
# /home/user/backup-poc/server/scripts/setup_server.sh

set -e

# Konfiguration

CLIENT_HOST=${CLIENT_HOST:-client}
CLIENT_PORT=${CLIENT_PORT:-22}

# lokaler Pull-User (auf dem Backup-Server)
PULL_USER=${PULL_USER:-backup_puller}

# Remote-User mit initialem Passwort (auf dem Client)
PULL_USER_PASSWORD=${PULL_USER_PASSWORD:-"puller-temp-password"}

REMOTE_REPO_PATH=${REMOTE_REPO_PATH:-/data/encrypted_stage}
LOCAL_REPO_PATH=${LOCAL_REPO_PATH:-/data/restic_repo}

SSH_DIR="/home/${PULL_USER}/.ssh"
SSH_KEY_PATH="${SSH_DIR}/id_ed25519"
PUB_KEY_PATH="${SSH_DIR}/id_ed25519.pub"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

FORMAT="\n\033[1;94m=> %s\033[0m\n"

# Basis-SSH-Optionen (Host-Key wird in eigenes known_hosts geschrieben)
SSH_BASE_OPTS="-p ${CLIENT_PORT} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KNOWN_HOSTS}"


# Pakete installieren

printf "${FORMAT}" "Installiere benötigte Pakete (openssh-client, sshpass, rsync)..."
apt-get update > /dev/null
apt-get install -y openssh-client sshpass rsync > /dev/null


# Lokalen Pull-User anlegen

if ! id -u "${PULL_USER}" > /dev/null 2>&1; then
    printf "${FORMAT}" "Erstelle lokalen PULL_USER '${PULL_USER}'..."
    # Systemnutzer, keine interaktive Shell
    useradd --system --create-home --shell /usr/sbin/nologin "${PULL_USER}"
fi

printf "${FORMAT}" "Lege Verzeichnisse an und setze Berechtigungen..."
mkdir -p "${LOCAL_REPO_PATH}" "${SSH_DIR}"
chown "${PULL_USER}":"${PULL_USER}" "${LOCAL_REPO_PATH}"
chmod 750 "${LOCAL_REPO_PATH}"

chmod 700 "${SSH_DIR}"
chown -R "${PULL_USER}":"${PULL_USER}" "${SSH_DIR}"

touch "${KNOWN_HOSTS}"
chmod 600 "${KNOWN_HOSTS}"
chown "${PULL_USER}":"${PULL_USER}" "${KNOWN_HOSTS}"


# SSH-Key für PULL_USER erzeugen

if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Generiere neues SSH-Schlüsselpaar unter ${SSH_KEY_PATH} (als ${PULL_USER})..."
    runuser -u "${PULL_USER}" -- ssh-keygen -t ed25519 -N "" -f "${SSH_KEY_PATH}"
fi

if [ ! -s "${PUB_KEY_PATH}" ]; then
    printf "${FORMAT}" "Fehler: Öffentlicher Schlüssel (${PUB_KEY_PATH}) konnte nicht erstellt werden." >&2
    exit 1
fi


# 1Key  auf den Client übertragen

printf "${FORMAT}" "Schlüssel auf Client übertragen (per Passwort-Login)..."

# .ssh auf dem Client vorbereiten (noch mit Passwort)
sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_BASE_OPTS} \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    "${PULL_USER}@${CLIENT_HOST}" \
    'umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'

# Public Key, falls noch nicht vorhanden, anhängen
PUBKEY_LINE="$(cat "${PUB_KEY_PATH}")"

sshpass -p "${PULL_USER_PASSWORD}" ssh ${SSH_BASE_OPTS} \
    -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    "${PULL_USER}@${CLIENT_HOST}" \
    "grep -q \"${PUBKEY_LINE}\" ~/.ssh/authorized_keys || printf '%s\n' '${PUBKEY_LINE}' >> ~/.ssh/authorized_keys"


# SSH-Anmeldung via Key testen

printf "${FORMAT}" "SSH-Anmeldung mit Schlüssel (ohne Passwort) testen..."

runuser -u "${PULL_USER}" -- ssh ${SSH_BASE_OPTS} \
    -i "${SSH_KEY_PATH}" \
    "${PULL_USER}@${CLIENT_HOST}" \
    'echo "Key-Login OK"' || {
        printf "${FORMAT}" "Fehler: SSH-Login mit Schlüssel funktioniert nicht. Abbruch."
        exit 1
    }


# Passwort-Login für den User praktisch unbrauchbar machen
# (User ist remote kein sudoer, kann aber eigenes Passwort ändern)

printf "${FORMAT}" "Passwort-Login für ${PULL_USER} unbrauchbar machen (Passwort auf Zufallswert drehen)..."

runuser -u "${PULL_USER}" -- ssh ${SSH_BASE_OPTS} \
    -i "${SSH_KEY_PATH}" \
    "${PULL_USER}@${CLIENT_HOST}" \
    "NEWPW=\$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64);
     # altes + neues Passwort an passwd durchreichen
     if printf '%s\n%s\n%s\n' '${PULL_USER_PASSWORD}' \"\$NEWPW\" \"\$NEWPW\" | passwd >/dev/null 2>&1; then
         echo 'Passwort geändert – bekanntes Initialpasswort ist jetzt ungültig.';
     else
         echo 'WARNUNG: Passwort konnte nicht automatisch geändert werden. Prüfe passwd-/PAM-Policy.';
     fi
     unset NEWPW"
     

# authorized_keys auf rrsync read-only einschränken

printf "${FORMAT}" "Restriktionen für Schlüssel setzen (rrsync read-only)..."

REMOTE_ALLOWED_CMD="rrsync -ro ${REMOTE_REPO_PATH}"

# Nur der Payload-Teil des öffentlichen Schlüssels (ab Feld 2)
PUBKEY_PAYLOAD="$(cut -d' ' -f2- "${PUB_KEY_PATH}")"

runuser -u "${PULL_USER}" -- ssh ${SSH_BASE_OPTS} \
    -i "${SSH_KEY_PATH}" \
    "${PULL_USER}@${CLIENT_HOST}" \
    "AUTH=\$HOME/.ssh/authorized_keys; TMP=\$(mktemp);
     # alle bisherigen Zeilen mit diesem Key entfernen
     grep -Fv '${PUBKEY_PAYLOAD}' \"\${AUTH}\" >\"\${TMP}\" || true;
     # neue eingeschränkte Zeile anhängen
     printf '%s\n' 'command=\"${REMOTE_ALLOWED_CMD}\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty ssh-ed25519 ${PUBKEY_PAYLOAD}' >>\"\${TMP}\";
     mv \"\${TMP}\" \"\${AUTH}\"; chmod 600 \"\${AUTH}\""


# rrsync/rsync-Handshake prüfen (optional)

printf "${FORMAT}" "Test: rsync-Pull mit Key und rrsync-Restriktion..."

runuser -u "${PULL_USER}" -- rsync -az --ignore-existing \
    -e "ssh ${SSH_BASE_OPTS} -i ${SSH_KEY_PATH}" \
    "${PULL_USER}@${CLIENT_HOST}://" \
    "${LOCAL_REPO_PATH}/" || {
        # printf "${FORMAT}" "WARNUNG: rsync-Test fehlgeschlagen. Prüfe rrsync-Setup und Pfade."
        exit 1
    }