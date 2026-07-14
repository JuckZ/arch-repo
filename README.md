# JuckZ Arch Repository

[English](README.md) | [简体中文](README.zh-CN.md)

Signed custom pacman repository and inspectable PKGBUILD collection for Arch
Linux and compatible distributions.

## Recommended project

This repository is based on and refers to
[ilysenko/codex-desktop-linux](https://github.com/ilysenko/codex-desktop-linux).
We recommend that most users use that project directly.

This repository is maintained primarily for personal use and only adapts the
packaging and distribution workflow for Arch Linux. The referenced project is
the more appropriate starting point if you want the general Linux conversion
workflow, broader distribution support, or upstream implementation details.

Initial packages:

- `codex-desktop`: builds locally from the official Codex DMG and a pinned
  `codex-desktop-linux` commit.
- `codex-desktop-bin`: installs the corresponding prebuilt package quickly.

The packages conflict and cannot be installed together.

The optional upstream update manager is disabled by default because its current
Rust native dependencies do not link reliably in the Arch build container. The
desktop application remains installable and Codex CLI updates are independent
of this optional component. Maintainers can re-enable it from the workflow
input after upstream compatibility is restored.

Some upstream revisions may report a native linker failure for the Linux
Computer Use backend in the Arch container. The desktop application and normal
Codex/CLI integration are still packaged, but Computer Use can be unavailable
until the upstream native-linking issue is resolved.

## Enable the repository

Import and locally trust the repository signing key:

```bash
curl -fLo /tmp/juckz-repo.asc \
  https://raw.githubusercontent.com/JuckZ/arch-repo/main/keys/juckz-repo.asc
sudo pacman-key --add /tmp/juckz-repo.asc
sudo pacman-key --lsign-key A36130B488E1E75604E60A9A92A815DA30F9FA93
```

Verify the fingerprint before trusting it:

```text
A361 30B4 88E1 E756 04E6  0A9A 92A8 15DA 30F9 FA93
```

Append this section to `/etc/pacman.conf` once:

```ini
[juckz]
SigLevel = Required DatabaseOptional
Server = https://github.com/JuckZ/arch-repo/releases/download/repository-$arch
```

Install with pacman:

```bash
sudo pacman -Syu juckz/codex-desktop-bin
```

Install with paru:

```bash
paru -S juckz/codex-desktop-bin
```

Install with yay:

```bash
yay -S juckz/codex-desktop-bin
```

## Direct package installation

The rolling `repository-x86_64` Release provides stable direct-download names.
Import the signing key first, then install the latest prebuilt package:

```bash
sudo pacman -U \
  'https://github.com/JuckZ/arch-repo/releases/download/repository-x86_64/codex-desktop-bin-x86_64.pkg.tar.zst'
```

The locally-built channel is also available as a versioned asset named
`codex-desktop-<version>-x86_64.pkg.tar.zst`.

If pacman reports `TLS connect error` on a proxied network while ordinary curl
downloads work, add this under `[options]` in `/etc/pacman.conf`:

```ini
XferCommand = /usr/bin/curl -L --retry 5 --retry-all-errors -C - -f -o %o %u
```

## Build from a PKGBUILD

```bash
git clone https://github.com/JuckZ/arch-repo.git
cd arch-repo/packages/codex-desktop
makepkg -si
```

For the prebuilt recipe:

```bash
cd arch-repo/packages/codex-desktop-bin
makepkg -si
```

Never run `makepkg` with `sudo`.

## Maintainer publishing

### Daily automatic update

The `Check and publish new Codex DMG` workflow runs every day at **06:00
Asia/Shanghai** (`22:00 UTC`). It:

1. checks the upstream DMG ETag, modification time, and content length;
2. downloads the DMG only when its remote fingerprint changes;
3. verifies the complete SHA256 and reads the application version from
   `Info.plist`;
4. builds and signs `codex-desktop` and `codex-desktop-bin`;
5. refreshes the `juckz` pacman database and stable direct-download aliases;
6. commits the new pinned versions and checksums back to `main`.

The workflow can also be started manually. Enable `force` only when the same
DMG payload needs to be rebuilt deliberately.

### Manual publishing

The `Build and publish package` workflow has publishing enabled by default.
It builds as an unprivileged user, signs the package, updates the `juckz`
database, and publishes everything to the fixed `repository-x86_64` Release.

See [DISCLAIMER.md](DISCLAIMER.md) before redistributing third-party payloads.
