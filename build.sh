#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
build_dir="$PWD/build"
app="$build_dir/Welcome Jay.app"
contents="$app/Contents"

mkdir -p "$contents/MacOS" "$contents/Resources"
cp Info.plist "$contents/Info.plist"
cp WelcomeJay.icns "$contents/Resources/WelcomeJay.icns"

xcrun swiftc -swift-version 5 -O -target arm64-apple-macos13.0 \
    -module-cache-path "$build_dir/ModuleCache" \
    Scene.swift WelcomeApp.swift -o "$contents/MacOS/WelcomeJay"

xattr -cr "$app"
codesign --force --sign - "$app"
printf '%s\n' "$app"
