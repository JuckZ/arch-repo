#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_name="${1:?usage: build-package.sh <package-name>}"
package_dir="${repo_root}/packages/${package_name}"

if [[ ! -f "${package_dir}/PKGBUILD" ]]; then
  printf 'Unknown package: %s\n' "${package_name}" >&2
  exit 1
fi

cd "${package_dir}"
makepkg --cleanbuild --syncdeps --noconfirm --needed

