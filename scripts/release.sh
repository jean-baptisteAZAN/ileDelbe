#!/bin/bash
# Builds a release zip of ileDelbe: build/ileDelbe-<version>.zip
#
# Optional environment:
#   DEVELOPER_ID_APP  Signing identity, e.g. "Developer ID Application: Jane Doe (TEAMID)".
#                     Without it the app is signed ad hoc and will NOT pass Gatekeeper.
#   NOTARY_PROFILE    notarytool keychain profile (e.g. "ileDelbe", created with
#                     `xcrun notarytool store-credentials ileDelbe`). Requires DEVELOPER_ID_APP.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/IleDelbe.app
FRAMEWORK="$APP/Contents/Resources/MediaRemoteAdapter.framework"
ENTITLEMENTS=Resources/IleDelbe.entitlements
DEVELOPER_ID_APP="${DEVELOPER_ID_APP:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

die() { echo "error: $*" >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)" \
  || die "could not read CFBundleShortVersionString from Resources/Info.plist"
ZIP="build/ileDelbe-$VERSION.zip"

if [[ -n "$NOTARY_PROFILE" && -z "$DEVELOPER_ID_APP" ]]; then
  die "NOTARY_PROFILE is set but DEVELOPER_ID_APP is not: notarization needs a Developer ID signature"
fi
[[ -f Vendor/mediaremote-adapter/CMakeLists.txt ]] \
  || die "submodule missing: run 'git submodule update --init'"

echo "==> Building ileDelbe $VERSION"
scripts/build-adapter.sh
scripts/bundle-app.sh  # release build, bundle, ad-hoc signature (replaced below if signing)

if [[ -n "$DEVELOPER_ID_APP" ]]; then
  echo "==> Signing with: $DEVELOPER_ID_APP"
  # Inside-out: nested code first, then the app.
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APP" "$FRAMEWORK"
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID_APP" "$APP"
else
  echo "==> Signing ad hoc"
  codesign --force --sign - "$FRAMEWORK"
  codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP"
  cat >&2 <<'EOF'

  WARNING: DEVELOPER_ID_APP is not set, so this build is signed ad hoc.
  It will NOT pass Gatekeeper on other Macs (users would have to remove the
  quarantine attribute by hand). Do not publish it as an official release.

EOF
fi

codesign --verify --deep --strict "$APP" || die "signature verification failed"

rm -f "$ZIP"
ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "==> Notarizing with keychain profile: $NOTARY_PROFILE"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait \
    || die "notarization failed (see: xcrun notarytool log <id> --keychain-profile \"$NOTARY_PROFILE\")"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm -f "$ZIP"
  ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
else
  echo "==> Skipping notarization (NOTARY_PROFILE not set)"
fi

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

echo
echo "Artifact: $ZIP"
echo "SHA-256:  $SHA256"
echo
echo "Ready-to-paste Casks/iledelbe.rb (jean-baptisteAZAN/homebrew-tap):"
echo
sed -e "s/^  version \".*\"/  version \"$VERSION\"/" \
    -e "s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" \
    packaging/homebrew/iledelbe.rb
