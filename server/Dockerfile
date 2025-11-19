# /home/user/backup-poc/server/Dockerfile
FROM ubuntu:22.04

# tools installieren
RUN apt-get update && apt-get install -y nano


# Script für den automatisierten Schlüsseltausch
COPY scripts/setup_server.sh /usr/local/bin/setup_server.sh
RUN chmod +x /usr/local/bin/setup_server.sh

# Script zum Synchronisieren des Restic-Repos
COPY scripts/pull_restic_repo.sh /usr/local/bin/pull_restic_repo.sh
RUN chmod +x /usr/local/bin/pull_restic_repo.sh

# Container am Laufen halten
CMD ["tail", "-f", "/dev/null"]
