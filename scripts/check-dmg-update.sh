#!/usr/bin/env bash
set -Eeuo pipefail

state_file="${1:?usage: check-dmg-update.sh <state-file> <output-dir> [force]}"
output_dir="${2:?usage: check-dmg-update.sh <state-file> <output-dir> [force]}"
force="${3:-false}"
dmg_url="${CODEX_DMG_URL:-https://persistent.oaistatic.com/codex-app-prod/ChatGPT.dmg}"
headers_file="${output_dir}/headers.txt"
candidate_file="${output_dir}/candidate.json"
dmg_path="${output_dir}/Codex.dmg"
extract_dir="${output_dir}/dmg-extract"

mkdir -p "$output_dir"

emit_output() {
  local name="$1"
  local value="$2"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf '%s=%s\n' "$name" "$value" >> "$GITHUB_OUTPUT"
  else
    printf '%s=%s\n' "$name" "$value"
  fi
}

curl -fsSLI --retry 5 --retry-all-errors --connect-timeout 30 \
  --max-time 120 -- "$dmg_url" > "$headers_file"

readarray -t remote_values < <(python3 - "$headers_file" <<'PY'
from pathlib import Path
import sys

values = {"etag": "", "last-modified": "", "content-length": ""}
for raw_line in Path(sys.argv[1]).read_text(errors="replace").splitlines():
    line = raw_line.strip()
    if line.lower().startswith("http/"):
        values = {"etag": "", "last-modified": "", "content-length": ""}
        continue
    if ":" not in line:
        continue
    key, value = line.split(":", 1)
    key = key.strip().lower()
    if key in values:
        values[key] = value.strip()

print(values["etag"])
print(values["last-modified"])
print(values["content-length"])
PY
)

remote_etag="${remote_values[0]:-}"
remote_last_modified="${remote_values[1]:-}"
remote_content_length="${remote_values[2]:-}"
state_etag="$(jq -r '.remote.etag // ""' "$state_file" 2>/dev/null || true)"
state_last_modified="$(jq -r '.remote.last_modified // ""' "$state_file" 2>/dev/null || true)"
state_content_length="$(jq -r '.remote.content_length // ""' "$state_file" 2>/dev/null || true)"
state_sha256="$(jq -r '.sha256 // ""' "$state_file" 2>/dev/null || true)"

if [[ "$force" != 'true' \
      && -n "$remote_etag" \
      && "$remote_etag" == "$state_etag" \
      && "$remote_last_modified" == "$state_last_modified" \
      && "$remote_content_length" == "$state_content_length" ]]; then
  printf 'DMG remote fingerprint is unchanged.\n'
  emit_output payload_changed false
  emit_output fingerprint_changed false
  exit 0
fi

rm -f "$dmg_path" "$dmg_path.aria2"
if command -v aria2c >/dev/null 2>&1; then
  aria2c --max-connection-per-server=16 --split=16 --max-tries=5 \
    --retry-wait=5 --connect-timeout=30 --timeout=600 \
    --allow-overwrite=true --auto-file-renaming=false \
    --console-log-level=warn --summary-interval=0 \
    --dir="$output_dir" --out="$(basename "$dmg_path")" -- "$dmg_url"
else
  curl -fL --retry 5 --retry-all-errors --connect-timeout 30 \
    --max-time 1200 -o "$dmg_path" -- "$dmg_url"
fi

test -s "$dmg_path"
dmg_sha256="$(sha256sum "$dmg_path" | awk '{print $1}')"
payload_changed=true
if [[ "$force" != 'true' && "$dmg_sha256" == "$state_sha256" ]]; then
  payload_changed=false
fi

if [[ "$payload_changed" == 'true' ]]; then
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  set +e
  7z x -y -snl "$dmg_path" -o"$extract_dir" >"${output_dir}/7z.log" 2>&1
  seven_status=$?
  set -e

  app_dir="$(find "$extract_dir" -maxdepth 4 -type d -name '*.app' | head -n 1)"
  if [[ -z "$app_dir" ]]; then
    cat "${output_dir}/7z.log" >&2
    printf 'Could not find an application bundle in the DMG (7z status %s).\n' "$seven_status" >&2
    exit 1
  fi

  app_version="$(python3 - "$app_dir/Contents/Info.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    info = plistlib.load(handle)
value = info.get("CFBundleShortVersionString") or info.get("CFBundleVersion") or ""
if not value:
    raise SystemExit("DMG application version is missing")
print(value)
PY
)"
else
  app_version="$(jq -r '.app_version // ""' "$state_file")"
fi

python3 - "$state_file" "$candidate_file" "$dmg_url" "$remote_etag" \
  "$remote_last_modified" "$remote_content_length" "$dmg_sha256" "$app_version" <<'PY'
from datetime import datetime, timezone
import json
from pathlib import Path
import sys

state_path, output_path, url, etag, modified, length, sha256, app_version = sys.argv[1:]
try:
    state = json.loads(Path(state_path).read_text())
except (FileNotFoundError, json.JSONDecodeError):
    state = {"schema_version": 1}

state.update({
    "schema_version": 1,
    "url": url,
    "remote": {
        "etag": etag,
        "last_modified": modified,
        "content_length": int(length) if length.isdigit() else None,
    },
    "sha256": sha256,
    "app_version": app_version,
    "checked_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
})
Path(output_path).write_text(json.dumps(state, indent=2, ensure_ascii=False) + "\n")
PY

emit_output payload_changed "$payload_changed"
emit_output fingerprint_changed true
emit_output candidate_file "$candidate_file"
emit_output dmg_path "$dmg_path"
emit_output dmg_sha256 "$dmg_sha256"
emit_output app_version "$app_version"

