#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import re
import sys


def replace_line(path: Path, pattern: str, replacement: str) -> None:
    content = path.read_text()
    updated, count = re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Could not update {pattern!r} in {path}")
    path.write_text(updated)


def normalize_pkgver(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9+_.]+", ".", value.strip())
    value = re.sub(r"\.{2,}", ".", value).strip(".")
    if not value:
        raise SystemExit("DMG application version cannot be converted to an Arch pkgver")
    return value


def main() -> None:
    if len(sys.argv) not in (4, 5):
        raise SystemExit(
            "usage: update-package-metadata.py <repo-root> <candidate-json> "
            "<wrapper-commit> [source-package-sha256]"
        )

    repo_root = Path(sys.argv[1]).resolve()
    candidate_path = Path(sys.argv[2]).resolve()
    wrapper_commit = sys.argv[3].strip()
    source_package_sha256 = sys.argv[4].strip() if len(sys.argv) == 5 else ""
    if not re.fullmatch(r"[0-9a-f]{40}", wrapper_commit):
        raise SystemExit(f"Invalid wrapper commit: {wrapper_commit}")

    candidate = json.loads(candidate_path.read_text())
    dmg_sha256 = str(candidate["sha256"])
    if not re.fullmatch(r"[0-9a-f]{64}", dmg_sha256):
        raise SystemExit(f"Invalid DMG SHA256: {dmg_sha256}")

    app_version = normalize_pkgver(str(candidate["app_version"]))
    pkgver = f"{app_version}.d{dmg_sha256[:8]}.g{wrapper_commit[:8]}"
    source_pkgbuild = repo_root / "packages/codex-desktop/PKGBUILD"
    binary_pkgbuild = repo_root / "packages/codex-desktop-bin/PKGBUILD"

    for path in (source_pkgbuild, binary_pkgbuild):
        replace_line(path, r"^pkgver=.*$", f"pkgver={pkgver}")
        replace_line(path, r"^pkgrel=.*$", "pkgrel=1")

    replace_line(
        source_pkgbuild,
        r"^_wrapper_commit='[^']*'$",
        f"_wrapper_commit='{wrapper_commit}'",
    )
    replace_line(
        source_pkgbuild,
        r"^_dmg_sha256='[^']*'$",
        f"_dmg_sha256='{dmg_sha256}'",
    )

    if source_package_sha256:
        if not re.fullmatch(r"[0-9a-f]{64}", source_package_sha256):
            raise SystemExit(f"Invalid source package SHA256: {source_package_sha256}")
        replace_line(
            binary_pkgbuild,
            r"^_source_sha256='[^']*'$",
            f"_source_sha256='{source_package_sha256}'",
        )
        candidate["source_package_sha256"] = source_package_sha256

    candidate["wrapper_commit"] = wrapper_commit
    candidate["package_version"] = pkgver
    candidate_path.write_text(json.dumps(candidate, indent=2, ensure_ascii=False) + "\n")
    print(pkgver)


if __name__ == "__main__":
    main()

