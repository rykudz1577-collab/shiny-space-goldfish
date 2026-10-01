#!/usr/bin/env bash
# Antares 3.0 — portable build cho Linux/macOS (spec 3.0 mục 65).
# Yêu cầu: pip install -r requirements.txt pyinstaller
# Output: dist/Antares-1.0.0-portable-<os>.zip
set -euo pipefail

VERSION="1.0.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OS_TAG="$(uname -s | tr '[:upper:]' '[:lower:]')"

cd "$ROOT"
echo "==> Build Antares $VERSION ($OS_TAG)"
python -m PyInstaller packaging/antares.spec --noconfirm --clean

DIST="$ROOT/dist/Antares"
[ -d "$DIST" ] || { echo "dist/Antares not found"; exit 1; }

echo "==> Portable markers"
touch "$DIST/portable.flag"          # bật portable mode (data cạnh exe)

cat > "$DIST/start.sh" <<'EOF'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/Antares/Antares" &      # onedir: binary nằm trong thư mục Antares
EOF
chmod +x "$DIST/start.sh"
cp "$ROOT/README-PORTABLE.md" "$DIST/README-PORTABLE.md"

ZIP="$ROOT/dist/Antares-$VERSION-portable-$OS_TAG.zip"
( cd "$DIST/.." && zip -qr "$ZIP" "$(basename "$DIST")" )

echo "==> Done: $ZIP"
