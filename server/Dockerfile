# /home/user/backup-poc/server/Dockerfile
FROM ubuntu:22.04

# tools installieren
RUN apt-get update && apt-get install -y nano openssh-client sshpass rsync

# User-Parameter
ARG USERNAME=pull_user
ARG USER_PASSWORD=puller-temp-password

# Nutzer erstellen
RUN useradd -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
# RUN usermod -aG sudo ${USERNAME}

RUN mkdir -p /data/restic_repo && chown ${USERNAME}:${USERNAME} /data/restic_repo

# USER ${USERNAME}
# WORKDIR /home/${USERNAME}

# SSH-Schlüsselpaar für den root-User im Container generieren
# RUN ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

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
