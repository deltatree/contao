#!/usr/bin/env bash
set -e

TARGET=4.9.18
MANAGER_PLUGIN_VERSION=2.11.3

# Security-Blocker für unsichere Versionen deaktivieren
composer config audit.block-insecure false

# Alle Contao-Pakete aus composer.lock holen
PKGS=$(composer show --locked 'contao/*' | awk '{print $1}')

# Nur Bundles & managed-edition auf TARGET-Version pinnen
for pkg in $PKGS; do
  if [[ "$pkg" =~ bundle$ ]] || [[ "$pkg" == "contao/managed-edition" ]]; then
    echo "Pinne $pkg auf $TARGET"
    composer require "${pkg}:${TARGET}" --no-update
  else
    echo "Überspringe $pkg (Library)"
  fi
done

echo "Pinne contao/manager-plugin auf $MANAGER_PLUGIN_VERSION"
composer require "contao/manager-plugin:${MANAGER_PLUGIN_VERSION}" --no-update

# Dependencies neu auflösen, aber ohne Composer-Skripte
composer update 'contao/*' -W --no-scripts
