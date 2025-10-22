# /home/user/backup-poc/server/Dockerfile
FROM alpine:latest

# tools installieren
RUN apk add --no-cache nano openssh-client sshpass rsync

# SSH-Schlüsselpaar für den root-User im Container generieren
RUN ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

# Script für den automatisierten Schlüsseltausch
COPY scripts/push_ssh_key.sh /usr/local/bin/push_ssh_key.sh
RUN chmod +x /usr/local/bin/push_ssh_key.sh

# Script zum Synchronisieren des Restic-Repos
COPY scripts/pull_restic_repo.sh /usr/local/bin/pull_restic_repo.sh
RUN chmod +x /usr/local/bin/pull_restic_repo.sh

# Private Key & known_hosts laden
#COPY ./ssh/ /root/.ssh/
#RUN chmod 600 /root/.ssh/id_rsa

# Container am Laufen halten
CMD ["tail", "-f", "/dev/null"]
