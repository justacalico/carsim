#!/usr/bin/env bash
# Wrap a Flutter Linux bundle as an AppImage using appimagetool.
#
# Usage: build-appimage.sh <bundle-dir> <version> <out-arch> <output-file>
set -euo pipefail

BUNDLE_DIR="${1:?usage: build-appimage.sh <bundle-dir> <version> <arch> <output>}"
VERSION="${2:?usage}"
ARCH="${3:?usage}"   # x86_64 or arm64
OUT="${4:?usage}"

APPIMAGE_ARCH="$ARCH"
[ "$ARCH" = "arm64" ] && APPIMAGE_ARCH="aarch64"

APPDIR="$(mktemp -d)/carsim.AppDir"
trap 'rm -rf "$(dirname "$APPDIR")"' EXIT
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/icons/hicolor/512x512/apps" "$APPDIR/usr/share/applications"

cp -r "$BUNDLE_DIR/." "$APPDIR/usr/bin/"
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
exec "$(dirname "$0")/usr/bin/carsim" "$@"
EOF
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/carsim.desktop" <<'EOF'
[Desktop Entry]
Name=carsim
Exec=carsim
Type=Application
Icon=carsim
Categories=Game;Simulation;
EOF
cp "$APPDIR/carsim.desktop" "$APPDIR/usr/share/applications/"

ICON="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/linux/carsim.png"
cp "$ICON" "$APPDIR/carsim.png" 2>/dev/null || true
cp "$ICON" "$APPDIR/usr/share/icons/hicolor/512x512/apps/carsim.png" 2>/dev/null || true

TOOL="$(mktemp -d)/appimagetool"
curl -fsSL --retry 3 -o "$TOOL" \
  "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage"
chmod +x "$TOOL"

ARCH="$APPIMAGE_ARCH" "$TOOL" "$APPDIR" "$OUT"
echo "AppImage written to $OUT"
