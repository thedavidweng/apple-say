#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
swift build --configuration release
binary_directory="$(swift build --configuration release --show-bin-path)"
application="$project_root/build/Apple Say.app"
mkdir -p "$application/Contents/MacOS" "$application/Contents/Resources"
cp "$binary_directory/AppleSay" "$application/Contents/MacOS/AppleSay"
cp "$project_root/Resources/Info.plist" "$application/Contents/Info.plist"
codesign --force --sign - "$application"
printf '%s\n' "$application"
