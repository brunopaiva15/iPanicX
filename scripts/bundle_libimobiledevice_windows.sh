#!/bin/bash
# Prepares a self-contained copy of the libimobiledevice tools for the
# Windows build of iPanicX. Run it from an MSYS2 UCRT64 (or MINGW64) shell:
#
#   pacman -S --needed mingw-w64-ucrt-x86_64-libimobiledevice
#   ./scripts/bundle_libimobiledevice_windows.sh
#
# Result: windows/libimobiledevice/  idevice_id.exe, ideviceinfo.exe,
#                                    idevicecrashreport.exe, idevicepair.exe
#                                    + every non-system DLL they load.
#
# `flutter build windows` then installs that folder next to iPanicX.exe
# (see the end of windows/CMakeLists.txt). Windows loads DLLs from the
# executable's own folder, so no path rewriting is needed.
#
# Runtime requirement on the target PC: Apple's USB driver and the
# "Apple Mobile Device Service", installed by the "Apple Devices" app
# (Microsoft Store) or iTunes. libimobiledevice talks to that service.
#
# libimobiledevice and its dependencies are LGPL-2.1 / other open-source
# licenses: ship their license texts with any distributed build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${ROOT}/windows/libimobiledevice"
TOOLS=(idevice_id ideviceinfo idevicecrashreport idevicepair idevicediagnostics idevicesyslog)
PREFIX="${MINGW_PREFIX:-/ucrt64}"

rm -rf "${OUT:?}"
mkdir -p "${OUT}"

for tool in "${TOOLS[@]}"; do
  src="${PREFIX}/bin/${tool}.exe"
  if [ ! -f "${src}" ]; then
    echo "error: ${src} not found." >&2
    echo "Run: pacman -S --needed ${MINGW_PACKAGE_PREFIX:-mingw-w64-ucrt-x86_64}-libimobiledevice" >&2
    exit 1
  fi
  cp "${src}" "${OUT}/"
  # ldd lists every DLL; keep only those shipped by MSYS2 (not C:\Windows).
  ldd "${src}" | awk '{print $3}' | grep -E "^${PREFIX}/" | while read -r dll; do
    cp -n "${dll}" "${OUT}/" 2>/dev/null || true
  done
done

echo "Bundled into ${OUT}:"
ls -1 "${OUT}"
"${OUT}/idevice_id.exe" -l >/dev/null 2>&1 \
  && echo "idevice_id.exe runs OK" \
  || echo "warning: idevice_id.exe failed (is Apple Mobile Device Service running? a device connected?)"
