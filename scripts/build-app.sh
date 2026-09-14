#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build --configuration release
binary_directory="$(swift build --configuration release --show-bin-path)"
application="$project_root/build/Apple Say.app"
rm -rf "$application"
mkdir -p "$application/Contents/MacOS" "$application/Contents/Resources"
cp "$binary_directory/AppleSay" "$application/Contents/MacOS/AppleSay"
cp "$project_root/Resources/Info.plist" "$application/Contents/Info.plist"
xcrun actool \
    --compile "$application/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --target-device mac \
    --app-icon AppIcon \
    --output-partial-info-plist "$application/Contents/icon-info.plist" \
    "$project_root/Resources/AppIcon.icon"
/usr/libexec/PlistBuddy -c "Merge '$application/Contents/icon-info.plist'" "$application/Contents/Info.plist"
rm "$application/Contents/icon-info.plist"
cp "$project_root/Resources/Credits.html" "$application/Contents/Resources/Credits.html"
for localization in "$project_root"/Resources/*.lproj; do
    ditto "$localization" "$application/Contents/Resources/$(basename "$localization")"
done
codesign --force --sign - "$application"
printf '%s\n' "$application"
