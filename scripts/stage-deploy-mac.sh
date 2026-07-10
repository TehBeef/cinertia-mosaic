#!/bin/bash
# Build, bundle, sign, and package Mosaic for macOS — the Mac counterpart of
# stage-deploy.ps1. Produces dist/Mosaic-<version>.dmg.
#
#   ./scripts/stage-deploy-mac.sh
#
# Steps: CMake Release build → macdeployqt (copies the Qt frameworks + QML
# modules into the .app so it runs on Macs without Qt) → codesign (ad-hoc by
# default; set SIGN_ID to a real "Developer ID Application: …" identity when
# one exists) → hdiutil .dmg with an /Applications shortcut.
#
# Ad-hoc signing is fine for local use and hand-offs to trusted machines;
# other Macs will need right-click → Open the first time (no notarization).
set -euo pipefail

# Build root on the Mac (external drive). Override with MOSAIC_MAC_BASE
# if the folder moves.
BASE="${MOSAIC_MAC_BASE:-/Volumes/Max DeRoin/Dev/NDI Multiviewer - Mac}"
REPO="$BASE/cinertia-mosaic"
QT="$BASE/Qt/6.8.3/macos"
export PATH="$BASE/tools/bin:$PATH"

SIGN_ID="${SIGN_ID:--}"   # "-" = ad-hoc signature

VERSION=$(sed -n 's/^project(Mosaic VERSION \([0-9.]*\).*/\1/p' "$REPO/CMakeLists.txt")
echo "== Mosaic $VERSION — macOS package =="

echo "== 1/5 Build (Release) =="
cmake -S "$REPO" -B "$REPO/build" -DCMAKE_PREFIX_PATH="$QT" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$REPO/build" >/dev/null
APP="$REPO/build/Mosaic.app"

echo "== 2/5 Stage a clean copy =="
STAGE="$REPO/deploy"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
APP="$STAGE/Mosaic.app"

echo "== 3/5 macdeployqt (bundle Qt frameworks + QML) =="
# -appstore-compliant skips Qt's SQL-driver plugins, which reference database
# libraries that don't exist on this machine (harmless ERROR spam otherwise).
"$QT/bin/macdeployqt" "$APP" -qmldir="$REPO/qml" -appstore-compliant 2>&1 | grep -iE "error|warn" || true

echo "== 4/5 Codesign ($SIGN_ID) =="
codesign --force --deep --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP" && echo "signature verifies"

echo "== 5/5 Build .dmg =="
DIST="$REPO/dist"
mkdir -p "$DIST"
DMG="$DIST/Mosaic-$VERSION.dmg"
rm -f "$DMG"
DMGDIR=$(mktemp -d)
cp -R "$APP" "$DMGDIR/"
ln -s /Applications "$DMGDIR/Applications"
hdiutil create -volname "Mosaic $VERSION" -srcfolder "$DMGDIR" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DMGDIR"
echo "Done: $DMG"
