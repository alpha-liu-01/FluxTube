#!/usr/bin/env bash
# Copy a pinned static GPL ffmpeg into DEST, next to fluxtube or fluxtube.exe.
# Build: BtbN/FFmpeg-Builds autobuild-2026-09-22-13-18 (GPL-2.0 or later).
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bundle-ffmpeg.sh DEST" >&2
  exit 1
fi

dest="$(cd "$1" && pwd)"
release="autobuild-2026-09-22-13-18"
base="https://github.com/BtbN/FFmpeg-Builds/releases/download/${release}"

# shellcheck disable=SC1091
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/host-arch.sh"
host_cpu="$(host_machine)"
case "${host_cpu}" in
  x86_64 | amd64) ffmpeg_arch=linux64 ;;
  aarch64 | arm64) ffmpeg_arch=linuxarm64 ;;
  *)
    echo "Unsupported CPU ${host_cpu}. This script bundles the x64 and aarch64 builds." >&2
    exit 1
    ;;
esac

case "$(uname -s)" in
  Linux)
    asset="ffmpeg-N-126756-g8b34c36e61-${ffmpeg_arch}-gpl.tar.xz"
    binary_name="ffmpeg"
    ;;
  MINGW* | MSYS* | CYGWIN*)
    case "${host_cpu}" in
      aarch64 | arm64)
        asset="ffmpeg-N-126755-g52f05ac780-winarm64-gpl.zip"
        ;;
      *)
        asset="ffmpeg-N-126755-g52f05ac780-win64-gpl.zip"
        ;;
    esac
    binary_name="ffmpeg.exe"
    ;;
  *)
    echo "Unsupported OS $(uname -s). This script bundles the Linux and Windows x64 and ARM64 builds." >&2
    exit 1
    ;;
esac

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

echo "Downloading ${asset}"
curl -fL --retry 3 -o "${workdir}/ffmpeg.archive" "${base}/${asset}"

mkdir -p "${workdir}/extract"
case "${asset}" in
  *.zip)
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "${workdir}/ffmpeg.archive" -d "${workdir}/extract"
    else
      tar -xf "${workdir}/ffmpeg.archive" -C "${workdir}/extract"
    fi
    ;;
  *)
    tar -xJf "${workdir}/ffmpeg.archive" -C "${workdir}/extract"
    ;;
esac

binary="$(find "${workdir}/extract" -type f -name "${binary_name}" | head -n 1)"
if [[ -z "${binary}" ]]; then
  echo "Archive did not contain ${binary_name}." >&2
  exit 1
fi

install -m 755 "${binary}" "${dest}/${binary_name}"
"${dest}/${binary_name}" -version | head -n 1
echo "Installed ${dest}/${binary_name}"
