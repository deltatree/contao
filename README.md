# Contao Docker Environment

This setup provides a reproducible Contao-ready PHP environment that follows the official system requirements from https://docs.contao.org/4.x/manual/en/installation/system-requirements/. The actual Contao project files live in the `app/` directory so that Docker assets stay separate and the installation directory starts empty.

## Stack Overview

- **Web/PHP**: custom image based on `php:7.4-apache` (matching Contao 4.9’s PHP requirement) with required PHP extensions (DOM, Intl, PDO, ZLIB, JSON, cURL, Mbstring, GD, Imagick, Fileinfo, Sodium, Opcache, etc.) and `mod_rewrite` enabled. Default document root points to `web/`, which is the public directory for Contao 4.9; switch `APACHE_DOCUMENT_ROOT` to `/var/www/html/public` if you install a newer Contao release that uses `public/`.
- **Database**: `mariadb:10.11` configured for `utf8mb4`, `InnoDB`, and strict SQL mode defaults compatible with Contao.
- **Composer**: bundled inside the web container to install Contao via Composer or the Contao Manager.
- **PHP settings**: overrides (`docker/php/php.ini`) to match the recommended memory, upload, execution, and opcache limits from the Contao documentation.
- **App separation**: host source code sits under `app/` and is the only directory bind-mounted into the container, keeping infrastructure files out of the Contao docroot.

## Prerequisites

- Docker Engine + Docker Compose Plugin (or Docker Desktop) on your host machine.
- `app/` folder must remain empty before the first start (committed `.gitkeep` keeps the directory in git).
- Beim Containerstart entfernt der Entry-Point die `.gitkeep`, führt – falls noch keine Installation vorhanden ist – automatisch `install-contao` aus, pinnt alle Contao-Pakete auf 4.9.18 (inkl. `contao/manager-plugin:2.11.3`) und ruft danach `contao:install` auf. Beim Stoppen wird `.gitkeep` nur dann zurückgeschrieben, wenn der Ordner leer geblieben ist.

## Quick Start

1. **Build & start**
   ```sh
   docker compose up -d --build
   ```
2. **Initial Contao installation** – happens automatically on the first `docker compose up` as long as `app/` is empty. The entrypoint runs `install-contao`, pins every `contao/*` bundle (plus `contao/manager-plugin:2.11.3`) to `4.9.18`, executes `composer update 'contao/*' -W --no-scripts`, and finally calls `vendor/bin/contao-console contao:install` to wire up directories. If you need to rerun the installer manually, you can still call:
   ```sh
   docker compose exec contao install-contao
   ```
   Override the target version via `CONTAO_VERSION`, e.g. `CONTAO_VERSION="5.6.*" docker compose exec contao install-contao`. When switching to Contao 5.x update the `Dockerfile` to PHP 8.x and drop the legacy Composer flags.

   > ℹ️ Beim Container-Start führt das neue Entry-Point-Skript automatisch `vendor/bin/contao-console contao:install` aus, sobald die Contao-Konsole im `app/`-Verzeichnis vorhanden ist. So werden notwendige Verzeichnisse direkt angelegt.
   After the dependencies are installed, Contao’s public entry point will be in `public/` (or `web/` for older releases). The Apache virtual host already points to `public/`.
3. **Run the install tool / Contao Manager**
   - Install tool: visit `http://localhost:8080/contao/install`.
   - Contao Manager: download `contao-manager.phar.php` into the project root and open `http://localhost:8080/contao-manager.phar.php`.

## Database Access

Default credentials (configure `.env`/secrets as needed):

| Key | Value |
| --- | --- |
| Host | `db` (inside the network) / `localhost:3306` via port mapping |
| Database | `contao` |
| User | `contao` |
| Password | `contao` |
| Root password | `contao_root` |

To obtain a SQL shell:
```sh
docker compose exec db mariadb -u contao -pcontao contao
```

## Customizing PHP & Apache

- Tune PHP directives in `docker/php/php.ini` (memory limit, upload sizes, opcache, etc.). Containers reload these settings on start.
- Additional Apache modules or vhost tweaks can be added in the `Dockerfile` if required.

## File Persistence

- Project files live on the host under `app/` (bind mount `./app:/var/www/html`).
- Database state persists in the named volume `db_data`.

## Common Commands

```sh
# Follow logs
docker compose logs -f contao

# Run Contao console
docker compose exec contao vendor/bin/contao-console cache:clear

# Stop and remove the stack
docker compose down -v
```

## Resetting a Backend Password

If the Contao login UI cannot be used (e.g., after a fresh install), you can reset a backend user password from the host:

```sh
docker compose exec contao php vendor/bin/contao-console contao:user:password <username> \
   --password "NeuesPasswort123" [--require-change]
```

`--require-change` erzwingt eine Passwortänderung beim nächsten Login. The hash is stored in `tl_user`; no additional DB steps are necessary.

## Publishing the Docker Image via GitHub Actions

The workflow `.github/workflows/publish.yml` builds the image and pushes it to `ghcr.io/<owner>/<repo>` whenever a tag matching `v00.00.00` (SemVer style with leading `v`) is pushed. Two tags are published per release: the full `vX.Y.Z` and the `X.Y` shorthand. Ensure GitHub Packages is enabled for the repository so the built image is available to your deployments.

## Next Steps

- Adjust environment variables / secrets before deploying beyond local development.
- Consider using a production-grade web server (Nginx + PHP-FPM) or CDN when hosting publicly.
- Harden the image (non-root Apache, read-only FS) to meet your organization’s security guidelines.
