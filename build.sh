#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

swift build --package-path "$ROOT" --configuration release

BIN_DIR=$(swift build --package-path "$ROOT" --configuration release --show-bin-path)

APP="$ROOT/build/FileTree.app"
STAGING="$ROOT/build/.FileTree.app"
rm -rf "$STAGING"
mkdir -p "$STAGING/Contents/MacOS" "$STAGING/Contents/Resources"
cp "$BIN_DIR/FileTree" "$STAGING/Contents/MacOS/FileTree"
cp "$BIN_DIR/ft" "$STAGING/Contents/MacOS/ft"

cp "$ROOT/Resources/AppIcon.icns" "$STAGING/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/Info.plist" "$STAGING/Contents/Info.plist"
printf 'APPL????' > "$STAGING/Contents/PkgInfo"

rm -rf "$APP"
mv "$STAGING" "$APP"

cat << EOF

==> Build complete!
Outputs generated in $ROOT/build:
  App: $APP
  CLI: $APP/Contents/MacOS/ft

Usage:
  $APP/Contents/MacOS/ft .        (Opens GUI loaded with current directory)
  $APP/Contents/MacOS/ft <path>   (Opens GUI loaded with specified directory)
EOF
