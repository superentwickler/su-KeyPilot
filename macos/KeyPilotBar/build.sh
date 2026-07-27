#!/usr/bin/env bash
# Builds KeyPilotBar.app into ./dist. Needs the Xcode command line tools (swift).
# Usage: ./build.sh [--debug] [--install] [--run]
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=release
INSTALL=0
RUN=0
for arg in "$@"; do
  case "$arg" in
    --debug)   CONFIG=debug ;;
    --install) INSTALL=1 ;;
    --run)     RUN=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP_NAME="KeyPilotBar"
BUNDLE="dist/${APP_NAME}.app"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"
BINARY="$(swift build -c "$CONFIG" --show-bin-path)/${APP_NAME}"

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"

# Ad-hoc signature so the keychain can tie the stored master key to this app.
codesign --force --sign - --timestamp=none "$BUNDLE" >/dev/null 2>&1 \
  && echo "==> Signed (ad-hoc)" \
  || echo "==> Warning: codesign failed – the app still runs, but macOS may ask for keychain access more often."

if [ "$INSTALL" = "1" ]; then
  echo "==> Installing to /Applications"
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "$BUNDLE" /Applications/
  echo "    /Applications/${APP_NAME}.app"
fi

if [ "$RUN" = "1" ]; then
  TARGET="$BUNDLE"
  [ "$INSTALL" = "1" ] && TARGET="/Applications/${APP_NAME}.app"
  pkill -x "$APP_NAME" 2>/dev/null || true
  open "$TARGET"
  echo "==> Started – look for the key icon in the menu bar."
else
  echo "==> Done: $BUNDLE"
  echo "    Start with: open \"$BUNDLE\""
fi
