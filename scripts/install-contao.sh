#!/usr/bin/env bash
set -euo pipefail

version="${CONTAO_VERSION:-4.9.*}"
project="${CONTAO_PACKAGE:-contao/managed-edition}"

if [[ ! -d /var/www/html ]]; then
  echo "error: /var/www/html not mounted" >&2
  exit 1
fi

if [[ -n $(ls -A /var/www/html 2>/dev/null) ]]; then
  echo "error: target directory /var/www/html must be empty" >&2
  exit 1
fi

# Composer 2.2.x kompatibel (keine --no-audit oder --no-security-blocking Optionen)
exec composer create-project "${project}:${version}" ./
