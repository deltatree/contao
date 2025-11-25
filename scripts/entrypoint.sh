#!/usr/bin/env bash
set -euo pipefail

APP_DIR=${APP_DIR:-/var/www/html}
PLACEHOLDER=${APP_PLACEHOLDER:-$APP_DIR/.gitkeep}
CONTAO_CONSOLE="$APP_DIR/vendor/bin/contao-console"
INSTALLER=${CONTAO_INSTALLER_BIN:-/usr/local/bin/install-contao}

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
  else
    echo "[entrypoint] No Contao console found at $CONTAO_CONSOLE (skipping contao:install)"
  fi
fi

# Recalculate path after potential install
if [[ -x "$CONTAO_CONSOLE" ]]; then
  echo "[entrypoint] Running initial Contao setup via contao:install"
  php "$CONTAO_CONSOLE" contao:install
else
  echo "[entrypoint] Still no Contao console present – continuing without running contao:install"
fi
if [[ -x "$CONTAO_CONSOLE" ]]; then
  echo "[entrypoint] Running initial Contao setup via contao:install"
  php "$CONTAO_CONSOLE" contao:install
else
  echo "[entrypoint] No Contao console found at $CONTAO_CONSOLE (skipping contao:install)"
fi

echo "[entrypoint] Starting main process: $*"
exec "$@"
