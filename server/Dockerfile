# /home/user/backup-poc/server/Dockerfile
FROM alpine:latest

# tools installieren
RUN apk add --no-cache nano openssh-client

# SSH-Schlüsselpaar für den root-User im Container generieren
RUN ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""

# Private Key & known_hosts laden
#COPY ./ssh/ /root/.ssh/
#RUN chmod 600 /root/.ssh/id_rsa

# Container am Laufen halten
CMD ["tail", "-f", "/dev/null"]
