#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' TextCleaner.xcodeproj/project.pbxproj | head -1)
if [ -z "$VERSION" ]; then
    echo "Could not read MARKETING_VERSION from project.pbxproj" >&2
    exit 1
fi

xcodebuild -scheme TextCleaner -configuration Release -derivedDataPath .build/DerivedData -quiet build

APP=".build/DerivedData/Build/Products/Release/TextCleaner.app"
if [ ! -d "$APP" ]; then
    echo "Missing built app at $APP" >&2
    exit 1
fi

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

FOLDER="$STAGE/TextCleaner-$VERSION"
mkdir -p "$FOLDER"
ditto "$APP" "$FOLDER/TextCleaner.app"

cat > "$FOLDER/INSTALL.txt" <<EOF
TextCleaner $VERSION

To install:
1. Open TextCleaner-$VERSION.dmg or unzip TextCleaner-$VERSION.zip.
2. Drag TextCleaner.app to your Applications folder.
3. Launch TextCleaner from Applications.

If macOS warns that the app was downloaded from the internet, open it from Finder with Control-click > Open.
EOF

mkdir -p release
rm -f "release/TextCleaner-$VERSION.dmg" "release/TextCleaner-$VERSION.zip"
hdiutil create -volname "TextCleaner $VERSION" -srcfolder "$FOLDER" -ov -format UDZO "release/TextCleaner-$VERSION.dmg"
ditto -c -k --keepParent "$FOLDER" "release/TextCleaner-$VERSION.zip"

echo "Built release/TextCleaner-$VERSION.dmg and release/TextCleaner-$VERSION.zip"
