#!/bin/bash
set -e

# Build release script for Blink Launcher
# Creates a signed zip file ready for GitHub Releases

VERSION="${1:-1.0.0}"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/Blink.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
ZIP_NAME="Blink.zip"

echo "Building Blink Launcher v$VERSION..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build release archive
xcodebuild -scheme Blink \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive

# Export the app
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist scripts/ExportOptions.plist

# Create zip
cd "$EXPORT_PATH"
zip -r "../$ZIP_NAME" Blink.app
cd -

# Calculate SHA256
echo ""
echo "=========================================="
echo "Release artifact: $BUILD_DIR/$ZIP_NAME"
echo "SHA256:"
shasum -a 256 "$BUILD_DIR/$ZIP_NAME" | awk '{print $1}'
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create a GitHub release tagged 'v$VERSION'"
echo "2. Upload $BUILD_DIR/$ZIP_NAME to the release"
echo "3. Update homebrew-blink/Casks/blink-launcher.rb with the SHA256"
