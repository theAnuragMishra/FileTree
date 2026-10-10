#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

BUILD_DIR="build"
mkdir -p "$BUILD_DIR"

echo "==> Compiling native Swift binary..."
swiftc -O -parse-as-library FileTreeApp.swift -o "$BUILD_DIR/FileTree"

echo "==> Creating macOS App bundle..."
APP_DIR="$BUILD_DIR/FileTree.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/FileTree" "$APP_DIR/Contents/MacOS/FileTree"
chmod +x "$APP_DIR/Contents/MacOS/FileTree"

ICON_ENTRY=""
# Look for AppIcon.icns in project root
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    ICON_ENTRY="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>"
fi

cat << EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>FileTree</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.FileTree</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>FileTree</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
$ICON_ENTRY
</dict>
</plist>
EOF

echo "==> Build complete!"
echo "Outputs generated in $BUILD_DIR/:"
echo "  open $BUILD_DIR/FileTree.app"
echo "  or: ./$BUILD_DIR/FileTree"
