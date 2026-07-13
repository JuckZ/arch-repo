# JuckZ Arch Repository

Signed custom pacman repository and inspectable PKGBUILD collection for Arch
Linux and compatible distributions.

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

Versioned packages are available from the `repository-x86_64` Release. Import
the signing key first, then use the exact asset URL shown on the Release page:

```bash
sudo pacman -U \
  'https://github.com/JuckZ/arch-repo/releases/download/repository-x86_64/codex-desktop-2026.07.13.a8dbcb95-1-x86_64.pkg.tar.zst'
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

The `Build and publish package` workflow has publishing enabled by default.
It builds as an unprivileged user, signs the package, updates the `juckz`
database, and publishes everything to the fixed `repository-x86_64` Release.

See [DISCLAIMER.md](DISCLAIMER.md) before redistributing third-party payloads.
