#!/bin/bash
# Tahlil.app paketler. Çıktı Finder'dan çift tıklanır; terminal penceresi açılmaz.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift test
swift build -c release --product Tahlil

BIN="$ROOT/.build/release/Tahlil"
APP="$ROOT/dist/Tahlil.app"
ICON_DIR="$ROOT/build/AppIcon.iconset"
PNG="$ROOT/build/AppIcon-1024.png"

rm -rf "$APP" "$ICON_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICON_DIR" "$ROOT/build"

python3 "$ROOT/Scripts/make_icon.py" "$PNG"

declare -a SIZES=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)
for item in "${SIZES[@]}"; do
  size="${item%%:*}"
  name="${item##*:}"
  sips -z "$size" "$size" "$PNG" --out "$ICON_DIR/$name" >/dev/null
done
iconutil -c icns "$ICON_DIR" -o "$APP/Contents/Resources/AppIcon.icns"

cp "$BIN" "$APP/Contents/MacOS/Tahlil"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
chmod +x "$APP/Contents/MacOS/Tahlil"

# Skala JSON'ları: SPM resource bundle + düz Resources/scales
RESOURCE_BUNDLE="$ROOT/.build/release/Tahlil_TahlilCore.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  rm -rf "$APP/Contents/Resources/Tahlil_TahlilCore.bundle"
  cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/"
  mkdir -p "$APP/Contents/Resources/scales"
  cp "$RESOURCE_BUNDLE/Contents/Resources/scales/"*.json "$APP/Contents/Resources/scales/" 2>/dev/null || true
fi

codesign --force --sign - --identifier com.tahlil.okuyucu "$APP/Contents/MacOS/Tahlil"
codesign --force --sign - --identifier com.tahlil.okuyucu "$APP"
codesign --verify --verbose=2 "$APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$APP"
fi

echo "Hazır: $APP"
