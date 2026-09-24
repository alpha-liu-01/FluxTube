#!/usr/bin/env bash
# Build newpipe-spike.jar and unpack a headless Temurin 17 JRE into DEST.
# DEST is the directory that contains fluxtube or fluxtube.exe.
# The JRE is Eclipse Temurin, GPL-2.0 with the Classpath Exception.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bundle-runtime.sh DEST" >&2
  exit 1
fi

dest="$(cd "$1" && pwd)"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v java >/dev/null 2>&1; then
  echo "A JDK 17 is required to build the sidecar jar." >&2
  exit 1
fi

echo "Building newpipe-spike.jar"
(
  cd "${root}/packaging/newpipe-spike"
  bash ./gradlew --no-daemon jar
)
jar_src="${root}/packaging/newpipe-spike/build/libs/newpipe-spike.jar"
if [[ ! -f "${jar_src}" ]]; then
  echo "Sidecar jar was not produced at ${jar_src}." >&2
  exit 1
fi
cp "${jar_src}" "${dest}/newpipe-spike.jar"

case "$(uname -s)" in
  Linux) os_name=linux ;;
  Darwin) os_name=mac ;;
  MINGW* | MSYS* | CYGWIN*) os_name=windows ;;
  *)
    echo "Unsupported OS $(uname -s)." >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64) arch=x64 ;;
  *)
    echo "Unsupported CPU $(uname -m). This script bundles the x64 runtime." >&2
    exit 1
    ;;
esac

url="https://api.adoptium.net/v3/binary/latest/17/ga/${os_name}/${arch}/jre/hotspot/normal/eclipse?project=jdk"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

echo "Downloading Temurin 17 JRE for ${os_name}/${arch}"
curl -fL --retry 3 -o "${workdir}/jre.archive" -D "${workdir}/headers" "${url}"
filename="$(sed -n 's/.*[Ff]ilename=\([^;]*\).*/\1/p' "${workdir}/headers" | tr -d '\r" ' | tail -n 1)"
case "${filename}" in
  *.zip) kind=zip ;;
  *.tar.gz | *.tgz) kind=tar ;;
  *)
    if file "${workdir}/jre.archive" | grep -q 'Zip archive'; then
      kind=zip
    else
      kind=tar
    fi
    ;;
esac

mkdir -p "${workdir}/extract"
if [[ "${kind}" == zip ]]; then
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "${workdir}/jre.archive" -d "${workdir}/extract"
  else
    tar -xf "${workdir}/jre.archive" -C "${workdir}/extract"
  fi
else
  tar -xzf "${workdir}/jre.archive" -C "${workdir}/extract"
fi

top="$(find "${workdir}/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${top}" ]]; then
  echo "Temurin archive did not contain a runtime directory." >&2
  exit 1
fi

rm -rf "${dest}/jre"
mv "${top}" "${dest}/jre"

java_bin="${dest}/jre/bin/java"
if [[ -f "${dest}/jre/bin/java.exe" ]]; then
  java_bin="${dest}/jre/bin/java.exe"
fi
if [[ ! -x "${java_bin}" && ! -f "${java_bin}" ]]; then
  echo "Bundled runtime is missing ${java_bin}." >&2
  exit 1
fi
"${java_bin}" -version
echo "Installed ${dest}/newpipe-spike.jar and ${dest}/jre"
