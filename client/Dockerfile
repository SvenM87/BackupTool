# /home/user/backup-poc/client/Dockerfile
FROM ubuntu:22.04

#ARG DEBIAN_FRONTEND=noninteractive

# Basissystem einrichten
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    nano

# User-Parameter
ARG USERNAME=user
ARG USER_PASSWORD=123456

# Nutzer erstellen
RUN useradd -m -s /bin/bash ${USERNAME} \
    && echo "${USERNAME}:${USER_PASSWORD}" | chpasswd \
    && usermod -aG sudo ${USERNAME}

# Setup-Skript kopieren und ausführen
COPY data/user_home/ /home/${USERNAME}/
COPY scripts/setup_client.sh /home/${USERNAME}/setup_client.sh
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/ && \
    chmod +x /home/${USERNAME}/setup_client.sh

ENV PULL_USER_PASSWORD=${PULL_USER_PASSWORD}


EXPOSE 22
# CMD ["/usr/sbin/sshd", "-D"]

CMD ["tail", "-f", "/dev/null"]