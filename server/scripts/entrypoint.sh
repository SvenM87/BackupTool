#!/bin/sh
# Startet Cron und richtet den wöchentlichen Backup-Report ein

set -eu

ENV_FILE="/etc/backup_report.env"
CRON_FILE="/etc/cron.d/backup_report"
LOG_FILE="/var/log/backup_report.log"
USE_EXISTING_ENV_FILE=0

if [ -s "${ENV_FILE}" ]; then
    . "${ENV_FILE}"
    USE_EXISTING_ENV_FILE=1
fi

: "${LOCAL_REPO_PATH:=/data/restic_repo}"
: "${BACKUP_REPORT_SCHEDULE:=0 6 * * 1}"
: "${BACKUP_REPORT_FROM:=backup-report@$(hostname)}"
: "${BACKUP_REPORT_SUBJECT:=Backup-Status $(hostname)}"
: "${SMTP_PORT:=587}"
: "${SMTP_STARTTLS:=on}"
: "${SMTP_TLS:=on}"

escape_for_single_quotes() {
    printf "%s" "$1" | sed "s/'/'\"'\"'/g"
}

write_env_file() {
    if [ "${USE_EXISTING_ENV_FILE}" -eq 1 ]; then
        return
    fi

    {
        printf "LOCAL_REPO_PATH='%s'\n" "$(escape_for_single_quotes "${LOCAL_REPO_PATH}")"
        printf "BACKUP_REPORT_TO='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_TO:-}")"
        printf "BACKUP_REPORT_FROM='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_FROM}")"
        printf "BACKUP_REPORT_SUBJECT='%s'\n" "$(escape_for_single_quotes "${BACKUP_REPORT_SUBJECT}")"
        printf "SMTP_HOST='%s'\n" "$(escape_for_single_quotes "${SMTP_HOST:-}")"
        printf "SMTP_PORT='%s'\n" "$(escape_for_single_quotes "${SMTP_PORT}")"
        printf "SMTP_USER='%s'\n" "$(escape_for_single_quotes "${SMTP_USER:-}")"
        printf "SMTP_PASSWORD='%s'\n" "$(escape_for_single_quotes "${SMTP_PASSWORD:-}")"
        printf "SMTP_STARTTLS='%s'\n" "$(escape_for_single_quotes "${SMTP_STARTTLS}")"
        printf "SMTP_TLS='%s'\n" "$(escape_for_single_quotes "${SMTP_TLS}")"
    } > "${ENV_FILE}"

    chmod 600 "${ENV_FILE}"
}

configure_msmtp() {
    [ -z "${SMTP_HOST:-}" ] && return

    AUTH_LINE="auth off"
    if [ -n "${SMTP_USER:-}" ] || [ -n "${SMTP_PASSWORD:-}" ]; then
        AUTH_LINE="auth on"
    fi

    {
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
        [ -n "${SMTP_USER:-}" ] && echo "user ${SMTP_USER}"
        [ -n "${SMTP_PASSWORD:-}" ] && echo "password ${SMTP_PASSWORD}"
    } > /etc/msmtprc

    chmod 600 /etc/msmtprc
}

write_cron_file() {
    : "${BACKUP_REPORT_SCHEDULE:=0 6 * * 1}"

    {
        echo "SHELL=/bin/sh"
        echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
        printf "%s root . %s && /usr/local/bin/backup_report.sh >> %s 2>&1\n" "${BACKUP_REPORT_SCHEDULE}" "${ENV_FILE}" "${LOG_FILE}"
    } > "${CRON_FILE}"

    chmod 644 "${CRON_FILE}"
    touch "${LOG_FILE}"
}

write_env_file
configure_msmtp
write_cron_file

exec cron -f -L 15
