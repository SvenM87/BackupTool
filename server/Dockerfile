# /home/user/backup-poc/server/Dockerfile
FROM ubuntu:22.04

# Tools für SSH, Cron und Mailversand installieren
RUN apt-get update && apt-get install -y \
    nano sudo cron msmtp-mta ca-certificates


# Script für den automatisierten Schlüsseltausch
COPY scripts/setup_server.sh /usr/local/bin/setup_server.sh
RUN chmod +x /usr/local/bin/setup_server.sh

# Script zum Synchronisieren des Restic-Repos
COPY scripts/pull_restic_repo.sh /usr/local/bin/pull_restic_repo.sh
RUN chmod +x /usr/local/bin/pull_restic_repo.sh

# Report-Skript und Entry-Point für Cron
COPY scripts/backup_report.sh /usr/local/bin/backup_report.sh
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/backup_report.sh /usr/local/bin/entrypoint.sh

# Container am Laufen halten
CMD ["/usr/local/bin/entrypoint.sh"]
