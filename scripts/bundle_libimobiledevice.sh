#!/bin/bash
# Prepares a self-contained copy of the libimobiledevice tools for iPanicX.
#
#   brew install libimobiledevice
#   ./scripts/bundle_libimobiledevice.sh
#
# Result: macos/libimobiledevice/bin  (idevice_id, ideviceinfo,
#                                      idevicecrashreport, idevicepair)
#         macos/libimobiledevice/lib  (every non-system dylib they need)
#
# Install names are rewritten to @executable_path/../lib and @loader_path so
# the tools run from inside iPanicX.app without Homebrew. The Xcode build phase
# (scripts/embed_libimobiledevice.sh) copies and signs them.
#
# libimobiledevice and its dependencies are LGPL-2.1 / other open-source
# licenses: ship their license texts with any distributed build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/macos/libimobiledevice"
TOOLS=(idevice_id ideviceinfo idevicecrashreport idevicepair)
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"

rm -rf "${OUT}"
mkdir -p "${OUT}/bin" "${OUT}/lib"

# Non-system dependencies of a Mach-O file (skip /usr/lib and /System).
deps() {
  otool -L "$1" | tail -n +2 | awk '{print $1}' \
    | grep -v -E '^(/usr/lib/|/System/|@)' || true
}

copy_lib() {
  local src="$1" name
  name="$(basename "$src")"
  [ -f "${OUT}/lib/${name}" ] && return
  cp -L "$src" "${OUT}/lib/${name}"
  chmod u+w "${OUT}/lib/${name}"
  for d in $(deps "$src"); do copy_lib "$d"; done
}

for tool in "${TOOLS[@]}"; do
  src="$(command -v "$tool" || true)"
  [ -z "$src" ] && src="${BREW_PREFIX}/bin/${tool}"
  if [ ! -x "$src" ]; then
    echo "error: ${tool} not found. Run: brew install libimobiledevice" >&2
    exit 1
  fi
  cp -L "$src" "${OUT}/bin/${tool}"
  chmod u+w "${OUT}/bin/${tool}"
  for d in $(deps "$src"); do copy_lib "$d"; done
done

# Rewrite install names.
for lib in "${OUT}"/lib/*.dylib; do
  name="$(basename "$lib")"
  install_name_tool -id "@loader_path/${name}" "$lib" 2>/dev/null
  for d in $(deps "$lib"); do
    install_name_tool -change "$d" "@loader_path/$(basename "$d")" "$lib" 2>/dev/null
  done
done
for bin in "${OUT}"/bin/*; do
  for d in $(deps "$bin"); do
    install_name_tool -change "$d" "@executable_path/../lib/$(basename "$d")" "$bin" 2>/dev/null
  done
done

# install_name_tool invalidates signatures: ad-hoc sign for local runs
# (the Xcode build phase re-signs with the real identity).
for f in "${OUT}"/lib/*.dylib "${OUT}"/bin/*; do codesign --force --sign - "$f"; done

echo "Bundled into ${OUT}:"
ls -1 "${OUT}/bin" "${OUT}/lib"
"${OUT}/bin/idevice_id" -l >/dev/null 2>&1 && echo "idevice_id runs OK" || echo "warning: idevice_id did not run (is a device connected? usbmuxd running?)"
