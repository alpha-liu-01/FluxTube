#!/bin/bash
# Offline Flutter Linux release build inside flatpak-builder.
set -eu

# The module directory is a copy of the repo. Drop host build outputs so
# CMake does not reuse another machine's cache.
rm -rf build .dart_tool

sdk=/run/build/gastube/flutter-sdk
if [ ! -x "$sdk/bin/flutter" ]; then
  sdk=$sdk/flutter
fi

git config --global --add safe.directory "$sdk"
export FLUTTER_ROOT="$sdk"
export PATH="/run/build/gastube/packaging/flatpak/bin:$sdk/bin:${PATH}"

python3 - <<'PY'
import pathlib
import re

text = pathlib.Path("pubspec.lock").read_text()
root = pathlib.Path("/run/build/gastube/pub-cache/hosted-hashes/pub.dev")
root.mkdir(parents=True, exist_ok=True)
name = sha = ver = source = None
count = 0

def flush():
    global count, name, sha, ver, source
    if source == "hosted" and name and sha and ver:
        (root / f"{name}-{ver}.sha256").write_bytes(sha.encode())
        count += 1
    name = sha = ver = source = None

for line in text.splitlines():
    if re.match(r"^  [^ ].*:$", line):
        flush()
        continue
    if line.startswith("      name: "):
        name = line.split("name: ", 1)[1].strip().strip('"')
    elif line.startswith("      sha256: "):
        sha = line.split("sha256: ", 1)[1].strip().strip('"')
    elif line.startswith("    source: "):
        source = line.split("source: ", 1)[1].strip()
    elif line.startswith("    version: "):
        ver = line.split("version: ", 1)[1].strip().strip('"')
flush()
print(f"wrote {count} pub cache hashes")
PY

# PUB_CACHE is already set, so Flutter skips its own preload. Load the
# SDK's bundled tool packages first, then resolve flutter_tools offline.
# That writes packages/flutter_tools/.dart_tool/package_config.json, which
# is what makes later flutter commands skip a networked tool pub get.
dart="$sdk/bin/cache/dart-sdk/bin/dart"
preload="$sdk/.pub-preload-cache"
if [ -d "$preload" ]; then
  mapfile -t tool_archives < <(find "$preload" -name '*.tar.gz' | sort)
  "$dart" pub --suppress-analytics cache preload "${tool_archives[@]}"
fi
(
  cd "$sdk/packages/flutter_tools"
  "$dart" pub --suppress-analytics get --offline
)

flutter --no-version-check config --no-analytics --enable-linux-desktop
flutter --no-version-check pub get --offline
flutter --no-version-check build linux --release
