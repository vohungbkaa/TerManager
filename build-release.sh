#!/bin/bash
set -euo pipefail

APP_NAME="Terminal Manager"
BINARY_NAME="TerminalGridApp"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

# ── parse flags ──
LIPO=false
case "${1:-}" in
    universal) LIPO=true ;;
esac

echo "==> Cleaning previous artifacts..."
rm -rf "${APP_BUNDLE}" "${APP_NAME}.zip"

if $LIPO; then
    echo "==> Building arm64..."
    swift build -c release --arch arm64 -Xlinker -headerpad_max_install_names 2>&1 | tail -1
    cp "${BUILD_DIR}/${BINARY_NAME}" "${BUILD_DIR}/${BINARY_NAME}-arm64"

    echo "==> Building x86_64..."
    swift build -c release --arch x86_64 -Xlinker -headerpad_max_install_names 2>&1 | tail -1
    cp "${BUILD_DIR}/${BINARY_NAME}" "${BUILD_DIR}/${BINARY_NAME}-x86_64"

    echo "==> Lipo into universal binary..."
    lipo -create \
        "${BUILD_DIR}/${BINARY_NAME}-arm64" \
        "${BUILD_DIR}/${BINARY_NAME}-x86_64" \
        -output "${BUILD_DIR}/${BINARY_NAME}"
    rm "${BUILD_DIR}/${BINARY_NAME}-arm64" "${BUILD_DIR}/${BINARY_NAME}-x86_64"
else
    echo "==> Building release (current architecture)..."
    swift build -c release -Xlinker -headerpad_max_install_names 2>&1 | tail -1
fi

echo "==> Creating .app bundle..."
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BUILD_DIR}/${BINARY_NAME}" "${MACOS_DIR}/"

echo "==> Writing Info.plist..."
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Terminal Manager</string>
    <key>CFBundleDisplayName</key>
    <string>Terminal Manager</string>
    <key>CFBundleIdentifier</key>
    <string>com.termanager.terminalgrid</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>TerminalGridApp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_BUNDLE}" 2>&1

echo "==> Verifying..."
codesign --verify --verbose=1 "${APP_BUNDLE}" 2>&1

echo "==> Creating zip..."
zip -rq "${APP_NAME}.zip" "${APP_BUNDLE}"

BINARY_SIZE=$(du -sh "${MACOS_DIR}/${BINARY_NAME}" | cut -f1)
ZIP_SIZE=$(du -sh "${APP_NAME}.zip" | cut -f1)
ARCH_INFO=$($LIPO && file "${MACOS_DIR}/${BINARY_NAME}" | grep -o 'arm64\|x86_64' | tr '\n' ' ' || file "${MACOS_DIR}/${BINARY_NAME}" | cut -d: -f2 | cut -d, -f1)

echo ""
echo "Done.  Arch:${ARCH_INFO}  Binary:${BINARY_SIZE}  ZIP:${ZIP_SIZE}"
echo "  ${APP_NAME}.zip — send to other Macs"
echo "  ${APP_BUNDLE} — drag to /Applications to install locally"
