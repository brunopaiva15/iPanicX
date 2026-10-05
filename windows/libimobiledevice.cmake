# libimobiledevice for the Windows build of iPaniX.
#
# iPaniX needs idevice_id.exe, ideviceinfo.exe, idevicecrashreport.exe and
# idevicepair.exe next to iPaniX.exe (in "libimobiledevice\", where
# lib/services/tool_locator.dart looks first).
#
# Source, in this order:
#   1. windows/libimobiledevice/ if it exists (made by
#      scripts/bundle_libimobiledevice_windows.sh from an MSYS2 install);
#   2. otherwise, the official MSYS2 UCRT64 packages listed below, downloaded
#      ONCE at configure time, checked against their SHA-256 and cached in the
#      build folder. Nothing is downloaded at runtime: the app stays offline.
#      Turn off with -DIPANIX_FETCH_LIBIMOBILEDEVICE=OFF.
#
# The DLL list is the full dependency closure of the four tools (checked with
# objdump); everything else they import is part of Windows 10/11 (UCRT).
# libimobiledevice and its dependencies are LGPL-2.1 / Apache-2.0 (OpenSSL).

option(IPANIX_FETCH_LIBIMOBILEDEVICE
  "Download libimobiledevice (MSYS2 UCRT64 packages) when windows/libimobiledevice is absent"
  ON)

set(IPANIX_LIBIMOBILEDEVICE_PACKAGES
  "mingw-w64-ucrt-x86_64-libimobiledevice-1.3.0-17-any.pkg.tar.zst|2f8ede1528372fa0ec7d3ec9f248b22c43e3bb2f573025c9086781413d12a1d1"
  "mingw-w64-ucrt-x86_64-libimobiledevice-glue-1.3.2-1-any.pkg.tar.zst|d089c718ab846c5bd1f41fb2788a976fdbda13c9f09128a670eca578da0bc34f"
  "mingw-w64-ucrt-x86_64-libplist-2.7.0-4-any.pkg.tar.zst|665607c34dbf923ebb820d78b376db59de4d2d3874a45d70f24f51eb1d64f127"
  "mingw-w64-ucrt-x86_64-libusbmuxd-2.1.1-1-any.pkg.tar.zst|27c86acc00eda349947fa0fde05cfca805ab1aee6da4cc4e4a6486aedf054f1c"
  "mingw-w64-ucrt-x86_64-openssl-3.6.5-1-any.pkg.tar.zst|773e021ebad83f14b5c103db467411e8ff064663e1c7e7f730e2be72f4117064"
)
set(IPANIX_LIBIMOBILEDEVICE_FILES
  idevice_id.exe ideviceinfo.exe idevicecrashreport.exe idevicepair.exe
  libimobiledevice-1.0.dll libimobiledevice-glue-1.0.dll libplist-2.0.dll
  libusbmuxd-2.0.dll libssl-3-x64.dll libcrypto-3-x64.dll
)
set(IPANIX_MSYS2_MIRRORS
  "https://repo.msys2.org/mingw/ucrt64"
  "https://mirror.msys2.org/mingw/ucrt64"
  "https://mirrors.tuna.tsinghua.edu.cn/msys2/mingw/ucrt64"
)

# Sets <out_var> to a folder holding the tools, or "" if unavailable.
function(ipanix_prepare_libimobiledevice source_dir binary_dir out_var)
  set(manual "${source_dir}/libimobiledevice")
  if(EXISTS "${manual}/idevice_id.exe")
    message(STATUS "iPaniX: using bundled libimobiledevice from ${manual}")
    set(${out_var} "${manual}" PARENT_SCOPE)
    return()
  endif()
  if(NOT IPANIX_FETCH_LIBIMOBILEDEVICE)
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  set(root "${binary_dir}/libimobiledevice")
  set(out "${root}/bin")
  string(SHA256 stamp "${IPANIX_LIBIMOBILEDEVICE_PACKAGES}")
  if(EXISTS "${out}/.stamp-${stamp}")
    set(${out_var} "${out}" PARENT_SCOPE)
    return()
  endif()

  message(STATUS "iPaniX: downloading libimobiledevice (MSYS2 UCRT64, ~9 MB, once)")
  file(REMOVE_RECURSE "${root}")
  file(MAKE_DIRECTORY "${root}/packages" "${root}/extract" "${out}")
  foreach(entry IN LISTS IPANIX_LIBIMOBILEDEVICE_PACKAGES)
    string(REPLACE "|" ";" parts "${entry}")
    list(GET parts 0 name)
    list(GET parts 1 sha)
    set(archive "${root}/packages/${name}")
    set(ok FALSE)
    foreach(mirror IN LISTS IPANIX_MSYS2_MIRRORS)
      file(DOWNLOAD "${mirror}/${name}" "${archive}"
        STATUS status TLS_VERIFY ON TIMEOUT 120)
      list(GET status 0 code)
      if(code EQUAL 0)
        file(SHA256 "${archive}" actual)
        if(actual STREQUAL sha)
          set(ok TRUE)
          break()
        endif()
        message(WARNING "iPaniX: checksum mismatch for ${name} from ${mirror}")
      endif()
    endforeach()
    if(NOT ok)
      message(WARNING
        "iPaniX: could not download ${name}. The app will build without "
        "bundled tools and look for an MSYS2 install at runtime "
        "(pacman -S mingw-w64-ucrt-x86_64-libimobiledevice).")
      set(${out_var} "" PARENT_SCOPE)
      return()
    endif()
    # CMake's bundled libarchive reads .tar.zst.
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xf "${archive}"
      WORKING_DIRECTORY "${root}/extract"
      RESULT_VARIABLE extract_result)
    if(NOT extract_result EQUAL 0)
      message(WARNING "iPaniX: could not extract ${name}")
      set(${out_var} "" PARENT_SCOPE)
      return()
    endif()
  endforeach()

  foreach(f IN LISTS IPANIX_LIBIMOBILEDEVICE_FILES)
    set(src "${root}/extract/ucrt64/bin/${f}")
    if(NOT EXISTS "${src}")
      message(WARNING "iPaniX: ${f} missing from the MSYS2 packages")
      set(${out_var} "" PARENT_SCOPE)
      return()
    endif()
    file(COPY "${src}" DESTINATION "${out}")
  endforeach()
  # License texts that ship with the binaries.
  file(GLOB licenses "${root}/extract/ucrt64/share/licenses/*")
  if(licenses)
    file(COPY ${licenses} DESTINATION "${out}/licenses")
  endif()
  file(REMOVE_RECURSE "${root}/extract")
  file(WRITE "${out}/.stamp-${stamp}" "")
  message(STATUS "iPaniX: libimobiledevice ready in ${out}")
  set(${out_var} "${out}" PARENT_SCOPE)
endfunction()
