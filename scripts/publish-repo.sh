#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_file="$(realpath "${1:?usage: publish-repo.sh <package-file>}")"
repo_name="${GITHUB_REPOSITORY:-JuckZ/arch-repo}"
repo_db="${REPO_DB_NAME:-juckz}"
repo_arch="$(pacman -Qp "$package_file" | awk '{print $1 ":" $2}' >/dev/null; \
  bsdtar -xOf "$package_file" .PKGINFO | awk -F ' = ' '$1 == "arch" { print $2; exit }')"
release_tag="repository-${repo_arch}"
work_dir="${repo_root}/repo-work/${repo_arch}"
new_name="$(pacman -Qp "$package_file" | awk '{print $1}')"
key_id="${REPO_GPG_KEY_ID:?REPO_GPG_KEY_ID is required}"

rm -rf "$work_dir"
mkdir -p "$work_dir"

if ! gh release view "$release_tag" --repo "$repo_name" >/dev/null 2>&1; then
  gh release create "$release_tag" --repo "$repo_name" \
    --title "Pacman repository (${repo_arch})" \
    --notes "Rolling signed pacman repository assets for ${repo_arch}."
fi

gh release download "$release_tag" --repo "$repo_name" \
  --pattern '*.pkg.tar.zst' --dir "$work_dir" 2>/dev/null || true
gh release download "$release_tag" --repo "$repo_name" \
  --pattern '*.pkg.tar.zst.sig' --dir "$work_dir" 2>/dev/null || true

for old_file in "$work_dir"/*.pkg.tar.zst; do
  [[ -e "$old_file" ]] || continue
  old_name="$(pacman -Qp "$old_file" | awk '{print $1}')"
  if [[ "$old_name" == "$new_name" ]]; then
    gh release delete-asset "$release_tag" "$(basename "$old_file")" \
      --repo "$repo_name" --yes || true
    gh release delete-asset "$release_tag" "$(basename "$old_file").sig" \
      --repo "$repo_name" --yes || true
    gh release delete-asset "$release_tag" "$(basename "$old_file").sha256" \
      --repo "$repo_name" --yes || true
    rm -f "$old_file" "$old_file.sig" "$old_file.sha256"
  fi
done

cp "$package_file" "$work_dir/"
gpg --batch --yes --local-user "$key_id" --detach-sign "$work_dir/$(basename "$package_file")"
sha256sum "$work_dir/$(basename "$package_file")" > \
  "$work_dir/$(basename "$package_file").sha256"

rm -f "$work_dir/${repo_db}.db"* "$work_dir/${repo_db}.files"*
repo-add --sign --key "$key_id" "$work_dir/${repo_db}.db.tar.gz" \
  "$work_dir"/*.pkg.tar.zst
cp "$work_dir/${repo_db}.db.tar.gz" "$work_dir/${repo_db}.db"
cp "$work_dir/${repo_db}.files.tar.gz" "$work_dir/${repo_db}.files"
cp "$work_dir/${repo_db}.db.tar.gz.sig" "$work_dir/${repo_db}.db.sig"
cp "$work_dir/${repo_db}.files.tar.gz.sig" "$work_dir/${repo_db}.files.sig"

gh release upload "$release_tag" --repo "$repo_name" --clobber \
  "$work_dir/$(basename "$package_file")" \
  "$work_dir/$(basename "$package_file").sig" \
  "$work_dir/$(basename "$package_file").sha256"

gh release upload "$release_tag" --repo "$repo_name" --clobber \
  "$work_dir/${repo_db}.db" \
  "$work_dir/${repo_db}.db.sig" \
  "$work_dir/${repo_db}.db.tar.gz" \
  "$work_dir/${repo_db}.db.tar.gz.sig" \
  "$work_dir/${repo_db}.files" \
  "$work_dir/${repo_db}.files.sig" \
  "$work_dir/${repo_db}.files.tar.gz" \
  "$work_dir/${repo_db}.files.tar.gz.sig"
