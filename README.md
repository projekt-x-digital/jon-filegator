# Jonova News FileGator

Schlanker, kundenspezifischer FileGator-Fork für
`https://shopdaten.jonova.de/`, basierend auf FileGator 7.15.1.

Angemeldete Benutzer pflegen die Dateien im Portal. Bilder und PDFs werden
unter `https://shopdaten.jonova.de/files/...` von Nginx öffentlich und
schreibgeschützt ausgeliefert. Im Datei-Dropdown erzeugt
**„Öffentlichen Link kopieren“** genau diese URL.

## Enthalten

- FileGator-Backend und Vue-Frontend
- schlanker Produktions-Build, der im Deployment-Workflow erzeugt wird
- kundenspezifisches Logo und Markenfarben
- deutsche Oberfläche mit englischer Rückfallsprache
- manuelles GitHub-Deployment mit atomarem `live`-Symlink und Rollback
- Build- und Deployment-Skripte

Tests, CI-Testworkflow, Docker-Umgebung, Upstream-Dokumentationswebsite und
Entwicklungsbeispiele sind bewusst nicht enthalten.

## Branding

Das Logo liegt unter `branding/logo.svg`. Die Markenfarben werden in
`frontend/assets/scss/theme/_brand.scss` gepflegt. Nach Änderungen muss das
Frontend neu gebaut werden.

## Release bauen

Der Build benötigt Composer, PHP 8.4 und Node.js 22:

```bash
composer install --no-dev --no-interaction --prefer-dist --classmap-authoritative
npm ci
npm run build
scripts/build-release.sh
```

Das Ergebnis liegt unter `build/shopdaten.jonova-filegator.tar.gz`. Es enthält
keine Benutzer, Sessions, hochgeladenen Dateien oder Secrets.

## Deployment

Der GitHub-Workflow **Deploy production** wird manuell gestartet. Er benötigt
diese Repository-Secrets:

- `SSH_HOST`
- `SSH_PORT`
- `SSH_PRIVATE_KEY`
- `SSH_USER_PRODUCTION`
- `WORK_DIR_PRODUCTION` (normalerweise `/var/www/shopdaten.jonova.de`)

Optional kann die Repository-Variable `HEALTHCHECK_URL` gesetzt werden. Ohne
Angabe wird `https://shopdaten.jonova.de/index.php?r=/getconfig` verwendet.
`PHP_FPM_SERVICE` ist ebenfalls optional und verwendet standardmäßig
`php8.4-fpm`.

Das Deployment legt Releases unter `releases/<release-id>` ab, verknüpft die
persistenten Daten, übernimmt die mitgelieferte `configuration_sample.php` als
Release-Konfiguration und schaltet anschließend
`/var/www/shopdaten.jonova.de/live` atomar auf das neue Release. Bei einem
fehlgeschlagenen Healthcheck wird der vorherige Stand wieder aktiviert. Nach
Aktivierung und Rollback startet das Skript den projektspezifisch per sudoers
freigegebenen PHP-FPM-Dienst neu.

## Persistente Daten

Diese Pfade werden von Ansible angelegt und niemals aus Git überschrieben:

```text
/var/www/shopdaten.jonova.de/shared/private/
/var/www/shopdaten.jonova.de/shared/private/csrf.key
/var/www/shopdaten.jonova.de/shared/private/users.json
/var/www/shopdaten.jonova.de/shared/repository/
```

Ansible erzeugt `csrf.key` beim ersten Lauf automatisch und behält denselben
Wert über alle Deployments hinweg. Er schützt angemeldete Benutzer vor
gefälschten Requests und muss weder als Projektvariable noch im Vault gepflegt
werden. Die Anwendungskonfiguration liest diesen Schlüssel zur Laufzeit ein.

Vor dem ersten Deployment wird die vorhandene Benutzerdatei in den
persistenten Bereich übernommen. Ihr Inhalt bleibt dabei unverändert:

```bash
cp /pfad/zum/bisherigen/private/users.json \
  /var/www/shopdaten.jonova.de/shared/private/users.json
chown stl-php:<deployment-gruppe> \
  /var/www/shopdaten.jonova.de/shared/private/users.json
chmod 0640 /var/www/shopdaten.jonova.de/shared/private/users.json
```

`shared/private/logs`, `shared/private/sessions` und `shared/private/tmp`
müssen für den PHP-Runtime-User `stl-php` beschreibbar sein. Der Nginx-
Document-Root zeigt auf `/var/www/shopdaten.jonova.de/live/dist`; `/files/` wird
direkt aus `shared/repository` ausgeliefert.

Der öffentliche Basispfad steht in der Anwendung fest auf `/files`. Beim
Kopieren ergänzt das Frontend automatisch die aktuelle Domain und erzeugt
beispielsweise `https://shopdaten.jonova.de/files/bild.jpg`.

Der sichtbare App-Name wird vom Nginx-Vhost aus dem Ansible-Projektnamen
übergeben. Bei `name: shopdaten.jonova.de` zeigt FileGator daher automatisch
`shopdaten.jonova.de` an; eine zusätzliche App-Name-Variable ist nicht nötig.

## Lizenz

FileGator ist MIT-lizenziert. Upstream: <https://github.com/filegator/filegator>
