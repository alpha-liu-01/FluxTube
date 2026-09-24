#!/usr/bin/env bash
# Build the Linux x64 release bundle and pack it into dist/.
# Requires Flutter 3.47.1 on PATH. Used by the host, the container, and CI.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${root}"

required_flutter="3.47.1"
export CI="${CI:-true}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH. Install Flutter ${required_flutter} and re-run." >&2
  exit 1
fi

actual_flutter="$(flutter --version | awk '/^Flutter / {print $2; exit}')"
if [[ "${actual_flutter}" != "${required_flutter}" ]]; then
  echo "Flutter ${required_flutter} is required, found ${actual_flutter:-unknown}." >&2
  exit 1
fi

flutter config --no-analytics --enable-linux-desktop >/dev/null

version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
if [[ -z "${version}" ]]; then
  echo "Could not read version from pubspec.yaml." >&2
  exit 1
fi

flutter pub get
dart_define_args=()
if [[ -n "${FLUXTUBE_DART_DEFINE:-}" ]]; then
  dart_define_args+=(--dart-define="${FLUXTUBE_DART_DEFINE}")
fi
flutter build linux --release "${dart_define_args[@]}"

bundle="${root}/build/linux/x64/release/bundle"
if [[ ! -x "${bundle}/fluxtube" ]]; then
  echo "Release bundle is missing ${bundle}/fluxtube." >&2
  exit 1
fi

"${root}/packaging/java/bundle-runtime.sh" "${bundle}"
"${root}/packaging/ffmpeg/bundle-ffmpeg.sh" "${bundle}"

mkdir -p "${root}/dist"
archive="${root}/dist/fluxtube-${version}-linux-x64.tar.gz"
rm -f "${archive}"
tar -C "${root}/build/linux/x64/release" \
  --transform 's,^bundle,fluxtube,' \
  -czf "${archive}" \
  bundle

echo "Wrote ${archive}"
