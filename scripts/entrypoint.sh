#!/usr/bin/env bash
# Don't use -e so the container keeps running even if setup fails
set -uo pipefail

APP_DIR=${APP_DIR:-/var/www/html}
PLACEHOLDER=${APP_PLACEHOLDER:-$APP_DIR/.gitkeep}
CONTAO_CONSOLE="$APP_DIR/vendor/bin/contao-console"
INSTALLER=${CONTAO_INSTALLER_BIN:-/usr/local/bin/install-contao}
PIN_SCRIPT=${CONTAO_PIN_BIN:-/usr/local/bin/pin-contao-version}

has_app_content() {
  find "$APP_DIR" -mindepth 1 \
    -not -path "$PLACEHOLDER" \
    -print -quit 2>/dev/null | grep -q .
}

cleanup_placeholder() {
  if [[ ! -d "$APP_DIR" ]]; then
    return
  fi

  if ! has_app_content; then
    touch "$PLACEHOLDER"
    echo "[entrypoint] Recreated placeholder $PLACEHOLDER so git keeps the directory"
  fi
}

trap cleanup_placeholder EXIT

if [[ -f "$PLACEHOLDER" ]]; then
  echo "[entrypoint] Removing placeholder $PLACEHOLDER before installation"
  rm -f "$PLACEHOLDER"
fi

if [[ ! -x "$CONTAO_CONSOLE" ]]; then
  if ! has_app_content && [[ -x "$INSTALLER" ]]; then
    echo "[entrypoint] No Contao installation detected – running install-contao"
    "$INSTALLER"
    
    # Configure Composer plugins for Contao (required for Composer 2.2+)
    echo "[entrypoint] Configuring Composer plugins"
    (
      cd "$APP_DIR"
      composer config allow-plugins.contao-components/installer true --no-interaction
      composer config allow-plugins.contao-community-alliance/composer-plugin true --no-interaction
      composer config allow-plugins.php-http/discovery true --no-interaction
      composer config allow-plugins.contao/manager-plugin true --no-interaction
    )
    
    # Add additional packages after initial installation
    echo "[entrypoint] Adding additional Contao packages"
    (
      cd "$APP_DIR"
      composer require --no-update \
        "christianbarkowsky/contao-tiny-compress-images:^1.0" \
        "terminal42/notification_center:^1.5"
      composer update
    )
    echo "[entrypoint] Additional packages installed"
    
    if [[ -x "$PIN_SCRIPT" ]]; then
      echo "[entrypoint] Pinning Contao dependencies via $PIN_SCRIPT"
      (
        cd "$APP_DIR"
        "$PIN_SCRIPT"
      )
      echo "[entrypoint] Pinning completed"
    else
      echo "[entrypoint] Pin script $PIN_SCRIPT not found or not executable" >&2
      exit 1
    fi
  else
    echo "[entrypoint] No Contao console found at $CONTAO_CONSOLE (skipping contao:install)"
  fi
fi

# Fix permissions for entire app directory - must be writable by www-data
echo "[entrypoint] Fixing permissions on $APP_DIR"
chown -R www-data:www-data "$APP_DIR"
chmod -R 775 "$APP_DIR"

# Clear cache completely to avoid stale container issues
echo "[entrypoint] Clearing cache completely"
rm -rf "$APP_DIR/var/cache"
mkdir -p "$APP_DIR/var/cache"
chown www-data:www-data "$APP_DIR/var/cache"
chmod 775 "$APP_DIR/var/cache"

# Ensure .env.local has TRUSTED_PROXIES for reverse proxy support (Ingress/Load Balancer)
if [[ -f "$APP_DIR/.env.local" ]]; then
  if ! grep -q "TRUSTED_PROXIES" "$APP_DIR/.env.local"; then
    echo "[entrypoint] Adding TRUSTED_PROXIES to .env.local"
    echo "TRUSTED_PROXIES=REMOTE_ADDR" >> "$APP_DIR/.env.local"
  fi
else
  echo "[entrypoint] Creating .env.local with TRUSTED_PROXIES"
  echo "TRUSTED_PROXIES=REMOTE_ADDR" > "$APP_DIR/.env.local"
fi

# Run composer install to ensure dependencies and autoloader are up to date
echo "[entrypoint] Running composer install"
(
  cd "$APP_DIR"
  # Ensure Composer plugins are allowed for Contao
  if [[ -f "composer.json" ]]; then
    composer config allow-plugins.contao-components/installer true --no-interaction 2>/dev/null || true
    composer config allow-plugins.contao-community-alliance/composer-plugin true --no-interaction 2>/dev/null || true
    composer config allow-plugins.php-http/discovery true --no-interaction 2>/dev/null || true
    composer config allow-plugins.contao/manager-plugin true --no-interaction 2>/dev/null || true
  fi
  composer install --no-dev --optimize-autoloader || echo "[entrypoint] WARNING: composer install failed"
)

# Warm up the cache before running contao:install
if [[ -x "$CONTAO_CONSOLE" ]]; then
  echo "[entrypoint] Warming up cache"
  php "$CONTAO_CONSOLE" cache:warmup --env=prod || echo "[entrypoint] WARNING: cache:warmup failed, continuing anyway"
fi

# Recalculate path after potential install
if [[ -x "$CONTAO_CONSOLE" ]]; then
  echo "[entrypoint] Running initial Contao setup via contao:install"
  php "$CONTAO_CONSOLE" contao:install || echo "[entrypoint] WARNING: contao:install failed, continuing anyway"
else
  echo "[entrypoint] Still no Contao console present – continuing without running contao:install"
fi

# Fix permissions again after all cache/install operations
echo "[entrypoint] Final permission fix on $APP_DIR/var"
chown -R www-data:www-data "$APP_DIR/var"
chmod -R 775 "$APP_DIR/var"

echo "[entrypoint] Starting main process: $*"
exec "$@"
