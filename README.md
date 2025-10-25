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

## Manuelles Testen mit Docker

1. Stack bauen und im Hintergrund starten: `docker-compose up --build -d`.
2. In den Client-Container einloggen: `docker exec -it -u user backup_client bash`.
3. Innerhalb des Containers in den Systembenutzer wechseln: `sudo -u backup_encoder bash`.

| Befehl                     | Stoppt Container | Entfernt Container | Entfernt Netzwerk | Entfernt Volumes |
|----------------------------|------------------|--------------------|-------------------|------------------|
| `docker-compose stop`      | ✅               | ❌                 | ❌                | ❌               |
| `docker-compose down`      | ✅               | ✅                 | ✅                | ❌               |
| `docker-compose down -v`   | ✅               | ✅                 | ✅                | ✅               |

## End-to-End-Tests in Docker

Es gibt einen automatisierten Testlauf, der den kompletten Ablauf (Schlüsseltausch, Restic-Backup, Repo-Sync) mit synthetischen Testdaten durchspielt.

1. Docker muss verfügbar sein (`docker compose` oder `docker-compose`).
2. Script aufrufen: `tests/e2e/run.sh`
3. Der Lauf erstellt temporäre Verzeichnisse unter `tests/tmp`, füllt `/home/user/testdata` mit Prüfinhalten, initialisiert per Restic ein Repository unter `/data/encrypted_stage`, sichert die Testdaten verschlüsselt, führt anschließend `push_ssh_key.sh` sowie `pull_restic_repo.sh` aus und überprüft, dass die verschlüsselten Artefakte auf dem Server landen (inkl. Negativ-Check auf Klartext).

Nach Abschluss werden Container und temporäre Daten automatisch entfernt.

Die SSH-Schlüssel werden bei jedem Durchlauf neu erzeugt und nicht mehr über Host-Volumes persistiert. Wenn andere Pfade für Daten oder Repo verwendet werden sollen, lassen sie sich via Umgebungsvariablen (`CLIENT_USER_HOME_VOLUME`, `CLIENT_ENCRYPTED_VOLUME`, `SERVER_REPO_VOLUME`) überschreiben. Das für den Test verwendete Restic-Passwort kann über `RESTIC_PASSWORD_VALUE` gesetzt werden.
