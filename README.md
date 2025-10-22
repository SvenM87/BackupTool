# Backup POC

## SSH-Schlüssel für den Pull-Nutzer bootstrappen

1. Optional das temporäre Passwort definieren: `export PULL_USER_PASSWORD="mein-sicheres-passwort"`.
2. Container bauen und starten: `docker compose up -d`.
3. Einmalig den Schlüsseltausch auslösen: `docker compose exec server /usr/local/bin/push_ssh_key.sh`.
4. Nach erfolgreichem Durchlauf ist `backup_puller` nur noch per SSH-Schlüssel erreichbar; der Passwort-Login wurde gesperrt.

Die relevanten Variablen können über Umgebungsvariablen gesteuert werden:

- `PULL_USER_PASSWORD` – temporäres Passwort während des Schlüsseltauschs (Standard: `puller-temp-password`)
- `CLIENT_HOST` / `CLIENT_PORT` – Adresse des Client-Containers (Standard: `client:22`)
