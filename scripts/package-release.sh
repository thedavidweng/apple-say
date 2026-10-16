#!/bin/bash
set -euo pipefail

: "${APPLE_SIGNING_IDENTITY:?release signing identity required}"
: "${APPLE_SIGNING_KEYCHAIN:?}" "${APPLE_TEAM_ID:?}"
: "${APPLE_API_KEY_PATH:?}" "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER:?}"

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

echo "==> Building Apple Say.app..."
"$project_root/scripts/build-app.sh"

application="$project_root/build/Apple Say.app"
"$project_root/scripts/sign-and-notarize.sh" "$application"
dist_dir="$project_root/dist"
rm -rf "$dist_dir"
mkdir -p "$dist_dir"

echo "==> Packaging Apple-Say.zip..."
ditto -c -k --keepParent "$application" "$dist_dir/Apple-Say.zip"

echo "==> Packaging Apple-Say.dmg..."
dmg_staging="$project_root/build/dmg_staging"
rm -rf "$dmg_staging"
mkdir -p "$dmg_staging"
cp -R "$application" "$dmg_staging/"
ln -s /Applications "$dmg_staging/Applications"

hdiutil create \
    -volname "Apple Say" \
    -srcfolder "$dmg_staging" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$dist_dir/Apple-Say.dmg"
rm -rf "$dmg_staging"

# Keep legacy Apple-Say-macOS.* release URLs working.
cd "$dist_dir"
ln -s Apple-Say.dmg Apple-Say-macOS.dmg
ln -s Apple-Say.zip Apple-Say-macOS.zip

"$project_root/scripts/sign-and-notarize.sh" "$dist_dir/Apple-Say.dmg"

echo "==> Generating SHA-256 checksums..."
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 Apple-Say.dmg Apple-Say.zip > checksums.txt
elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum Apple-Say.dmg Apple-Say.zip > checksums.txt
fi

echo "==> Packaging complete! Artifacts in $dist_dir:"
ls -lh "$dist_dir"
cat "$dist_dir/checksums.txt"
