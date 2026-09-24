# Local Linux build

`packaging/linux/build-local.sh` installs the packages for this distro family, pins Flutter 3.47.1 if it is not already on `PATH`, and runs `build-release.sh`. The tarball is `dist/fluxtube-<version>-linux-x64.tar.gz` on x64 and `dist/fluxtube-<version>-linux-arm64.tar.gz` on aarch64. The script then builds the native package for this machine:

- Debian-like: `dist/fluxtube_<version>_<arch>.deb` (`dpkg-dev`). `<arch>` is `dpkg --print-architecture`, so `amd64` or `arm64`.
- Fedora-like: `dist/fluxtube-<upstream>-<release>.x86_64.rpm` (`rpm-build`). `0.9.3+14` becomes version `0.9.3` and release `14`. The spec still sets `BuildArch: x86_64`.
- Arch-like: `dist/fluxtube-<upstream>-<release>-x86_64.pkg.tar.zst` (`base-devel`). `pkgver` is `0.9.3` and `pkgrel` is `14`. The `PKGBUILD` still sets `arch=('x86_64')`.

Installing that package puts the app in `/opt/fluxtube`, a `/usr/bin/fluxtube` symlink, and a desktop file whose icon is the same launcher image as Android. That is what makes FluxTube show up in Plasma. The package depends on GTK 3 and libmpv (`libgtk-3-0` and `libmpv2 | libmpv1`, `gtk3` and `mpv-libs`, or `gtk3` and `mpv`).

Flutter is not installed from the distro. Distro packages track a different Flutter version.

```bash
bash packaging/linux/build-local.sh --install-deps
bash packaging/linux/build-local.sh
```

The second command only checks that the tools are present, then builds. An unknown distro stops and asks you to install the packages below yourself.

## Debian, Ubuntu, and other apt distros

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev \
  curl git unzip xz-utils zip make openjdk-17-jdk-headless ca-certificates \
  dpkg-dev
```

## Fedora, RHEL, and other dnf distros

```bash
sudo dnf install -y \
  clang cmake ninja-build pkgconf gtk3-devel xz-devel mpv-devel \
  curl git unzip xz zip make java-17-openjdk-devel \
  rpm-build
```

## Arch, CachyOS, EndeavourOS, and Manjaro

```bash
sudo pacman -S --needed --noconfirm \
  clang cmake ninja pkgconf gtk3 xz mpv \
  curl git unzip zip make jdk17-openjdk \
  base-devel
```

## ARM64

Run the same `build-local.sh` commands on an aarch64 glibc machine. The script chooses the ARM64 artifacts from `uname -m`. It does not cross-compile.

Flutter 3.47.1 has no official Linux ARM64 tarball. When `PATH` does not already have that version, the script clones the `3.47.1` tag into `~/.cache/fluxtube/flutter/flutter`. The release tree is `build/linux/arm64/release/bundle`, and the archive is `dist/fluxtube-<version>-linux-arm64.tar.gz`.

The sidecar still needs JDK 17. Gradle 8.11.1 cannot run on a newer default JVM. Fedora and Arch install their JDK 17 packages from the lists above. Debian 13 has no `openjdk-17-jdk-headless` package, so `--install-deps` skips that package and downloads Eclipse Temurin 17 (Adoptium, `linux/aarch64`) into `/usr/lib/jvm/temurin-17-jdk`. The copy inside the package is a Temurin 17 JRE for the same architecture, plus the BtbN `linuxarm64` GPL ffmpeg from autobuild `2026-09-22-13-18`. libmpv stays a distro dependency.

The Debian package on this architecture is `dist/fluxtube_<version>_arm64.deb`. The Fedora and Arch packagers still label the package `x86_64`, so use the Debian package or the `linux-arm64` tarball for an aarch64 install.

The Linux `volume_controller` plugin in that package is the vendored 3.6.0 tree. It looks for an ALSA playback element named `Master`, then `PCM`, `Speaker`, `Headphone`, `Digital`, and `Playback`, then any element that has a playback volume. If the card has none, volume calls return an error instead of crashing, and mpv keeps its own volume.
