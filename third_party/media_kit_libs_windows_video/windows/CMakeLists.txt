# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------
function(download_and_verify url md5 locationForArchive)
  # Check if the archive exists.
  if(EXISTS "${locationForArchive}")
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    # If MD5 doesn't match, delete the archive to download again.
    if(NOT md5 STREQUAL ARCHIVE_MD5)
      file(REMOVE "${locationForArchive}")
      message(STATUS "MD5 mismatch. File deleted.")
    endif()
  endif()

  # Download the archive if it doesn't exist.
  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(DOWNLOAD "${url}" "${locationForArchive}")
    message(STATUS "Downloaded archive to ${locationForArchive}.")

    # Verify MD5 of the newly downloaded file.
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    if(md5 STREQUAL ARCHIVE_MD5)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(check_directory_exists_and_not_empty dir result_var)
  # Check if the directory exists
  if(EXISTS "${dir}")
    # Check if the directory is not empty
    file(GLOB dir_contents "${dir}/*")

    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
      message(STATUS "Directory ${dir} exists but is empty!")
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
    message(STATUS "Directory ${dir} does not exist!")
  endif()
endfunction()

# libmpv archive containing the pre-built shared libraries & headers.
# x64: shinchiro's baseline x86-64 build (no AVX2 requirement), mirrored
# unchanged from
# https://github.com/shinchiro/mpv-winbuild-cmake/releases/tag/20260924
# Its d3d11-egl interop accepts ANGLE's client-side EGL_EXT_device_query
# (mpv#18326), so hardware decoding is zero-copy d3d11va, not d3d11va-copy.
# ARM64: a no-DotProd build. Stock aarch64 libmpv uses SDOT/UDOT, which
# Snapdragon 850 traps.
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  find_program(SEVEN_ZIP NAMES 7z 7za REQUIRED
    PATHS "C:/Program Files/7-Zip" "C:/Program Files (x86)/7-Zip")
  set(LIBMPV "mpv-dev-aarch64-nodotprod.7z")
  set(LIBMPV_URL "https://github.com/alpha-liu-01/FluxTube/releases/download/windows-arm64-libmpv/${LIBMPV}")
  set(LIBMPV_MD5 "d64114f38dc0c0cc73ff98c5a1387f0f")
else()
  set(LIBMPV "mpv-dev-x86_64-20260924-git-2a4eb8067c.7z")
  set(LIBMPV_URL "https://github.com/alpha-liu-01/FluxTube/releases/download/deps-libmpv-20260924/${LIBMPV}")
  set(LIBMPV_MD5 "57151c4ca8caaf4a833cd41ec5a2900c")
endif()

# Download location of the libmpv archive.
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV}")
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")

download_and_verify(
  ${LIBMPV_URL}
  ${LIBMPV_MD5}
  ${LIBMPV_ARCHIVE}
)

# media_kit_video reads ${CMAKE_BINARY_DIR}/libmpv directly, so the folder name
# is fixed. Re-extract when it holds a different archive.
set(LIBMPV_MARKER "${LIBMPV_SRC}/.archive")
if(EXISTS "${LIBMPV_SRC}")
  set(LIBMPV_EXTRACTED "")
  if(EXISTS "${LIBMPV_MARKER}")
    file(READ "${LIBMPV_MARKER}" LIBMPV_EXTRACTED)
    string(STRIP "${LIBMPV_EXTRACTED}" LIBMPV_EXTRACTED)
  endif()
  if(NOT LIBMPV_EXTRACTED STREQUAL LIBMPV)
    message(STATUS "Removing libmpv extracted from a different archive.")
    file(REMOVE_RECURSE "${LIBMPV_SRC}")
  endif()
endif()

check_directory_exists_and_not_empty(${LIBMPV_SRC} LIBMPV_SRC_VALID)

# Extract the libmpv archive.
if(NOT LIBMPV_SRC_VALID)
  message(STATUS "Extracting ${LIBMPV}...")
  make_directory("${LIBMPV_SRC}")
  add_custom_target("${PROJECT_NAME}_LIBMPV_EXTRACT" ALL)
  if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
    set(LIBMPV_EXTRACT_COMMAND "${SEVEN_ZIP}" x -y "${LIBMPV_ARCHIVE}")
  else()
    set(LIBMPV_EXTRACT_COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${LIBMPV_ARCHIVE}\"")
  endif()
  add_custom_command(
    TARGET "${PROJECT_NAME}_LIBMPV_EXTRACT"
    COMMAND ${LIBMPV_EXTRACT_COMMAND}
    COMMAND xcopy "\"${LIBMPV_SRC}/include/mpv\"" "\"${LIBMPV_SRC}/mpv\"" /E /H /C /I
    COMMAND rmdir "\"${LIBMPV_SRC}/include\"" /S /Q
    COMMAND ren "\"${LIBMPV_SRC}/mpv\"" "\"include\""
    COMMAND "${CMAKE_COMMAND}" -E echo_append "${LIBMPV}" > .archive
    WORKING_DIRECTORY "${LIBMPV_SRC}"
  )
endif()

# ------------------------------------------------------------------------------

# ANGLE archive containing the pre-built shared libraries & headers.
# ANGLE.7z is x64. Windows ARM64 uses the matching ARM64 build.
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  set(ANGLE "ANGLE_WINARM64.7z")
  set(ANGLE_URL "https://github.com/talynone/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/${ANGLE}")
  set(ANGLE_MD5 "b56aaae894ccf6c8ee90b59ee642a787")
else()
  set(ANGLE "ANGLE.7z")
  set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/${ANGLE}")
  set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")
endif()

# Download location of the ANGLE archive.
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

download_and_verify(
  ${ANGLE_URL}
  ${ANGLE_MD5}
  ${ANGLE_ARCHIVE}
)

check_directory_exists_and_not_empty(${ANGLE_SRC} ANGLE_SRC_VALID)

# Extract the ANGLE archive.
if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting ${ANGLE}...")
  make_directory("${ANGLE_SRC}")
  add_custom_target("${PROJECT_NAME}_ANGLE_EXTRACT" ALL)
  if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
    set(ANGLE_EXTRACT_COMMAND "${SEVEN_ZIP}" x -y "${ANGLE_ARCHIVE}")
  else()
    set(ANGLE_EXTRACT_COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${ANGLE_ARCHIVE}\"")
  endif()
  add_custom_command(
    TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
    COMMAND ${ANGLE_EXTRACT_COMMAND}
    WORKING_DIRECTORY "${ANGLE_SRC}"
  )
endif()

# ------------------------------------------------------------------------------
set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
