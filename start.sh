#!/usr/bin/env sh
# Antares Launcher - portable (can Python 3.11+)
command -v python3 >/dev/null || { echo "python3 not found"; exit 1; }
cd "$(dirname "$0")"
exec python3 -m app.main "$@"
