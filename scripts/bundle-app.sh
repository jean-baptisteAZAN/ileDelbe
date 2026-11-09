#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/IleDelbe.app
ADAPTER=Vendor/mediaremote-adapter
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/IleDelbe" "$APP/Contents/MacOS/IleDelbe"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ADAPTER/bin/mediaremote-adapter.pl" "$APP/Contents/Resources/"
cp -R "$ADAPTER/build/MediaRemoteAdapter.framework" "$APP/Contents/Resources/"
codesign --force --deep -s - "$APP"
echo "Built $APP"
