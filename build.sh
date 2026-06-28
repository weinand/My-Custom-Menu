#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="MyCustomMenu"
BUNDLE_NAME="My Custom Menu.app"
BUILD_DIR="${PROJECT_DIR}/.build/release"
DIST_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${BUNDLE_NAME}"
LEGACY_APP_BUNDLE="${PROJECT_DIR}/${APP_NAME}.app"

echo "🔨 Building My Custom Menu..."
cd "${PROJECT_DIR}"
swift build -c release

if [[ ! -x "${BUILD_DIR}/${APP_NAME}" ]]; then
    echo "❌ Expected executable not found: ${BUILD_DIR}/${APP_NAME}"
    exit 1
fi

echo "📦 Creating .app bundle structure..."
mkdir -p "${DIST_DIR}"
rm -rf "${APP_BUNDLE}"
rm -rf "${LEGACY_APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "📋 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "📝 Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MyCustomMenu</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.MyCustomMenu</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>My Custom Menu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.6</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "🔒 Setting permissions..."
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

echo "✍️  Signing app bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Build complete!"
echo "📍 App location: ${APP_BUNDLE}"
echo ""
echo "To run the app, use:"
echo "   open \"${APP_BUNDLE}\""
