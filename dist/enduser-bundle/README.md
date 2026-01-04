# Endnutzer-Bundle – Einrichtung

## Inhalt des Bundles
- `client/scripts/setup_client.sh` – richtet Backup-Nutzer und Berechtigungen auf dem Client ein, erzeugt das temporäre Pull-Passwort.
- `server/scripts/setup_server.sh` – richtet den Pull-User auf dem Server ein, tauscht den SSH-Schlüssel aus und konfiguriert den Mail-Report (SMTP).
- `server/scripts/pull_restic_repo.sh` – zieht das Restic-Repository per rsync auf den Server.
- `server/scripts/backup_report.sh` – erstellt den wöchentlichen Statusbericht.
- `README` (diese Datei) – Ablauf und Hinweise.

## Wichtige Hinweise
- Das im Client-Setup erzeugte temporäre Pull-Passwort wird nur angezeigt. Bitte sofort notieren und sicher aufbewahren; es wird nicht gespeichert.
- Nur das SMTP-Passwort wird serverseitig persistiert (`/etc/backup_report.env` und `/etc/msmtprc`) für den Mailversand.
- Standardpfade: Datenquelle `/home/<SUDO_USER>`, verschlüsseltes Repo auf dem Client `/data/encrypted_stage`, lokales Repo auf dem Server `/data/restic_repo`.
- Die Skripte erkennen fehlende TTYs und verwenden dann die Defaults/ENV-Variablen ohne Prompts (z.B. für automatisierte Tests).

## Schritt 1: Client vorbereiten
1. Als Benutzer mit sudo-Rechten ausführen: `sudo client/scripts/setup_client.sh`
2. Prompts beantworten:
   - Pull-Nutzer (Default `backup_puller`)
   - Pfad zu den zu sichernden Daten (Default `/home/<SUDO_USER>`)
   - Pfad für das verschlüsselte Restic-Repository (Default `/data/encrypted_stage`)
   - Temporäres Pull-Passwort: leer lassen für zufälligen Wert oder eigenes setzen
3. Am Ende zeigt das Skript das temporäre Pull-Passwort an – manuell notieren.
4. SSH-Server auf dem Client sicherstellen/starten (falls nicht aktiv).

## Schritt 2: Server vorbereiten
1. Als root ausführen: `sudo server/scripts/setup_server.sh`
2. Prompts beantworten:
   - Client-Hostname/IP und SSH-Port
   - Pull-Nutzer (wie auf dem Client)
   - Pfad zum Remote-Repo (Default `/data/encrypted_stage`) und lokaler Zielpfad (Default `/data/restic_repo`)
   - Temporäres Pull-Passwort (vom Client-Setup notiert)
   - Mail-Report/SMTP: Empfänger, Absender, Betreff, SMTP-Host/Port/User/Passwort, TLS/STARTTLS
3. Das Skript installiert openssh-client/sshpass/rsync/msmtp, legt den Pull-User an, tauscht den Schlüssel aus, deaktiviert den Passwort-Login und schreibt `/etc/backup_report.env` sowie `/etc/msmtprc` (nur bei gesetztem SMTP-Host).

## Schritt 3: Erstes Repository ziehen
- Auf dem Server ausführen: `sudo server/scripts/pull_restic_repo.sh`
- Der rsync-Call nutzt den Pull-User-Schlüssel und synchronisiert nach `/data/restic_repo` (oder den gewählten Pfad).

## Schritt 4: Backup-Report per Cron einplanen
- `/etc/backup_report.env` wurde vom Setup geschrieben. Für den regelmäßigen Report einen Cronjob anlegen, z.B.:
  `echo "0 6 * * 1 root /usr/local/bin/backup_report.sh >> /var/log/backup_report.log 2>&1" >/etc/cron.d/backup_report`
- Mailversand erfolgt nur, wenn `BACKUP_REPORT_TO` und `SMTP_HOST` gesetzt sind.

## Automatisierte/Non-Interactive Nutzung
- Bei fehlender TTY werden die Prompts übersprungen; es werden ENV-Werte oder Defaults genutzt.
- Relevante ENV-Variablen: `CLIENT_HOST`, `CLIENT_PORT`, `PULL_USER`, `PULL_USER_PASSWORD`, `REMOTE_REPO_PATH`, `LOCAL_REPO_PATH`, `BACKUP_REPORT_*`, `SMTP_*`.
- Für den Client kann `PULL_USER_PASSWORD` gesetzt werden, sonst wird ein Zufallswert generiert. Auf dem Server muss `PULL_USER_PASSWORD` gesetzt sein, wenn keine interaktive Eingabe möglich ist.

## Sicherheit und Aufbewahrung
- Nur SMTP-Zugangsdaten werden gespeichert. `PULL_USER_PASSWORD` wird nach dem Schlüsseltausch auf dem Client durch einen Zufallswert ersetzt.
- `/etc/backup_report.env` und `/etc/msmtprc` liegen mit 600-Rechten vor – bei Bedarf zusätzliche Zugriffssteuerung anwenden.
