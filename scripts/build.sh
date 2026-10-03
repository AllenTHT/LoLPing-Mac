#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/module-cache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build -c release --product LoLPing --disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security"
APP="$PWD/dist/LoLPing.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LoLPing "$APP/Contents/MacOS/LoLPing"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Artwork Resources/Icons Resources/Sounds "$APP/Contents/Resources/"
cp Resources/asset-sources.json "$APP/Contents/Resources/"
if [[ ! -f "$APP/Contents/Resources/AppIcon.icns" || scripts/make_icon.swift -nt "$APP/Contents/Resources/AppIcon.icns" ]]; then
    swift scripts/make_icon.swift "$PWD/.build/AppIcon.iconset"
    iconutil -c icns .build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - --identifier local.allentu.LoLPing "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/LoLPing" --check-assets
print "Built: $APP"
