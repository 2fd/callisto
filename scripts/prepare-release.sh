#!/bin/bash
set -euo pipefail

# prepare-release.sh
# Builds, signs, notarizes, packages, and generates Sparkle appcast for Callisto.
# Intended to be invoked by semantic-release exec plugin during the prepare phase.
#
# Required environment variables:
#   RELEASE_VERSION         - semantic version (e.g. 1.2.3)
#   RELEASE_BUILD_NUMBER    - monotonic build number (e.g. GitHub run number)
#   GOOGLE_CLIENT_ID        - Google OAuth client ID
#   DEVELOPER_ID_CERTIFICATE_BASE64 - Base64-encoded .p12 Developer ID certificate
#   DEVELOPER_ID_CERTIFICATE_PASSWORD - Password for the .p12
#   APPLE_API_KEY_ID        - App Store Connect API key ID for notarization
#   APPLE_API_ISSUER_ID     - App Store Connect issuer ID
#   APPLE_API_KEY_P8_BASE64 - Base64-encoded .p8 API key
#   SPARKLE_PRIVATE_KEY_BASE64 - Base64-encoded Sparkle EdDSA private key file

RELEASE_VERSION="${RELEASE_VERSION:-$(cat .version 2>/dev/null || echo '1.0.0')}"
RELEASE_BUILD_NUMBER="${RELEASE_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"

echo "=== Preparing release ${RELEASE_VERSION} (build ${RELEASE_BUILD_NUMBER}) ==="

SCHEME="calendar"
PROJECT="calendar.xcodeproj"
ARCHIVE_PATH="build/Callisto.xcarchive"
EXPORT_PATH="build/export"
APP_NAME="Callisto.app"
DIST_DIR="dist"
SPARKLE_VERSION="2.9.1"
SPARKLE_DIR="build/sparkle"
TEAM_ID="489WB5L6KD"
CODE_SIGN_DETAILS_PATH="build/codesign-details.txt"
EXPECTED_ZIP_URL="https://github.com/${GITHUB_REPOSITORY}/releases/download/v${RELEASE_VERSION}/Callisto-${RELEASE_VERSION}.zip"

mkdir -p "${DIST_DIR}" "${EXPORT_PATH}"

# --- 1. App configuration ---
echo "=== Creating Config.xcconfig ==="
cat > Config.xcconfig <<EOF
GOOGLE_CLIENT_ID = ${GOOGLE_CLIENT_ID}
EOF

# --- 2. Setup signing keychain ---
echo "=== Setting up signing keychain ==="
KEYCHAIN_PATH="${RUNNER_TEMP}/app-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security list-keychain -d user -s "${KEYCHAIN_PATH}" $(security list-keychains -d user | tr -d '"')

# Import Developer ID certificate
echo "=== Importing Developer ID certificate ==="
echo "${DEVELOPER_ID_CERTIFICATE_BASE64}" | base64 -d > "${RUNNER_TEMP}/devid.p12"
security import "${RUNNER_TEMP}/devid.p12" -P "${DEVELOPER_ID_CERTIFICATE_PASSWORD}" -A -t cert -f pkcs12 -k "${KEYCHAIN_PATH}"
security set-key-partition-list -S apple-tool:,apple: -s -k "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

# --- 3. Archive ---
echo "=== Archiving ==="
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  MARKETING_VERSION="${RELEASE_VERSION}" \
  CURRENT_PROJECT_VERSION="${RELEASE_BUILD_NUMBER}" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  CODE_SIGN_STYLE="Manual" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  ENABLE_HARDENED_RUNTIME=YES

# --- 4. Export ---
echo "=== Exporting archive ==="
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist ExportOptions.plist

APP_PATH="${EXPORT_PATH}/${APP_NAME}"

# --- 5. Validate code signature ---
echo "=== Validating code signature ==="
codesign -dv --verbose=4 "${APP_PATH}" 2>&1 | tee "${CODE_SIGN_DETAILS_PATH}"
if ! grep -q "Authority=Developer ID Application" "${CODE_SIGN_DETAILS_PATH}"; then
  echo "ERROR: App is not signed with a Developer ID Application certificate"
  exit 1
fi
if ! grep -q "TeamIdentifier=${TEAM_ID}" "${CODE_SIGN_DETAILS_PATH}"; then
  echo "ERROR: App is not signed with expected team ${TEAM_ID}"
  exit 1
fi
if ! grep -q "Runtime Version=" "${CODE_SIGN_DETAILS_PATH}"; then
  echo "ERROR: Hardened runtime is not enabled"
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

# --- 6. Notarize ---
echo "=== Preparing notarization ==="
echo "${APPLE_API_KEY_P8_BASE64}" | base64 -d > "${RUNNER_TEMP}/AuthKey.p8"

ZIP_PATH="${DIST_DIR}/Callisto-${RELEASE_VERSION}.zip"

# Package for notarization (must preserve symlinks/extended attrs)
echo "=== Packaging for notarization ==="
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

echo "=== Submitting to notarization ==="
xcrun notarytool submit "${ZIP_PATH}" \
  --key-id "${APPLE_API_KEY_ID}" \
  --issuer "${APPLE_API_ISSUER_ID}" \
  --key "${RUNNER_TEMP}/AuthKey.p8" \
  --wait \
  --timeout 20m

# --- 7. Staple ---
echo "=== Stapling notarization ticket ==="
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

# --- 8. Re-package stapled app ---
echo "=== Re-packaging stapled app ==="
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"

# --- 9. Download Sparkle tools ---
echo "=== Downloading Sparkle tools ==="
mkdir -p "${SPARKLE_DIR}"
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
  | tar -xJ -C "${SPARKLE_DIR}" --strip-components=1

# --- 10. Generate appcast ---
echo "=== Generating appcast ==="
echo "${SPARKLE_PRIVATE_KEY_BASE64}" | base64 -d > "${RUNNER_TEMP}/sparkle_private.key"

"${SPARKLE_DIR}/bin/generate_appcast" \
  --ed-key-file "${RUNNER_TEMP}/sparkle_private.key" \
  --download-url-prefix "https://github.com/${GITHUB_REPOSITORY}/releases/download/v${RELEASE_VERSION}/" \
  --link "https://github.com/${GITHUB_REPOSITORY}/releases/tag/v${RELEASE_VERSION}" \
  --maximum-deltas 0 \
  "${DIST_DIR}"

# Move generated appcast to dist if it landed elsewhere
if [ -f "appcast.xml" ]; then
  mv appcast.xml "${DIST_DIR}/appcast.xml"
fi

# --- 11. Final validation ---
echo "=== Final validation ==="
ls -la "${DIST_DIR}"

# Verify appcast exists
if [ ! -f "${DIST_DIR}/appcast.xml" ]; then
  echo "ERROR: appcast.xml was not generated"
  exit 1
fi

# Verify zip exists and is non-empty
if [ ! -s "${ZIP_PATH}" ]; then
  echo "ERROR: Release zip is missing or empty"
  exit 1
fi

# Verify the appcast has the minimum Sparkle metadata needed for update delivery.
if ! grep -Fq 'sparkle:edSignature=' "${DIST_DIR}/appcast.xml"; then
  echo "ERROR: appcast is missing sparkle:edSignature"
  exit 1
fi
if ! grep -Fq 'sparkle:version="'"${RELEASE_BUILD_NUMBER}"'"' "${DIST_DIR}/appcast.xml"; then
  echo "ERROR: appcast is missing expected build ${RELEASE_BUILD_NUMBER}"
  exit 1
fi
if ! grep -Fq 'sparkle:shortVersionString="'"${RELEASE_VERSION}"'"' "${DIST_DIR}/appcast.xml"; then
  echo "ERROR: appcast is missing expected version ${RELEASE_VERSION}"
  exit 1
fi
if ! grep -Fq 'url="'"${EXPECTED_ZIP_URL}"'"' "${DIST_DIR}/appcast.xml"; then
  echo "ERROR: appcast is missing expected zip URL ${EXPECTED_ZIP_URL}"
  exit 1
fi
if ! grep -Eq 'length="[1-9][0-9]*"' "${DIST_DIR}/appcast.xml"; then
  echo "ERROR: appcast is missing a non-zero enclosure length"
  exit 1
fi

echo "=== Release artifacts ready ==="
