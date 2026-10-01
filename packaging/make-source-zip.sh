#!/usr/bin/env bash
# ============================================================
# Antares Launcher 1.0 — đóng gói ZIP "source-runnable"
#
# Gói chứa source sạch + run.sh/run.bat: giải nén -> ./run.sh (hoặc run.bat
# trên Windows) -> tự tạo venv + cài deps + mở launcher. Không cần PyInstaller.
#
#   ./packaging/make-source-zip.sh            # -> dist/Antares-1.0.0-source.zip
# ============================================================
set -euo pipefail
VERSION="$(python3 - <<'EOF'
import re
print(re.search(r'APP_VERSION\s*=\s*"([^"]+)"', open('app/version.py').read()).group(1))
EOF
)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"
OUT="$ROOT/dist/Antares-$VERSION-source.zip"

mkdir -p "$ROOT/dist"
cd "$ROOT"

# Copy toàn bộ trừ build artifacts / cache / venv / dist
rsync -a --delete \
  --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.venv' --exclude='.pytest_cache' --exclude='build' \
  --exclude='dist' --exclude='.ruff_cache' --exclude='*.egg-info' \
  ./ "$STAGE/Antares/"

# Marker chạy được + hướng dẫn ngắn ở root gói
cat > "$STAGE/Antares/RUN-ME.txt" <<EOF
Antares Launcher $VERSION — gói chạy trực tiếp từ source
=========================================================
WINDOWS : double-click run.bat        (cần Python 3.11+: python.org)
Linux   : ./run.sh                    (cần python3 + venv module)
macOS   : ./run.sh

Lần đầu chạy: script tự tạo môi trường ảo + tải dependencies (cần internet,
~1-2 phút). Các lần sau khởi động ngay.

Tùy chọn: run.bat --dev | --headless | --safe-mode | --diagnose
Chi tiết: README.md + docs/
EOF

( cd "$STAGE" && zip -qr "$OUT" Antares )
rm -rf "$STAGE"
echo "==> Done: $OUT ($(du -h "$OUT" | cut -f1))"
 