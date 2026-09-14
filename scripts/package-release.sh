#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

# 1. Build the app bundle using build-app.sh
echo "==> Building Apple Say.app..."
"$project_root/scripts/build-app.sh"

application="$project_root/build/Apple Say.app"
dist_dir="$project_root/dist"
rm -rf "$dist_dir"
mkdir -p "$dist_dir"

echo "==> Packaging Apple-Say.zip..."
ditto -c -k --sequesterRsrc --keepParent "$application" "$dist_dir/Apple-Say.zip"

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
    "$dist_dir/Apple-Say.dmg"
rm -rf "$dmg_staging"

# Also create symlinks for Apple-Say-macOS.* for backward-compat if needed
cd "$dist_dir"
ln -s Apple-Say.dmg Apple-Say-macOS.dmg
ln -s Apple-Say.zip Apple-Say-macOS.zip

echo "==> Generating SHA-256 checksums..."
if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 Apple-Say.dmg Apple-Say.zip > checksums.txt
elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum Apple-Say.dmg Apple-Say.zip > checksums.txt
fi

echo "==> Packaging complete! Artifacts in $dist_dir:"
ls -lh "$dist_dir"
cat "$dist_dir/checksums.txt"
