#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_repository="${SOURCE_REPOSITORY:-JuckZ/codex-desktop-bin}"
target_repository="${TARGET_REPOSITORY:-JuckZ/arch-repo}"
target_release_tag="${TARGET_RELEASE_TAG:-repository-x86_64}"
output_dir="${OUTPUT_DIR:-$repo_root/dist/codex-release}"
force_publish="${FORCE_PUBLISH:-false}"

for command in bsdtar curl gh jq node pacman sha256sum; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 1
  }
done

case "$force_publish" in
  true|false) ;;
  *)
    printf 'FORCE_PUBLISH must be true or false, got: %s\n' "$force_publish" >&2
    exit 1
    ;;
esac

mkdir -p "$output_dir"
release_json="$output_dir/source-release.json"
metadata_file="$output_dir/release-metadata.json"
gh api "repos/$source_repository/releases/latest" > "$release_json"

metadata_url="$(jq -r '
  [.assets[] | select(.name == "release-metadata.json")][0].browser_download_url // empty
' "$release_json")"
[ -n "$metadata_url" ] || {
  printf 'Latest %s release has no release-metadata.json\n' "$source_repository" >&2
  exit 1
}
curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
  --output "$metadata_file" "$metadata_url"

SOURCE_REPOSITORY="$source_repository" node - "$metadata_file" <<'NODE'
const fs = require("node:fs");
const metadata = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const expectedRepository = process.env.SOURCE_REPOSITORY;
const packageInfo = metadata.package ?? {};
if (metadata.schemaVersion !== 1) throw new Error("unsupported release metadata schema");
if (metadata.packaging?.repository !== expectedRepository) throw new Error("unexpected packaging repository");
if (packageInfo.name !== "codex-desktop") throw new Error("unexpected package name");
if (packageInfo.architecture !== "x86_64") throw new Error("unexpected package architecture");
if (!/^codex-desktop-[0-9][0-9A-Za-z._+-]*-x86_64\.pkg\.tar\.zst$/.test(packageInfo.fileName ?? "")) {
  throw new Error("unsafe package file name");
}
if (!/^[0-9a-f]{64}$/.test(packageInfo.sha256 ?? "")) throw new Error("invalid package SHA-256");
if (!/^[0-9a-f]{64}$/.test(metadata.upstreamLinuxPackage?.sha256 ?? "")) {
  throw new Error("invalid upstream SHA-256");
}
NODE

package_file="$(jq -r '.package.fileName' "$metadata_file")"
package_version="$(jq -r '.package.version' "$metadata_file")"
package_sha256="$(jq -r '.package.sha256' "$metadata_file")"
upstream_version="$(jq -r '.upstreamLinuxPackage.version' "$metadata_file")"
package_url="$(jq -r --arg name "$package_file" '
  [.assets[] | select(.name == $name)][0].browser_download_url // empty
' "$release_json")"
asset_digest="$(jq -r --arg name "$package_file" '
  [.assets[] | select(.name == $name)][0].digest // empty
' "$release_json")"

[ -n "$package_url" ] || {
  printf 'Latest release metadata references missing asset: %s\n' "$package_file" >&2
  exit 1
}
[ "$asset_digest" = "sha256:$package_sha256" ] || {
  printf 'GitHub asset digest does not match release metadata\n' >&2
  exit 1
}

already_published="$(gh release view "$target_release_tag" \
  --repo "$target_repository" --json assets \
  --jq ".assets[] | select(.name == \"$package_file\") | .name" 2>/dev/null || true)"
publish=true
if [ -n "$already_published" ] && [ "$force_publish" = false ]; then
  publish=false
fi

package_path="$output_dir/$package_file"
if [ "$publish" = true ]; then
  curl --fail --location --retry 5 --retry-all-errors --silent --show-error \
    --output "$package_path" "$package_url"
  actual_sha256="$(sha256sum "$package_path" | awk '{ print $1 }')"
  [ "$actual_sha256" = "$package_sha256" ] || {
    printf 'Downloaded package SHA-256 mismatch\n' >&2
    exit 1
  }
  actual_name="$(LC_ALL=C pacman -Qp "$package_path" | awk 'NR == 1 { print $1 }')"
  actual_version="$(LC_ALL=C pacman -Qp "$package_path" | awk 'NR == 1 { print $2 }')"
  actual_architecture="$(bsdtar -xOf "$package_path" .PKGINFO \
    | awk '$1 == "arch" { print $3; exit }')"
  [ "$actual_name" = codex-desktop ]
  [ "$actual_version" = "$package_version" ]
  [ "$actual_architecture" = x86_64 ]
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    printf 'package_file=%s\n' "$package_file"
    printf 'package_path=%s\n' "$package_path"
    printf 'package_version=%s\n' "$package_version"
    printf 'publish=%s\n' "$publish"
    printf 'upstream_version=%s\n' "$upstream_version"
  } >> "$GITHUB_OUTPUT"
fi

if [ "$publish" = true ]; then
  printf 'Verified %s %s from %s\n' \
    "$package_file" "$package_sha256" "$source_repository"
else
  printf '%s is already present in %s/%s\n' \
    "$package_file" "$target_repository" "$target_release_tag"
fi
