#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_dir"
go build -o bin/portato ./cmd/portato
cd "$repo_dir/macos"
swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
app_dir="${PORTATO_APP_DIR:-$repo_dir/dist/Portato Menu Bar.app}"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp -X "$binary_dir/PortatoMenuBar" "$app_dir/Contents/MacOS/PortatoMenuBar"
cp -X "$repo_dir/bin/portato" "$app_dir/Contents/Resources/portato"
icon_dir=$(mktemp -d /tmp/portato-icon.XXXXXX)
trap 'rm -rf "$icon_dir"' EXIT
swift "$repo_dir/macos/scripts/create-icon.swift" "$icon_dir/Portato.iconset" "$repo_dir/logo.svg"
iconutil -c icns "$icon_dir/Portato.iconset" -o "$app_dir/Contents/Resources/Portato.icns"
cp -X "$repo_dir/logo.svg" "$app_dir/Contents/Resources/logo.svg"
cp -X "$repo_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PortatoMenuBar</string>
<key>CFBundleIdentifier</key><string>dev.portato.menubar</string>
<key>CFBundleIconFile</key><string>Portato</string>
<key>CFBundleName</key><string>Portato Menu Bar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSLocalNetworkUsageDescription</key><string>Connect to your SSH servers on the local network to forward development ports.</string>
<key>NSAppleEventsUsageDescription</key><string>Open Portato's terminal interface and daemon setup in Terminal.</string>
</dict></plist>
PLIST
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir/Contents/Resources/portato"
codesign --force --sign - "$app_dir"
printf '%s\n' "$app_dir"
