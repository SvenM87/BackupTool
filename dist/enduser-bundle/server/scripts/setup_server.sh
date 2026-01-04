#!/bin/sh
# /home/user/backup-poc/server/scripts/setup_server.sh

set -e

FORMAT="\n\033[1;94m=> %s\033[0m\n"
PROMPT_ENABLED=1
[ -t 0 ] || PROMPT_ENABLED=0

prompt_with_default() {
    # $1 var name, $2 prompt, $3 default
    __var="$1"
    __prompt="$2"
    __default="$3"
    __input=""
    if [ "${PROMPT_ENABLED}" -eq 1 ]; then
        read -r -p "${__prompt} [${__default}]: " __input
        __input=${__input:-${__default}}
    else
        __input=${__default}
    fi
    eval "${__var}=\"${__input}\""
}

prompt_secret() {
    # $1 var name, $2 prompt, $3 default/fallback (may be empty)
    __var="$1"
    __prompt="$2"
    __default="$3"
    __input=""
    if [ "${PROMPT_ENABLED}" -eq 1 ]; then
        read -r -s -p "${__prompt}: " __input
        echo
    else
        __input="${__default}"
    fi

    if [ -z "${__input}" ] && [ -n "${__default}" ]; then
        __input="${__default}"
    fi

    if [ -z "${__input}" ]; then
        echo "Eingabe für ${__var} fehlt und kein Default vorhanden." >&2
        exit 1
    fi

    eval "${__var}=\"${__input}\""
}

prompt_optional_secret() {
    # $1 var name, $2 prompt, $3 default/fallback (may be empty)
    __var="$1"
    __prompt="$2"
    __default="$3"
    __input=""
    if [ "${PROMPT_ENABLED}" -eq 1 ]; then
        read -r -s -p "${__prompt} (leer = überspringen): " __input
        echo
    else
        __input="${__default}"
    fi
    [ -z "${__input}" ] && __input="${__default}"
    eval "${__var}=\"${__input}\""
}

CLIENT_HOST_DEFAULT=${CLIENT_HOST:-client}
CLIENT_PORT_DEFAULT=${CLIENT_PORT:-22}
PULL_USER_DEFAULT=${PULL_USER:-backup_puller}
REMOTE_REPO_PATH_DEFAULT=${REMOTE_REPO_PATH:-/data/encrypted_stage}
LOCAL_REPO_PATH_DEFAULT=${LOCAL_REPO_PATH:-/data/restic_repo}
PULL_USER_PASSWORD_DEFAULT=${PULL_USER_PASSWORD:-}

BACKUP_REPORT_TO_DEFAULT=${BACKUP_REPORT_TO:-}
BACKUP_REPORT_FROM_DEFAULT=${BACKUP_REPORT_FROM:-"backup-report@$(hostname)"}
BACKUP_REPORT_SUBJECT_DEFAULT=${BACKUP_REPORT_SUBJECT:-"Backup-Status $(hostname)"}
SMTP_HOST_DEFAULT=${SMTP_HOST:-}
SMTP_PORT_DEFAULT=${SMTP_PORT:-587}
SMTP_USER_DEFAULT=${SMTP_USER:-}
SMTP_PASSWORD_DEFAULT=${SMTP_PASSWORD:-}
SMTP_STARTTLS_DEFAULT=${SMTP_STARTTLS:-on}
SMTP_TLS_DEFAULT=${SMTP_TLS:-on}

if [ "${PROMPT_ENABLED}" -eq 1 ]; then
    printf "${FORMAT}" "Interaktives Setup: Werte können mit Enter bestätigt werden."
fi

prompt_with_default CLIENT_HOST "Client-Hostname oder IP" "${CLIENT_HOST_DEFAULT}"
prompt_with_default CLIENT_PORT "SSH-Port auf dem Client" "${CLIENT_PORT_DEFAULT}"
prompt_with_default PULL_USER "Pull-Nutzer (Client & Server)" "${PULL_USER_DEFAULT}"
prompt_with_default REMOTE_REPO_PATH "Pfad zum Restic-Repo auf dem Client" "${REMOTE_REPO_PATH_DEFAULT}"
prompt_with_default LOCAL_REPO_PATH "Zielpfad auf dem Server" "${LOCAL_REPO_PATH_DEFAULT}"

if [ -n "${PULL_USER_PASSWORD_DEFAULT}" ]; then
    PULL_USER_PASSWORD="${PULL_USER_PASSWORD_DEFAULT}"
elif [ "${PROMPT_ENABLED}" -eq 1 ]; then
    prompt_secret PULL_USER_PASSWORD "Temporäres Passwort des Pull-Nutzers auf dem Client (vom Client-Setup notiert)" ""
else
    echo "PULL_USER_PASSWORD muss via Umgebung gesetzt werden oder interaktiv eingegeben werden." >&2
    exit 1
fi

SSH_DIR="/home/${PULL_USER}/.ssh"
SSH_KEY_PATH="${SSH_DIR}/id_ed25519"
PUB_KEY_PATH="${SSH_DIR}/id_ed25519.pub"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

ENV_FILE=${ENV_FILE:-/etc/backup_report.env}
MSMTP_RC=${MSMTP_RC:-/etc/msmtprc}

# Basis-SSH-Optionen (Host-Key wird in eigenes known_hosts geschrieben)
SSH_BASE_OPTS="-p ${CLIENT_PORT} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KNOWN_HOSTS}"


# Pakete installieren

printf "${FORMAT}" "Installiere benötigte Pakete (openssh-client, sshpass, rsync, msmtp)..."
apt-get update > /dev/null
apt-get install -y openssh-client sshpass rsync msmtp > /dev/null


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


# Schlüssel auf den Client übertragen

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


# Backup-Report konfigurieren (SMTP und /etc/backup_report.env)

escape_for_single_quotes() {
    printf "%s" "$1" | sed "s/'/'\"'\"'/g"
}

prompt_with_default BACKUP_REPORT_TO "Backup-Report Empfänger (leer = kein Mailversand)" "${BACKUP_REPORT_TO_DEFAULT}"
prompt_with_default BACKUP_REPORT_FROM "Backup-Report Absender" "${BACKUP_REPORT_FROM_DEFAULT}"
prompt_with_default BACKUP_REPORT_SUBJECT "Betreff der Report-Mail" "${BACKUP_REPORT_SUBJECT_DEFAULT}"
prompt_with_default SMTP_HOST "SMTP-Host (leer = Mailversand aus)" "${SMTP_HOST_DEFAULT}"

if [ -n "${SMTP_HOST}" ]; then
    prompt_with_default SMTP_PORT "SMTP-Port" "${SMTP_PORT_DEFAULT}"
    prompt_with_default SMTP_USER "SMTP-User (leer = anonyme Zustellung)" "${SMTP_USER_DEFAULT}"
    if [ -n "${SMTP_USER}" ] || [ -n "${SMTP_PASSWORD_DEFAULT}" ]; then
        prompt_optional_secret SMTP_PASSWORD "SMTP-Passwort" "${SMTP_PASSWORD_DEFAULT}"
    else
        SMTP_PASSWORD=""
    fi
    prompt_with_default SMTP_STARTTLS "STARTTLS (on/off)" "${SMTP_STARTTLS_DEFAULT}"
    prompt_with_default SMTP_TLS "TLS (on/off)" "${SMTP_TLS_DEFAULT}"
else
    SMTP_PORT="${SMTP_PORT_DEFAULT}"
    SMTP_USER="${SMTP_USER_DEFAULT}"
    SMTP_PASSWORD="${SMTP_PASSWORD_DEFAULT}"
    SMTP_STARTTLS="${SMTP_STARTTLS_DEFAULT}"
    SMTP_TLS="${SMTP_TLS_DEFAULT}"
fi

printf "${FORMAT}" "Schreibe ${ENV_FILE}..."
if {
    printf "LOCAL_REPO_PATH='%s'\n" "$(escape_for_single_quotes "${LOCAL_REPO_PATH}")"
    printf "BACKUP_REPORT_TO='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_TO}")"
    printf "BACKUP_REPORT_FROM='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_FROM}")"
    printf "BACKUP_REPORT_SUBJECT='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_SUBJECT}")"
    printf "SMTP_HOST='%s'\n" "$(escape_for_single_quotes "${SMTP_HOST}")"
    printf "SMTP_PORT='%s'\n" "$(escape_for_single_quotes "${SMTP_PORT}")"
    printf "SMTP_USER='%s'\n" "$(escape_for_single_quotes "${SMTP_USER}")"
    printf "SMTP_PASSWORD='%s'\n" "$(escape_for_single_quotes "${SMTP_PASSWORD}")"
    printf "SMTP_STARTTLS='%s'\n" "$(escape_for_single_quotes "${SMTP_STARTTLS}")"
    printf "SMTP_TLS='%s'\n" "$(escape_for_single_quotes "${SMTP_TLS}")"
} > "${ENV_FILE}"; then
    chmod 600 "${ENV_FILE}"
else
    printf "${FORMAT}" "WARNUNG: Konnte ${ENV_FILE} nicht schreiben (ggf. read-only). Bitte manuell anlegen:\n$(escape_for_single_quotes "${ENV_FILE}")"
fi

if [ -n "${SMTP_HOST}" ]; then
    printf "${FORMAT}" "Schreibe ${MSMTP_RC}..."

    AUTH_LINE="auth off"
    if [ -n "${SMTP_USER}" ] || [ -n "${SMTP_PASSWORD}" ]; then
        AUTH_LINE="auth on"
    fi

    if {
        echo "defaults"
        echo "${AUTH_LINE}"
        echo "tls ${SMTP_TLS}"
        echo "tls_starttls ${SMTP_STARTTLS}"
        echo "tls_trust_file /etc/ssl/certs/ca-certificates.crt"
        echo "logfile /var/log/msmtp.log"
        echo
        echo "account default"
        echo "host ${SMTP_HOST}"
        echo "port ${SMTP_PORT}"
        echo "from ${BACKUP_REPORT_FROM}"
        [ -n "${SMTP_USER}" ] && echo "user ${SMTP_USER}"
        [ -n "${SMTP_PASSWORD}" ] && echo "password ${SMTP_PASSWORD}"
    } > "${MSMTP_RC}"; then
        chmod 600 "${MSMTP_RC}"
    else
        printf "${FORMAT}" "WARNUNG: Konnte ${MSMTP_RC} nicht schreiben (ggf. read-only). Bitte manuell anlegen."
    fi
else
    printf "${FORMAT}" "Kein SMTP-Host angegeben – Mailversand deaktiviert."
fi

printf "${FORMAT}" "Server-Setup abgeschlossen. Pull-User: ${PULL_USER}. Lokales Repo: ${LOCAL_REPO_PATH}"
