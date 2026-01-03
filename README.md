# Backup POC

## SSH-Schlüssel für den Pull-Nutzer bootstrappen

1. Stack bauen und starten: `docker compose up -d --build` (alternativ `docker-compose`).
2. Client vorbereiten (installiert Pakete, legt `backup_encoder`/`backup_puller` an, setzt ACLs, erzeugt ein temporäres Passwort):\
   `docker compose exec -T -u user client bash -lc "echo 123456 | sudo -S ~/setup_client.sh"`\
   Das Passwort steht in der Ausgabe zwischen `<:` und `:>`.
3. SSHD im Client starten: `docker compose exec -d client /usr/sbin/sshd -D`.
4. Schlüsseltausch vom Server auslösen (als root, mit dem Passwort aus Schritt 2):\
   `docker compose exec -T -e "PULL_USER_PASSWORD=<passwort>" server /usr/local/bin/setup_server.sh`
5. Danach ist `backup_puller` nur noch per SSH-Schlüssel erreichbar: Das Passwort wird auf einen Zufallswert gedreht und `authorized_keys` enthält eine rrsync-Restriktion (`command="rrsync -ro /data/encrypted_stage",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`), sodass ausschließlich rsync-Pulls erlaubt sind.

Relevante Variablen:

- `PULL_USER` – Name des Pull-Accounts auf Client und Server (Standard: `backup_puller`)
- `PULL_USER_PASSWORD` – temporäres Passwort für den Schlüsseltausch (Standard: `puller-temp-password`, im Client-Setup automatisch generiert)
- `CLIENT_HOST` / `CLIENT_PORT` – Ziel des SSH-Zugriffs (Standard: `client:22`)

`setup_server.sh` installiert die benötigten Pakete, legt den Pull-User an (falls fehlend) und erzeugt das Schlüsselpaar. Der Nutzer wird also erst beim ersten Aufruf des Skripts erstellt, nicht beim Build.

## Restic-Repository vom Client ziehen

Das verschlüsselte Restic-Repository liegt im Client unter `/data/encrypted_stage` und wird auf dem Server nach `/data/restic_repo` gespiegelt. Falls das Repository noch nicht existiert, kann es im Client erstellt werden:

```
docker compose exec -T -u backup_encoder client bash -lc "export RESTIC_PASSWORD='mein-passwort'; if [ ! -f /data/encrypted_stage/config ]; then restic -r /data/encrypted_stage init --no-cache; fi; restic -r /data/encrypted_stage backup /home/user/testdata --no-cache"
```

1. Sicherstellen, dass der SSH-Schlüsseltausch bereits erfolgt ist.
2. Synchronisation anstoßen (als root oder Pull-User; bei root erfolgt ein automatisches `su`):\
   `docker compose exec server /usr/local/bin/pull_restic_repo.sh`
3. Der Sync nutzt `rsync` und überträgt nur Änderungen; lokale Daten liegen anschließend unter `./server/data`.

Weitere Parameter:

- `REMOTE_REPO_PATH` – Pfad zum Restic-Repo auf dem Client (Standard: `/data/encrypted_stage`)
- `LOCAL_REPO_PATH` – Zielpfad im Server-Container (Standard: `/data/restic_repo`)

## Wöchentlicher Statusbericht per Mail

Der Server-Container schickt einmal pro Woche automatisch einen Statusbericht zum Backup-Repository (Cron-Job, Standard: Montag 06:00 Uhr). Die Mail enthält Pfad, Anzahl Snapshot-Dateien, letzte Änderung und Größe des Repos. Der Versand erfolgt über `msmtp`; konfiguriere dazu die folgenden Variablen beim Start des Containers (`docker compose up ...`):

- `BACKUP_REPORT_TO` – Empfänger-Adresse (Pflicht für Mailversand)
- `BACKUP_REPORT_FROM` – Absender-Adresse (Standard: `backup-report@<hostname>`)
- `BACKUP_REPORT_SCHEDULE` – Cron-Expression, wann der Report laufen soll (Standard: `0 6 * * 1`)
- `SMTP_HOST` – SMTP-Server (Pflicht)
- `SMTP_PORT` – SMTP-Port (Standard: `587`)
- `SMTP_USER` / `SMTP_PASSWORD` – Zugangsdaten (optional, aktiviert Auth wenn gesetzt)
- `SMTP_TLS` / `SMTP_STARTTLS` – TLS/STARTTLS-Schalter (`on`/`off`, Standard: `on`)

Im End-to-End-Setup werden diese Werte nicht mehr über Docker-Umgebungsvariablen gesetzt, sondern über `tests/e2e/backup_report.env` bereitgestellt und als `/etc/backup_report.env` in den Server-Container gemountet. Passe die Datei vor dem Start an, falls der Mailversand in der Testumgebung aktiv sein soll.

Beim Container-Start erzeugt `entrypoint.sh` die Cron-Definition sowie `/etc/backup_report.env` (falls nicht bereits vorhanden) und schreibt die `msmtp`-Konfiguration. Logs liegen unter `/var/log/backup_report.log`. Ein manueller Versand ist jederzeit möglich: `docker compose exec server /usr/local/bin/backup_report.sh`.

## Manuelles Testen mit Docker

1. Stack bauen und im Hintergrund starten: `docker compose up --build -d`.
2. Client-Setup inkl. ACLs starten: `docker compose exec -T -u user client bash -lc "echo 123456 | sudo -S ~/setup_client.sh"`.
3. SSHD im Client starten: `docker compose exec -d client /usr/sbin/sshd -D`.
4. Restic-Repo im Client initialisieren und Testdaten sichern (siehe Beispiel oben).
5. Schlüsseltausch und Pull: `docker compose exec -T -e "PULL_USER_PASSWORD=<passwort>" server /usr/local/bin/setup_server.sh` und anschließend `docker compose exec server /usr/local/bin/pull_restic_repo.sh`.

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
5. Anschließend laufen `setup_server.sh` (als root, legt den Pull-User an und tauscht den Schlüssel) sowie `pull_restic_repo.sh` (als `backup_puller`); der Lauf validiert, dass das Repository auf dem Server ankommt und keine Klartextmarker (`E2E_SECRET_TEST_PAYLOAD`) enthalten sind. Die Container bleiben danach bewusst aktiv, um eine manuelle Analyse zu ermöglichen; zur Bereinigung kann `docker compose -p poc_backup_e2e down -v` verwendet werden.
6. Die Mail-Konfiguration für den Report wird für den E2E-Stack aus `tests/e2e/backup_report.env` gelesen und als `/etc/backup_report.env` in den Server-Container eingebunden.

Da die Bereinigung (`sudo rm -rf tests/tmp`) mit erhöhten Rechten arbeitet, kann zu Beginn des Laufs eine lokale Passworteingabe für `sudo` erforderlich sein. Das für den Test verwendete Restic-Passwort lässt sich über `RESTIC_PASSWORD_VALUE`, der Compose-Projektname über `PROJECT_NAME` steuern. Weitere Variablen wie `PULL_USER_PASSWORD` sowie vorbereitete UID/GID-Overrides (`LOCAL_UID`, `LOCAL_GID`) können bei Bedarf vor dem Aufruf gesetzt werden.
