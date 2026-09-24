#!/usr/bin/env bash
# Install distro packages for a local Linux x64 build, pin Flutter 3.47.1,
# then run build-release.sh. Package lists are in BUILD.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
required_flutter="3.47.1"
install_deps=0

for arg in "$@"; do
  case "${arg}" in
    --install-deps) install_deps=1 ;;
    *)
      echo "usage: build-local.sh [--install-deps]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f /etc/os-release ]]; then
  echo "No /etc/os-release. Install the packages in packaging/linux/BUILD.md and re-run." >&2
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

family=""
distro_id="${ID:-}"
like=" ${ID_LIKE:-} "
case "${distro_id}" in
  debian | ubuntu | linuxmint | pop) family=debian ;;
  fedora | rhel | centos | nobara | rocky | almalinux) family=redhat ;;
  arch | cachyos | endeavouros | manjaro) family=arch ;;
esac
if [[ -z "${family}" ]]; then
  if [[ "${like}" == *" debian "* ]]; then
    family=debian
  elif [[ "${like}" == *" fedora "* || "${like}" == *" rhel "* ]]; then
    family=redhat
  elif [[ "${like}" == *" arch "* ]]; then
    family=arch
  fi
fi

debian_packages=(
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev
  curl git unzip xz-utils zip make openjdk-17-jdk-headless ca-certificates
  dpkg-dev
)
redhat_packages=(
  clang cmake ninja-build pkgconf gtk3-devel xz-devel mpv-devel
  curl git unzip xz zip make java-17-openjdk-devel
  rpm-build
)
arch_packages=(
  clang cmake ninja pkgconf gtk3 xz mpv
  curl git unzip zip make jdk17-openjdk
  base-devel
)

print_install() {
  case "${family}" in
    debian)
      echo "sudo apt-get update && sudo apt-get install -y --no-install-recommends ${debian_packages[*]}"
      ;;
    redhat)
      echo "sudo dnf install -y ${redhat_packages[*]}"
      ;;
    arch)
      echo "sudo pacman -S --needed --noconfirm ${arch_packages[*]}"
      ;;
  esac
}

if [[ -z "${family}" ]]; then
  echo "Unknown distro ${distro_id:-unset}. Install the packages in packaging/linux/BUILD.md and re-run." >&2
  exit 1
fi

if [[ "${install_deps}" -eq 1 ]]; then
  case "${family}" in
    debian)
      sudo apt-get update
      sudo apt-get install -y --no-install-recommends "${debian_packages[@]}"
      ;;
    redhat)
      sudo dnf install -y "${redhat_packages[@]}"
      ;;
    arch)
      sudo pacman -S --needed --noconfirm "${arch_packages[@]}"
      ;;
  esac
else
  missing=0
  for cmd in clang cmake ninja make curl git unzip; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "Missing command: ${cmd}" >&2
      missing=1
    fi
  done
  if ! command -v pkg-config >/dev/null 2>&1; then
    echo "Missing command: pkg-config" >&2
    missing=1
  else
    for module in gtk+-3.0 mpv liblzma; do
      if ! pkg-config --exists "${module}"; then
        echo "Missing pkg-config module: ${module}" >&2
        missing=1
      fi
    done
  fi
  has_jdk17=0
  if command -v java >/dev/null 2>&1; then
    java_line="$(java -version 2>&1 | head -n 1 || true)"
    if [[ "${java_line}" =~ \"17 ]]; then
      has_jdk17=1
    fi
  fi
  if [[ "${has_jdk17}" -eq 0 ]]; then
    shopt -s nullglob
    for candidate in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/java-17-openjdk; do
      if [[ -x "${candidate}/bin/java" ]]; then
        has_jdk17=1
      fi
    done
    shopt -u nullglob
  fi
  if [[ "${has_jdk17}" -eq 0 ]]; then
    echo "Missing JDK 17" >&2
    missing=1
  fi
  if [[ "${missing}" -eq 1 ]]; then
    echo "Install the ${family} packages, then re-run:" >&2
    echo "  bash packaging/linux/build-local.sh --install-deps" >&2
    print_install >&2
    exit 1
  fi
fi

if command -v flutter >/dev/null 2>&1; then
  actual_flutter="$(flutter --version | awk '/^Flutter / {print $2; exit}')"
  if [[ "${actual_flutter}" != "${required_flutter}" ]]; then
    echo "Flutter on PATH is ${actual_flutter:-unknown}. Using the pinned ${required_flutter} SDK." >&2
  fi
else
  actual_flutter=""
fi

if [[ "${actual_flutter}" != "${required_flutter}" ]]; then
  cache="${HOME}/.cache/fluxtube/flutter"
  sdk="${cache}/flutter"
  cached=""
  if [[ -x "${sdk}/bin/flutter" ]]; then
    cached="$("${sdk}/bin/flutter" --version | awk '/^Flutter / {print $2; exit}')"
  fi
  if [[ "${cached}" != "${required_flutter}" ]]; then
    mkdir -p "${cache}"
    archive="$(mktemp)"
    echo "Downloading Flutter ${required_flutter}"
    curl -fL --retry 3 -o "${archive}" \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${required_flutter}-stable.tar.xz"
    rm -rf "${sdk}"
    tar -C "${cache}" -xf "${archive}"
    rm -f "${archive}"
  fi
  export PATH="${sdk}/bin:${PATH}"
fi

"${root}/packaging/linux/build-release.sh"
"${root}/packaging/linux/package-native.sh"
