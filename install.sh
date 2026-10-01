#!/usr/bin/env bash
# Antares Launcher - cai dat + chay (tu source)
set -e
cd "$(dirname "$0")"
PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null || { echo "[LOI] Khong tim thay python3"; exit 1; }
"$PY" --version
"$PY" -m pip install --quiet --user "minecraft-launcher-lib>=8.0" "httpx>=0.27"     "psutil>=5.9" "pywebview>=5.0"
"$PY" -m app.main --diagnose
exec "$PY" -m app.main "$@"
