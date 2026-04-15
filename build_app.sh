#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
APP_NAME="蓝牙设备一键断开忽略"
APP_BUNDLE="$ROOT_DIR/dist/${APP_NAME}.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/swiftc \
  "$ROOT_DIR/src/main.swift" \
  -o "$MACOS_DIR/launcher"

/bin/chmod +x "$MACOS_DIR/launcher"
/bin/cp "$ROOT_DIR/resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/bin/cp "$ROOT_DIR/resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

/usr/bin/codesign --force --deep --sign - --identifier local.codex.bluetooth-ignore.selector "$APP_BUNDLE" >/dev/null 2>&1 || true

if [[ -x "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]]; then
  "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

printf 'Built app: %s\n' "$APP_BUNDLE"
