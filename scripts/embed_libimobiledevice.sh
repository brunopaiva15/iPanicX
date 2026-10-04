#!/bin/sh
# Xcode "Embed libimobiledevice" build phase (Runner target).
#
# Copies macos/libimobiledevice/{bin,lib} (produced by
# scripts/bundle_libimobiledevice.sh) into
# iPaniX.app/Contents/Resources/libimobiledevice and signs every Mach-O file
# with the identity used for the app, so the bundle can be notarized.
#
# If the folder does not exist the phase is a no-op: at runtime iPaniX then
# falls back to Homebrew (/opt/homebrew/bin, /usr/local/bin) or $PATH.
set -e

SRC="${SRCROOT}/libimobiledevice"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/libimobiledevice"

if [ ! -d "${SRC}/bin" ]; then
  echo "note: ${SRC} not found; iPaniX will use a system libimobiledevice at runtime."
  exit 0
fi

rm -rf "${DST}"
mkdir -p "${DST}"
cp -R "${SRC}/bin" "${DST}/"
[ -d "${SRC}/lib" ] && cp -R "${SRC}/lib" "${DST}/"

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY}"
[ -z "${IDENTITY}" ] && IDENTITY="-"

sign() {
  if [ "${IDENTITY}" = "-" ]; then
    codesign --force --sign - "$1"
  else
    codesign --force --sign "${IDENTITY}" --options runtime --timestamp "$1"
  fi
}

# Libraries first, then executables.
if [ -d "${DST}/lib" ]; then
  find "${DST}/lib" -type f -name "*.dylib" | while read -r f; do sign "$f"; done
fi
find "${DST}/bin" -type f | while read -r f; do sign "$f"; done

echo "Embedded libimobiledevice into ${DST}"
