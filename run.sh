#!/usr/bin/env bash
# ============================================================
# Antares Launcher 1.0 — chạy trực tiếp từ source (Linux/macOS)
#
# Lần đầu: tự tạo venv + cài dependencies (cần internet).
# Các lần sau: chạy luôn.
#
#   ./run.sh            # GUI (cửa sổ launcher)
#   ./run.sh --headless # không cửa sổ (kiểm tra boot)
#   ./run.sh --dev      # dev mode (verbose log + devtools)
# ============================================================
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

VENV="$DIR/.venv"
PY=python3
command -v "$PY" >/dev/null 2>&1 || PY=python

# 1. Venv
if [ ! -x "$VENV/bin/python" ]; then
  echo "==> [1/2] Tạo môi trường ảo (lần đầu)..."
  "$PY" -m venv "$VENV"
  "$VENV/bin/python" -m pip install --upgrade pip --quiet
  echo "==> Cài dependencies (một lần duy nhất)..."
  "$VENV/bin/python" -m pip install --quiet -r requirements.txt
fi

# 2. Chạy
echo "==> Khởi động Antares Launcher..."
exec "$VENV/bin/python" -m app.main "$@"
