#!/bin/bash
set -euo pipefail
if [ "$#" -lt 2 ]; then
  printf '%s\\n' 'Uso: check-connectivity.sh DB_PRIVATE_IP http://HOST:PUERTO/RUTA [http://HOST:PUERTO/RUTA ...]'
  exit 2
fi
if ! command -v curl >/dev/null 2>&1; then
  printf '%s\\n' 'Se requiere curl para comprobar las respuestas HTTP.'
  exit 2
fi
DB_HOST="$1"
shift
if ! timeout 5 bash -c "echo > /dev/tcp/$DB_HOST/3306" >/dev/null 2>&1; then
  printf 'Fallo TCP: %s:3306\\n' "$DB_HOST"
  exit 1
fi
printf 'MySQL disponible: %s:3306\\n' "$DB_HOST"
for url in "$@"; do
  code="$(curl --connect-timeout 5 --max-time 10 -sS -o /dev/null -w '%{http_code}' "$url" || true)"
  if [ -z "$code" ] || [ "$code" = "000" ] || [ "$code" -ge 500 ]; then
    printf 'Fallo HTTP: %s (estado %s)\\n' "$url" "${code:-sin respuesta}"
    exit 1
  fi
  printf 'HTTP disponible: %s (estado %s)\\n' "$url" "$code"
done
