#!/usr/bin/env bash
# Extract one video with the NewPipe spike jar and play it in mpv for 8 seconds.
# Prints the title and which kind of stream was chosen. Does not print the URL.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${root}"

video_id="${1:-jNQXAC9IVRw}"
export DISPLAY="${DISPLAY:-:0}"

if ! command -v java >/dev/null 2>&1; then
  echo "java is not on PATH. Install openjdk-17-jdk." >&2
  exit 1
fi
if ! command -v mpv >/dev/null 2>&1; then
  echo "mpv is not on PATH." >&2
  exit 1
fi

./gradlew --no-daemon jar

jar="${root}/build/libs/newpipe-spike.jar"
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

json="${workdir}/info.json"
if ! java -jar "${jar}" "${video_id}" >"${json}"; then
  echo "NewPipe extraction failed for ${video_id}." >&2
  exit 1
fi

mode="$(
  python3 - "${json}" "${workdir}" <<'PY'
import json
import sys

info_path, workdir = sys.argv[1], sys.argv[2]
with open(info_path, encoding="utf-8") as handle:
    data = json.load(handle)

def usable(items):
    return [item for item in (items or []) if item.get("url")]

def height(item):
    resolution = item.get("resolution") or ""
    if "x" in resolution:
        try:
            return int(resolution.split("x")[-1])
        except ValueError:
            return 10**9
    digits = "".join(ch for ch in resolution if ch.isdigit())
    return int(digits) if digits else 10**9

title = data.get("title") or "(no title)"
print(f"title: {title}", file=sys.stderr)

muxed = sorted(usable(data.get("videoStreams")), key=height)
video_only = sorted(usable(data.get("videoOnlyStreams")), key=height)
audio = usable(data.get("audioStreams"))
print(
    f"streams: muxed={len(muxed)} videoOnly={len(video_only)} audio={len(audio)}",
    file=sys.stderr,
)

user_agent = data.get("userAgent") or ""
with open(f"{workdir}/user-agent", "w", encoding="utf-8") as handle:
    handle.write(user_agent)

if muxed:
    chosen = muxed[0]
    with open(f"{workdir}/video.url", "w", encoding="utf-8") as handle:
        handle.write(chosen["url"])
    print(
        f"chosen: muxed {chosen.get('resolution') or 'unknown'} {chosen.get('mimeType') or ''}".rstrip(),
        file=sys.stderr,
    )
    print("muxed")
elif video_only and audio:
    chosen = video_only[0]
    with open(f"{workdir}/video.url", "w", encoding="utf-8") as handle:
        handle.write(chosen["url"])
    with open(f"{workdir}/audio.url", "w", encoding="utf-8") as handle:
        handle.write(audio[0]["url"])
    print(
        f"chosen: split {chosen.get('resolution') or 'unknown'} {chosen.get('mimeType') or ''}".rstrip(),
        file=sys.stderr,
    )
    print("split")
else:
    print("no playable stream in the NewPipe response", file=sys.stderr)
    sys.exit(2)
PY
)"

video_url="$(cat "${workdir}/video.url")"
user_agent="$(cat "${workdir}/user-agent")"
log="${workdir}/mpv.log"

mpv_args=(
  mpv
  --no-config
  --no-terminal
  --force-window=immediate
  --end=8
  --user-agent="${user_agent}"
  --referrer="https://www.youtube.com/"
  --log-file="${log}"
)

if [[ "${mode}" == "split" ]]; then
  mpv_args+=(--audio-file="$(cat "${workdir}/audio.url")")
elif [[ "${mode}" != "muxed" ]]; then
  echo "Unexpected playback mode: ${mode}" >&2
  exit 1
fi

mpv_args+=("${video_url}")

set +e
"${mpv_args[@]}"
mpv_status=$?
set -e

if [[ "${mpv_status}" -ne 0 ]]; then
  echo "mpv failed (exit ${mpv_status}) for ${video_id} (${mode})." >&2
  if [[ -f "${log}" ]]; then
    grep -Ei 'failed to recognize|HTTP error|403|Exiting' "${log}" | head -n 20 >&2 || true
  fi
  exit "${mpv_status}"
fi

if [[ -f "${log}" ]] && grep -Eqi 'failed to recognize|HTTP error|403 Forbidden' "${log}"; then
  echo "mpv exited 0 but the log reports a playback error for ${video_id} (${mode})." >&2
  grep -Ei 'failed to recognize|HTTP error|403 Forbidden' "${log}" | head -n 20 >&2 || true
  exit 1
fi

echo "played ${video_id} (${mode}) for 8 seconds"
