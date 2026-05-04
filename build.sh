#!/bin/bash
set -euo pipefail

APP_NAME="MacGameLensTranslator"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_BUNDLE="${PROJECT_DIR}/../${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "=== Building ${APP_NAME} ==="

# Build release binary
swift build -c release --arch arm64

# If arm64 build fails on Intel Mac, try x86_64
if [ $? -ne 0 ]; then
    echo "Trying x86_64 build..."
    swift build -c release --arch x86_64
fi

# Find built binary
BINARY="${BUILD_DIR}/release/${APP_NAME}"
if [ ! -f "$BINARY" ]; then
    BINARY="${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}"
fi

echo "Binary at: ${BINARY}"

# Clean and create app bundle
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp "${BINARY}" "${MACOS_DIR}/${APP_NAME}"

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacGameLensTranslator</string>
    <key>CFBundleIdentifier</key>
    <string>com.macgamelens.translator</string>
    <key>CFBundleName</key>
    <string>Mac Game Lens Translator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Mac Game Lens Translator needs screen capture permission to OCR game text for translation.</string>
</dict>
</plist>
PLISTEOF

# Copy Resources if any
if [ -d "${PROJECT_DIR}/Sources/MacGameLensTranslator/Resources" ]; then
    cp -R "${PROJECT_DIR}/Sources/MacGameLensTranslator/Resources/"* "${RESOURCES_DIR}/" 2>/dev/null || true
fi

# Set executable permissions
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Prefer a stable local signing identity when one is available. Ad-hoc signing works
# for local runs, but macOS privacy permissions may need to be re-granted after rebuilds.
SIGN_IDENTITY="${MGLT_CODESIGN_IDENTITY:-}"
if [ -z "${SIGN_IDENTITY}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '\"' '/[0-9A-F]{40}/ { print $2; exit }' || true)"
fi

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "Signing with identity: ${SIGN_IDENTITY}"
    codesign --force --deep --options runtime --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"
else
    echo "No code signing identity found; using ad-hoc signing."
    codesign --force --deep --sign - "${APP_BUNDLE}"
fi
xattr -dr com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true

echo "=== App bundle created at ${APP_BUNDLE} ==="
echo "Run with: open '${APP_BUNDLE}'"
echo ""
echo "NOTE: First launch may require granting Screen Recording permission in System Settings > Privacy & Security > Screen Recording"
