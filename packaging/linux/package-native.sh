#!/usr/bin/env bash
# Wrap build/linux/x64/release/bundle as a deb, rpm, or Arch package
# for the distro this script is running on. Adds a desktop file and the
# hicolor icons so a desktop shell can launch GasTube.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$(uname -m)" in
  x86_64 | amd64)
    flutter_arch=x64
    pkg_arch=x86_64
    ;;
  aarch64 | arm64)
    flutter_arch=arm64
    pkg_arch=aarch64
    ;;
  *)
    echo "Unsupported CPU $(uname -m)." >&2
    exit 1
    ;;
esac
bundle="${root}/build/linux/${flutter_arch}/release/bundle"

if [[ ! -x "${bundle}/fluxtube" ]]; then
  echo "Release bundle is missing ${bundle}/fluxtube. Run build-release.sh first." >&2
  exit 1
fi
if [[ ! -f /etc/os-release ]]; then
  echo "No /etc/os-release. This script packages Debian, Fedora, and Arch families." >&2
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
if [[ -z "${family}" ]]; then
  echo "Unknown distro ${distro_id:-unset}. packaging/linux/BUILD.md lists the package names." >&2
  exit 1
fi

version="$(awk '/^version:/ {print $2; exit}' "${root}/pubspec.yaml")"
upstream="${version%%+*}"
release="${version#*+}"
if [[ "${release}" == "${version}" ]]; then
  release=1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
payload="${workdir}/payload"
mkdir -p "${payload}/opt" "${payload}/usr/bin" "${payload}/usr/share/applications" "${payload}/usr/share/icons/hicolor"
cp -a "${bundle}" "${payload}/opt/fluxtube"
ln -s /opt/fluxtube/fluxtube "${payload}/usr/bin/fluxtube"
cp "${here}/fluxtube.desktop" "${payload}/usr/share/applications/fluxtube.desktop"
cp -a "${here}/icons/." "${payload}/usr/share/icons/hicolor/"

mkdir -p "${root}/dist"

case "${family}" in
  debian)
    if ! command -v dpkg-deb >/dev/null 2>&1; then
      echo "dpkg-deb is missing. Install dpkg-dev and re-run." >&2
      exit 1
    fi
    mkdir -p "${workdir}/deb/DEBIAN"
    cp -a "${payload}/." "${workdir}/deb/"
    cat > "${workdir}/deb/DEBIAN/control" << EOF
Package: fluxtube
Version: ${version}
Architecture: $(dpkg --print-architecture)
Maintainer: GasTube
Depends: libgtk-3-0, libmpv2 | libmpv1
Description: Watch videos
 GasTube desktop build with a bundled Java runtime and ffmpeg.
EOF
    deb="${root}/dist/fluxtube_${version}_$(dpkg --print-architecture).deb"
    dpkg-deb --root-owner-group --build "${workdir}/deb" "${deb}"
    echo "Wrote ${deb}"
    ;;
  redhat)
    if ! command -v rpmbuild >/dev/null 2>&1; then
      echo "rpmbuild is missing. Install rpm-build and re-run." >&2
      exit 1
    fi
    mkdir -p "${workdir}/rpm/"{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    cp -a "${payload}" "${workdir}/rpm/SOURCES/payload"
    cat > "${workdir}/rpm/SPECS/fluxtube.spec" << EOF
Name: fluxtube
Version: ${upstream}
Release: ${release}
Summary: Watch videos
License: GPL-3.0-or-later
BuildArch: ${pkg_arch}
Requires: gtk3, mpv-libs

%description
GasTube desktop build with a bundled Java runtime and ffmpeg.

%install
mkdir -p %{buildroot}
cp -a %{_sourcedir}/payload/. %{buildroot}/

%files
/opt/fluxtube
/usr/bin/fluxtube
/usr/share/applications/fluxtube.desktop
/usr/share/icons/hicolor
EOF
    rpmbuild --define "_topdir ${workdir}/rpm" -bb "${workdir}/rpm/SPECS/fluxtube.spec"
    rpm="${root}/dist/fluxtube-${upstream}-${release}.${pkg_arch}.rpm"
    cp "${workdir}/rpm/RPMS/${pkg_arch}/fluxtube-${upstream}-${release}.${pkg_arch}.rpm" "${rpm}"
    echo "Wrote ${rpm}"
    ;;
  arch)
    if ! command -v makepkg >/dev/null 2>&1; then
      echo "makepkg is missing. Install base-devel and re-run." >&2
      exit 1
    fi
    mkdir -p "${workdir}/arch"
    cp -a "${payload}" "${workdir}/arch/payload"
    cat > "${workdir}/arch/PKGBUILD" << EOF
pkgname=fluxtube
pkgver=${upstream}
pkgrel=${release}
pkgdesc='Watch videos'
arch=('${pkg_arch}')
url='https://github.com/fazilvk/fluxtube'
license=('GPL-3.0-or-later')
depends=('gtk3' 'mpv')
options=('!strip' '!debug')

package() {
  cp -a "${workdir}/arch/payload/." "\${pkgdir}/"
}
EOF
    (
      cd "${workdir}/arch"
      PKGDEST="${root}/dist" makepkg --nodeps --skipinteg --noconfirm
    )
    echo "Wrote ${root}/dist/fluxtube-${upstream}-${release}-${pkg_arch}.pkg.tar.zst"
    ;;
esac
