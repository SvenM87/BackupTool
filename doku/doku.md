# Projektdokumentation

## Projektplanung

### Phase 1
- Projektauftrag formulieren (Ziele, Zeitrahmen, Team)
    - Ziele:
        - Prof of Concept einer malware-sicheren Backup-Lösung für Linux-Clients und -Server
        - Nachweis der Funktionalität und Sicherheit durch Pilotumsetzung auf einem Testsystem mit Server und Client (Docker).
    - Team:
        - Sven Matzik		Sprecher
        - Ruben Saath		Koordinator
        - Marvin Mahlke		Mitarbeiter
    - Termin Abgabe/Präsentation (moodle)
        - Präsentation
        - 06.01.2026
        - 10min Sprecher Präsentiert
        - 8 Folien "best-of"/eine Darstellung, die die Vorlesung vertieft
    - Abgabe
        - GitHub i.O.
        - ~4 Seiten pro TN

### PHASE 2: ANFORDERUNGSANALYSE & KRITERIENKATALOG (0,5 WOCHEN)
- Erhebung der funktionalen Anforderungen (Zero-Trust, Verschlüsselung, Inkremente, Pull-Prinzip)
        - Sichere Backup Lösung mit Linux-basiertem Client und Server
        - mit Zero-Trust 
            - Verschlüsselung ausschließlich auf dem Client
            - Server speichert nur Ciphertext, kein Zugriff auf private Schlüssel
        - inkrementelle Sicherung
        - Realisierung eines Pull-Prinzips:
            - Backup-Server zieht Daten vom Server
            - Client ohne Zugriff auf den Server
        - Einsatz von WORM/Snapshots oder Append-only.
        - sicher bei kompromittiertem Client oder Server
            - Integritätsprüfung
        - Client ohne Zugriff auf Server
            - Drei Nutzer strategie auf Client
- Erhebung der qualitativen Anforderungen (Performance, Skalierbarkeit, Wiederherstellung)
- Aufnahme von Compliance-/Security-Anforderungen (BSI, ISO 27001)
- Priorisierung nach MoSCoW (Muss/Soll/Kann)
- Erstellung eines Kriterienkatalogs mit Gewichtung (z. B. AHP-Methodik: Sicherheit, Funktionalität, Performance, Kosten)

#### KRITERIENKATALOG INKL. BEWERTUNGSSKALA (BACKUPSYSTEM)
1. SICHERHEIT / ZERO-TRUST (50 %)
    1. Verschlüsselung
        - 0: Keine Verschlüsselung
        - 1–2: Serverseitige Verschlüsselung, schwache Algorithmen
        - 3: Clientseitige Verschlüsselung, Standard-Algorithmen
        - 4: Clientseitige Verschlüsselung, starke Algorithmen (AES-256, ChaCha20), Metadaten teilweise verschlüsselt
        - 5: Vollständige Verschlüsselung aller Daten & Metadaten ausschließlich clientseitig
    2. Zugriffstrennung
        - 0: Client hat vollen Zugriff auf Server
        - 3: Client hat eingeschränkten Zugriff (z. B. nur Schreibrechte)
        - 5: Reines Pull-Prinzip, Client ohne jeglichen Serverzugriff
    3. Manipulationsschutz
        - 0: Backups können jederzeit gelöscht/überschrieben werden^
        - 3: Löschungen eingeschränkt (ACLs, eingeschränkte Userrechte)
        - 5: Append-only / WORM / Snapshots mit Nachweis, dass alte Backups unveränderbar sind
    4. Integrität & Auditierbarkeit
        - 0: Keine Integritätsprüfung
        - 2–3: Prüfsummen vorhanden, aber nicht automatisiert
        - 5: Automatische Hash-Prüfungen, Audit-Logs, revisionssichere Historie
2. FUNKTIONALITÄT (25 %)
    1. Backup-Arten
        - 0: Nur Vollbackups
        - 2–3: Inkrementell möglich, aber ohne effiziente Deduplikation
        - 5: Kombination aus Voll, inkrementell & Snapshots mit effizienter Deduplikation
    2. Speicheroptimierung (Deduplikation & Kompression)
        - 0: Keine Optimierung
        - 2: Einfache Kompression oder dateibasierte Deduplikation
        - 5: Blockweise Deduplikation + Kompression integriert
    3. Wiederherstellung (Restore)
        - 0: Kein Restore-Test möglich
        - 2–3: Restore nur komplett oder eingeschränkt (z. B. nur einzelne Dateien)
        - 5: Granulare Wiederherstellung (Datei, Verzeichnis, System), Disaster-Recovery getestet
    4. Automatisierung & Integration
        - 0: Manuelle Ausführung
        - 2: Teilweise Automatisierung über Skripte
        - 5: Vollautomatisch über Timer/APIs + Integration in Monitoring & Alarmierung
3. PERFORMANCE & SKALIERBARKEIT (25 %)
    1. Datendurchsatz (hardwareabhängig)
        - 0: Sehr langsam (< ?? MB/s bei großen Daten)
        - 3: Solide Performance (> ?? MB/s, parallelisierte Prozesse möglich)
        - 5: Hohe Performance (> ?? MB/s, Skalierung auf mehrere Threads/Nodes)
    2. Effizienz bei vielen kleinen Dateien
        - 0: Starke Einbrüche bei >500k Dateien
        - 3: Akzeptabel mit Indexing/Caching
        - 5: Optimiert für Millionen Dateien, Metadatenzugriff performant
    3. Skalierbarkeit
        - 0: Nur ein Client/Server-Szenario unterstützt
        - 3: Mehrere Clients, aber eingeschränkte Verwaltung
        - 5: Beliebig viele Clients, zentral verwaltbar, flexible Storage-Backends (S3, Filesystem, Cloud)
    4. Komplexität
        ToDo
4. KOSTEN & BETRIEB ( %) <- ??? SINVOLL ??? JA! ToDo
    1. Kosten (TCO 5 Jahre)
        - 0: Sehr hohe Kosten, proprietär, >200 % Budget
        - 3: Mittlere Kosten, Support notwendig, evtl. Lizenzgebühren
        - 5: Open-Source oder geringe Lizenzkosten, TCO im Budget
    2. Betriebsaufwand
        - 0: Hoher Admin-Aufwand, manuelle Pflege nötig
        - 3: Teilweise automatisiert, moderate Wartung
        - 5: Minimaler Wartungsaufwand, automatische Updates, gute Doku/Community
    3. Zukunftssicherheit
        - 0: Keine Weiterentwicklung, Support <2 Jahre
        - 3: Aktive Community oder eingeschränkter Herstellersupport
        - 5: Hersteller- oder Community-Support ≥5 Jahre, aktive Roadmap & Sicherheitsupdates


### PHASAE 3: MARKTRECHERCHE & VORAUSWAHL (2 WOCHEN)
- Recherche relevanter Backup-Lösungen (Restic, BorgBackup, Kopia).
    - rSync geringe performance bei großen Datenmengen
    - syncovery (Kosten)
- Erstellung eines Produktkatalogs mit Bewertung anhand der Kriterien.
- Auswahl von 2–3 Kandidaten für PoC.

### PHASE 4: PROOF OF CONCEPT (3 WOCHEN)
- Einrichtung einer Testumgebung (Testserver + 1–2 Clients).
- Durchführung von Testszenarien:
    - Backup (& Restore) (verschlüsselt, inkrementell).
    - Verhalten bei kompromittiertem Client oder Server.
    - Monitoring & Logging überprüfen.
    - Performance- und Lasttests.
    - (Kompatibilität mit Storage (z. B. S3 oder lokales FS).)
- Bewertung der Systeme nach Entscheidungsmatrix (Punkte je Kriterium).

### Phase 5: Ergebnis & Learnings (1 Woche)
- Erstellung eines Bewertungsberichts (Score-Tabelle, Diagramme).
- Dokumentation der Ergebnisse und Empfehlung einer Backup-Lösung.

## DOKUMENTATION

### TESTUMGEBUNG (DOCKER)
Die Architektur der Testumgebung basiert auf einer Client-Server-Struktur, welche eine funktionsfähige SSH-Verbindung zwischen den beiden Komponenten voraussetzt. Um die Datenpersistenz über den Lebenszyklus der Container hinaus zu gewährleisten, werden sowohl die Testdaten (im Verzeichnis /home/user) als auch die verschlüsselten Daten des Clients (/data/encrypted_stage) in einem persistenten Speichervolumen vorgehalten. Notwendige, container-spezifische Konfigurationen oder Software-Abhängigkeiten werden über eine separate Dockerfile deklariert.

Für den Betrieb des Client-Containers ist die Konfiguration mehrerer Benutzerkonten erforderlich. Neben einem allgemeinen Systembenutzer (`user`) werden die dedizierten Nutzer `backup_encoder` (verschlüsselt und bereitet Daten vor) sowie `backup_puller` (stellt die verschlüsselten Artefakte bereit) angelegt. Die Software-Ausstattung des Containers wird zum Build-Zeitpunkt durch die Installation von OpenSSH-Server, sudo, nano, acl, rsync und restic erweitert. Der Einsatz von ACL ermöglicht eine fein-granulare Steuerung der Dateiberechtigungen. Die initialen Benutzerkonten, die für die Backup-Prozesse benötigt werden, werden durch ein Skript automatisiert erstellt und würden in einem produktiven System der einmaligen Initialisierung dienen.

Der Server-Container basiert auf dem minimalen alpine:latest Image, um eine schlanke und sichere Laufzeitumgebung zu gewährleisten. Die primäre Konfiguration während des Build-Prozesses umfasst die Erstellung eines SSH-Schlüsselpaares (RSA, 4096 Bit) für den root-Benutzer. Dieses Schlüsselpaar wird direkt im Image hinterlegt und dient der passwortlosen Authentifizierung für ausgehende Verbindungen. Für den Betrieb werden nano, openssh-client, sshpass und rsync installiert. Während nano als einfacher Texteditor zur Verfügung steht, ermöglicht der openssh-client zusammen mit sshpass den Schlüsseltausch sowie passwortgestützte Erstverbindungen zum Client. Um den Container nach dem Start dauerhaft aktiv zu halten und ein sofortiges Beenden zu verhindern, wird der Befehl tail -f /dev/null als Standardkommando ausgeführt.

Quellen:
- Docker Compose Referenz: https://docs.docker.com/reference/compose-file/
- Dockerfile Dokumentation: https://docs.docker.com/get-started/docker-concepts/building-images/writing-a-dockerfile/
- Bash Scripting Tutorial: https://www.freecodecamp.org/news/bash-scripting-tutorial-linux-shell-script-and-command-line-for-beginners/

### TEST DES SYSTEMS
1. Stack bauen und starten  
   - `docker-compose up --build -d`  
   - Sobald die Container laufen, lassen sich Logs per `docker-compose logs -f` prüfen.
2. Testdaten auf dem Client anlegen  
   - `docker exec -it -u user backup_client bash`  
   - `nano ~/test.txt` und Beispielinhalt speichern.  
   - `cat ~/test.txt` sicherstellt, dass die Datei verfügbar ist.
3. Wechsel und Berechtigungen für `backup_encoder` prüfen  
   - Innerhalb des Containers: `sudo -u backup_encoder bash`.  
   - Lesen funktioniert (`cat /home/user/test.txt`), Schreiben wird verweigert (`nano /home/user/test.txt` → *Permission denied*).  
   - Kopieren in das verschlüsselte Staging: `cp /home/user/* /data/encrypted_stage/` und anschließend `ls /data/encrypted_stage/`.
4. SSH-Schlüsseltausch und Pull testen  
   - `docker exec -it backup_server sh` und `cat ~/.ssh/id_rsa.pub` auf dem Server ausgeben.  
   - `docker exec -it -u backup_puller backup_client bash` und den Schlüssel unter `~/.ssh/authorized_keys` hinterlegen.  
   - Vom Server aus den Zugriff verifizieren: `scp backup_puller@client:/data/encrypted_stage/* /tmp/`.
