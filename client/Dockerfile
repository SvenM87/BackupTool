# /home/user/backup-poc/client/Dockerfile
FROM ubuntu:22.04

#ARG DEBIAN_FRONTEND=noninteractive

# Basissystem einrichten
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    nano \
    acl \
	restic

# User-Parameter
ARG USERNAME=user
ARG USER_PASSWORD=123456
ARG PULL_USER_PASSWORD=puller-temp-password

# Nutzer erstellen
RUN useradd -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME}:${USER_PASSWORD}" | chpasswd \
    && usermod -aG sudo ${USERNAME}

# Setup-Skript kopieren und ausführen
COPY scripts/setup_users.sh /home/${USERNAME}/setup_users.sh
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/setup_users.sh \
    && chmod +x /home/${USERNAME}/setup_users.sh

ENV PULL_USER_PASSWORD=${PULL_USER_PASSWORD}

# Zum neuen Nutzer wechseln und Skript ausführen
USER ${USERNAME}
WORKDIR /home/${USERNAME}
# 'echo ... |' dient dazu, das Sudo-Passwort zu übergeben
RUN echo "${USER_PASSWORD}" | sudo -SE /home/${USERNAME}/setup_users.sh

# Zurück zu root, Service starten
USER root
WORKDIR /

# SSH Schlüssel des Servers laden
#COPY ./ssh/authorized_keys /home/backup_puller/.ssh/authorized_keys
#RUN chown backup_puller:backup_puller /home/backup_puller/.ssh/authorized_keys \
# && chmod 600 /home/backup_puller/.ssh/authorized_keys

# SSH-Konfiguration und Startbefehl
RUN mkdir -p /var/run/sshd

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
