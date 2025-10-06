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

# Nutzer erstellen
RUN useradd -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME}:${USER_PASSWORD}" | chpasswd \
    && usermod -aG sudo ${USERNAME}

# Setup-Skript kopieren und ausführen
COPY scripts/setup_users.sh /home/${USERNAME}/setup_users.sh
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/setup_users.sh \
    && chmod +x /home/${USERNAME}/setup_users.sh

# Zum neuen Nutzer wechseln und Skript ausführen
USER ${USERNAME}
WORKDIR /home/${USERNAME}
# 'echo ... |' dient dazu, das Sudo-Passwort zu übergeben
RUN echo "${USER_PASSWORD}" | sudo -S /home/${USERNAME}/setup_users.sh

# Zurück zu root, Service starten
USER root
WORKDIR /

# SSH-Konfiguration und Startbefehl
RUN mkdir -p /var/run/sshd

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
