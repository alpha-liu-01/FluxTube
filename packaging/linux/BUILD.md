# Local Linux x64 build

`packaging/linux/build-local.sh` installs the packages for this distro family, downloads Flutter 3.47.1 if it is not already on `PATH`, and runs `build-release.sh`. The tarball is `dist/fluxtube-<version>-linux-x64.tar.gz`. The script then builds the native package for this machine:

- Debian-like: `dist/fluxtube_<version>_amd64.deb` (`dpkg-dev`)
- Fedora-like: `dist/fluxtube-<upstream>-<release>.x86_64.rpm` (`rpm-build`). `0.9.3+14` becomes version `0.9.3` and release `14`.
- Arch-like: `dist/fluxtube-<upstream>-<release>-x86_64.pkg.tar.zst` (`base-devel`). `pkgver` is `0.9.3` and `pkgrel` is `14`.

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
