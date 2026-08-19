# JuckZ Arch Repository

[English](README.md) | [简体中文](README.zh-CN.md)

Signed custom pacman repository for Arch Linux, CachyOS, and compatible
distributions.

## Codex Desktop package source

The signed `codex-desktop` package is synchronized from prebuilt releases of
[`JuckZ/codex-desktop-bin`](https://github.com/JuckZ/codex-desktop-bin). That
project verifies OpenAI's signed official Linux package and uses
[`ilysenko/codex-desktop-linux`](https://github.com/ilysenko/codex-desktop-linux)
as its packaging implementation.

Users of this repository do not build the OpenAI application locally. The
synchronization workflow verifies the source Release metadata and GitHub asset
digest, checks the package name, version, architecture, and SHA-256, signs the
package with the JuckZ repository key, and publishes it in `juckz.db`.

The current package identity is `codex-desktop`. It replaces the legacy
`codex-desktop-bin` package without deleting user state under `~/.codex`. Old
`codex-desktop-bin` assets remain only for migration and historical recovery.

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

Install or update safely with a complete system upgrade transaction:

```bash
sudo pacman -Syu juckz/codex-desktop
```

Do not use `pacman -Sy` without `-u`; Arch Linux does not support partial
upgrades. Once the repository is configured, ordinary `sudo pacman -Syu`
updates Codex Desktop with the rest of the system.

## Direct package installation

The rolling `repository-x86_64` Release also provides a stable direct-download
name. Import the signing key first, then install:

```bash
sudo pacman -U \
  'https://github.com/JuckZ/arch-repo/releases/download/repository-x86_64/codex-desktop-x86_64.pkg.tar.zst'
```

If pacman reports `TLS connect error` on a proxied network while ordinary curl
downloads work, add this under `[options]` in `/etc/pacman.conf`:

```ini
XferCommand = /usr/bin/curl -L --retry 5 --retry-all-errors -C - -f -o %o %u
```

## Build from source

Local source building remains available for auditing and development:

```bash
git clone https://github.com/JuckZ/codex-desktop-bin.git
cd codex-desktop-bin
./scripts/build-latest.sh
./scripts/install-local.sh
```

Never run `makepkg` or the build script with `sudo`.

## Maintainer publishing

The `Sync prebuilt Codex Desktop` workflow checks every six hours, 30 minutes
after the source repository's scheduled build. It:

1. resolves the latest `JuckZ/codex-desktop-bin` Release;
2. validates its provenance metadata and GitHub SHA-256 asset digest;
3. downloads only a package not already present in the rolling repository;
4. verifies the pacman name, version, architecture, and package SHA-256;
5. signs the package and repository database with the existing JuckZ key;
6. refreshes `juckz.db` and the stable direct-download alias.

The workflow can also be started manually. Enable `force` only to sign and
republish an identical source asset deliberately. `Publish existing artifact`
remains available for recovery workflows.

## Acknowledgements

Thanks to the [Linux.do](https://linux.do/) community for providing a platform
and welcoming environment for discussion. Its discussions and sharing have
been a great help to this project.

See [DISCLAIMER.md](DISCLAIMER.md) before redistributing third-party payloads.
