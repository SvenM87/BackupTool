#!/bin/sh
# Wöchentlicher Statusbericht für das Backup-Repository

set -eu

ENV_FILE="/etc/backup_report.env"
[ -f "${ENV_FILE}" ] && . "${ENV_FILE}"

LOCAL_REPO_PATH=${LOCAL_REPO_PATH:-/data/restic_repo}
REPORT_TO=${BACKUP_REPORT_TO:-}
REPORT_FROM=${BACKUP_REPORT_FROM:-"backup-report@$(hostname)"}
SUBJECT=${BACKUP_REPORT_SUBJECT:-"Backup-Status $(hostname)"}

log() {
    printf "%s | %s\n" "$(date -Is)" "$*"
}

# Kennzahlen ermitteln
repo_exists="nein"
config_exists="nein"
snapshot_count=0
repo_size="n/a"
latest_change="unbekannt"
disk_usage="n/a"

if [ -d "${LOCAL_REPO_PATH}" ]; then
    repo_exists="ja"
    [ -f "${LOCAL_REPO_PATH}/config" ] && config_exists="ja"
    if [ -d "${LOCAL_REPO_PATH}/snapshots" ]; then
        snapshot_count=$(find "${LOCAL_REPO_PATH}/snapshots" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    repo_size=$(du -sh "${LOCAL_REPO_PATH}" 2>/dev/null | awk '{print $1}')
    last_ts=$(find "${LOCAL_REPO_PATH}" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1 || true)
    if [ -n "${last_ts:-}" ]; then
        last_seconds=${last_ts%.*}
        latest_change=$(date -d "@${last_seconds}" -Is)
    fi
    disk_usage=$(df -h "${LOCAL_REPO_PATH}" 2>/dev/null | awk 'NR==2 {print $4 "/" $2 " frei (" $5 " belegt)"}')
fi

status="OK"
warn_reasons=""

if [ "${repo_exists}" != "ja" ]; then
    status="WARN"
    warn_reasons="${warn_reasons}Repository nicht gefunden. "
fi

if [ "${config_exists}" != "ja" ]; then
    status="WARN"
    warn_reasons="${warn_reasons}Restic-config fehlt. "
fi

if [ "${snapshot_count}" -eq 0 ]; then
    status="WARN"
    warn_reasons="${warn_reasons}Keine Snapshot-Dateien vorhanden. "
fi

[ -z "${disk_usage}" ] && disk_usage="n/a"

report_body=$(cat <<EOF
${SUBJECT}
Status: ${status}
Zeitpunkt: $(date -Is)
Host: $(hostname)

Repository-Pfad: ${LOCAL_REPO_PATH}
Repository vorhanden: ${repo_exists}
Restic config vorhanden: ${config_exists}
Snapshot-Dateien: ${snapshot_count}
Letzte Änderung im Repo: ${latest_change}
Geschätzte Größe: ${repo_size}
Freier Speicher (Mount): ${disk_usage}
Hinweise: ${warn_reasons:-keine}
EOF
)

printf "%s\n" "${report_body}"

send_mail() {
    if [ -z "${REPORT_TO}" ]; then
        log "Kein Empfänger gesetzt (BACKUP_REPORT_TO). Mail wird nicht versendet."
        return 1
    fi

    if ! command -v msmtp >/dev/null 2>&1; then
        log "msmtp ist nicht installiert. Mailversand wird übersprungen."
        return 1
    fi

    if [ ! -s /etc/msmtprc ]; then
        log "/etc/msmtprc fehlt oder ist leer. Mailversand wird übersprungen."
        return 1
    fi

    echo "${report_body}" | {
        printf "Subject: %s\n" "${SUBJECT}"
        printf "To: %s\n" "${REPORT_TO}"
        printf "From: %s\n" "${REPORT_FROM}"
        printf "Content-Type: text/plain; charset=UTF-8\n"
        printf "\n"
        cat
    } | msmtp -t
}

if send_mail; then
    log "Backup-Report per Mail versendet an ${REPORT_TO}."
else
    log "Backup-Report konnte nicht versendet werden (oben geloggt)."
fi
