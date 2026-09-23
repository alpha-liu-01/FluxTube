#!/usr/bin/env bash
# Build the Linux x64 archive inside the Ubuntu 26.04 toolchain image.
# The tarball is written to dist/ on the host, same as build-release.sh.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image="${FLUXTUBE_LINUX_BUILD_IMAGE:-fluxtube-linux-build}"

docker build \
  -t "${image}" \
  -f "${root}/packaging/linux/Dockerfile" \
  "${root}/packaging/linux"

docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e PUB_CACHE=/tmp/pub-cache \
  -e CI=true \
  -v "${root}:/src" \
  -w /src \
  "${image}" \
  /src/packaging/linux/build-release.sh
