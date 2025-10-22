# Backup POC

## SSH-Schlüssel für den Pull-Nutzer bootstrappen

1. Optional das temporäre Passwort definieren: `export PULL_USER_PASSWORD="mein-sicheres-passwort"`.
2. Container bauen und starten: `docker compose up -d`.
3. Einmalig den Schlüsseltausch auslösen: `docker compose exec server /usr/local/bin/push_ssh_key.sh`.
4. Nach erfolgreichem Durchlauf ist `backup_puller` nur noch per SSH-Schlüssel erreichbar; der Passwort-Login wurde gesperrt.

Die relevanten Variablen können über Umgebungsvariablen gesteuert werden:

- `PULL_USER_PASSWORD` – temporäres Passwort während des Schlüsseltauschs (Standard: `puller-temp-password`)
- `CLIENT_HOST` / `CLIENT_PORT` – Adresse des Client-Containers (Standard: `client:22`)

## Restic-Repository vom Client ziehen

Das Repository liegt im Client unter `/data/encrypted_stage` und wird auf dem Server nach `/data/restic_repo` gespiegelt.

1. Sicherstellen, dass der SSH-Schlüsseltausch bereits erfolgt ist.
2. Synchronisation anstoßen: `docker compose exec server /usr/local/bin/pull_restic_repo.sh`.
3. Der Sync nutzt `rsync` und überträgt nur Änderungen; lokale Daten liegen anschließend unter `./server/data`.

Weitere Parameter:

- `REMOTE_REPO_PATH` – Pfad zum Restic-Repo auf dem Client (Standard: `/data/encrypted_stage`)
- `LOCAL_REPO_PATH` – Zielpfad im Server-Container (Standard: `/data/restic_repo`)
