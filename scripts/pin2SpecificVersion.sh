#!/usr/bin/env bash
set -e

TARGET=4.9.18

# Allow required Composer plugins for Contao
composer config allow-plugins.contao-components/installer true --no-interaction
composer config allow-plugins.contao-community-alliance/composer-plugin true --no-interaction
composer config allow-plugins.php-http/discovery true --no-interaction
composer config allow-plugins.contao/manager-plugin true --no-interaction

# Alle Contao-Pakete aus composer.lock holen
PKGS=$(composer show --locked 'contao/*' | awk '{print $1}')

# Nur Bundles & managed-edition auf TARGET-Version pinnen
# (manager-plugin wird NICHT gepinnt - Composer wählt die kompatible Version)
for pkg in $PKGS; do
  if [[ "$pkg" =~ bundle$ ]] || [[ "$pkg" == "contao/managed-edition" ]]; then
    echo "Pinne $pkg auf $TARGET"
    composer require "${pkg}:${TARGET}" --no-update
  else
    echo "Überspringe $pkg (Library)"
  fi
done

# Dependencies neu auflösen, aber ohne Composer-Skripte
composer update 'contao/*' -W --no-scripts
