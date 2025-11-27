# Backup POC

## SSH-Schlüssel für den Pull-Nutzer bootstrappen

1. Optional das temporäre Passwort definieren: `export PULL_USER_PASSWORD="mein-sicheres-passwort"`.
2. Container bauen und starten: `docker compose up -d`.
3. Einmalig den Schlüsseltausch als dediziertem Service-Account auslösen: `docker compose exec -u pull_user server /usr/local/bin/setup_server.sh`.
4. Nach erfolgreichem Durchlauf ist `backup_puller` faktisch nur noch per SSH-Schlüssel erreichbar: Das anfängliche Passwort wird auf einen Zufallswert gedreht und das Schlüsselmaterial liegt unter `/home/pull_user/.ssh`.
5. Der Schlüsseltausch läuft per Passwort-Auth (`sshpass` als `pull_user`) und schreibt den Public Key in `authorized_keys`. Anschließend wird dieser Eintrag ersetzt durch einen erzwungenen rrsync-Call (`command="rrsync -ro /data/encrypted_stage",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`), sodass ausschließlich rsync-Pulls auf das Staging erlaubt sind.

Die relevanten Variablen können über Umgebungsvariablen gesteuert werden:

- `PULL_USER_PASSWORD` – temporäres Passwort während des Schlüsseltauschs (Standard: `puller-temp-password`)
- `CLIENT_HOST` / `CLIENT_PORT` – Adresse des Client-Containers (Standard: `client:22`)

Der Server-Container bringt einen eigenen Linux-Account (`pull_user`) mit, der beim Build via `USERNAME`/`USER_PASSWORD` überschrieben werden kann (`docker compose build --build-arg USERNAME=my_user --build-arg USER_PASSWORD=...`). Führe `setup_server.sh` und `pull_restic_repo.sh` immer mit `docker compose exec -u <USERNAME> server …` aus, damit SSH-Schlüssel und `known_hosts` konsistent im Home dieses Accounts landen.

## Restic-Repository vom Client ziehen

Das Repository liegt im Client unter `/data/encrypted_stage` und wird auf dem Server nach `/data/restic_repo` gespiegelt.

1. Sicherstellen, dass der SSH-Schlüsseltausch bereits erfolgt ist.
2. Synchronisation als Service-Account anstoßen: `docker compose exec -u pull_user server /usr/local/bin/pull_restic_repo.sh`.
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
| `docker-compose stop`      | ✅               | ❌                | ❌                | ❌              |
| `docker-compose down`      | ✅               | ✅                | ✅                | ❌              |
| `docker-compose down -v`   | ✅               | ✅                | ✅                | ✅              |
(-p poc_backup_e2e)

## End-to-End-Tests in Docker

Es gibt einen automatisierten Testlauf, der den kompletten Ablauf (Schlüsseltausch, Restic-Backup, Repo-Sync) mit synthetischen Testdaten durchspielt.

1. Docker muss verfügbar sein (`docker compose` oder `docker-compose`).
2. Script aufrufen: `tests/e2e/run.sh`
3. Das Skript stoppt vorhandene Container des Projekts (`poc_backup_e2e`), räumt `tests/tmp` auf und baut die Images frisch, bevor der Stack im Hintergrund startet.
4. Nach dem Start setzt das Skript die benötigten ACLs zur Laufzeit, initialisiert ein Restic-Repository und sichert die vorkonfigurierten Testdaten unter `/home/user/testdata` (aus `client/data/user_home`) verschlüsselt nach `/data/encrypted_stage`.
5. Anschließend werden `setup_server.sh` sowie `pull_restic_repo.sh` (im Container als `pull_user`) ausgeführt; der Lauf validiert, dass das Repository auf dem Server ankommt und keine Klartextmarker (`E2E_SECRET_TEST_PAYLOAD`) enthalten sind. Die Container bleiben danach bewusst aktiv, um eine manuelle Analyse zu ermöglichen; zur Bereinigung kann `docker compose -p poc_backup_e2e down -v` verwendet werden.

Da die Bereinigung (`sudo rm -rf tests/tmp`) mit erhöhten Rechten arbeitet, kann zu Beginn des Laufs eine lokale Passworteingabe für `sudo` erforderlich sein. Das für den Test verwendete Restic-Passwort lässt sich über `RESTIC_PASSWORD_VALUE`, der Compose-Projektname über `PROJECT_NAME` steuern. Weitere Variablen wie `PULL_USER_PASSWORD` sowie vorbereitete UID/GID-Overrides (`LOCAL_UID`, `LOCAL_GID`) können bei Bedarf vor dem Aufruf gesetzt werden.
