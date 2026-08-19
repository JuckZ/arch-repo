# JuckZ Arch 软件仓库

[English](README.md) | [简体中文](README.zh-CN.md)

适用于 Arch Linux、CachyOS 及兼容发行版的签名 pacman 软件仓库。

## Codex Desktop 软件包来源

签名的 `codex-desktop` 软件包从
[`JuckZ/codex-desktop-bin`](https://github.com/JuckZ/codex-desktop-bin)
的预构建 Release 自动同步。该项目验证 OpenAI 官方签名 Linux 软件包，并使用
[`ilysenko/codex-desktop-linux`](https://github.com/ilysenko/codex-desktop-linux)
完成 Linux 打包。

本仓库用户不需要在本地构建 OpenAI 应用。同步流程会验证来源 Release
元数据和 GitHub 资产摘要，核对软件包名称、版本、架构与 SHA-256，然后使用
JuckZ 仓库密钥签名并写入 `juckz.db`。

当前软件包身份是 `codex-desktop`。它会替换旧的 `codex-desktop-bin`，但不会
删除 `~/.codex` 中的用户状态。旧的 `codex-desktop-bin` 资产仅保留用于迁移
和历史恢复。

## 启用软件仓库

导入仓库签名公钥，并在本机信任完整指纹：

```bash
curl -fLo /tmp/juckz-repo.asc \
  https://raw.githubusercontent.com/JuckZ/arch-repo/main/keys/juckz-repo.asc
sudo pacman-key --add /tmp/juckz-repo.asc
sudo pacman-key --lsign-key A36130B488E1E75604E60A9A92A815DA30F9FA93
```

信任前请核对指纹：

```text
A361 30B4 88E1 E756 04E6  0A9A 92A8 15DA 30F9 FA93
```

在 `/etc/pacman.conf` 末尾添加一次：

```ini
[juckz]
SigLevel = Required DatabaseOptional
Server = https://github.com/JuckZ/arch-repo/releases/download/repository-$arch
```

通过完整系统升级事务安装或更新：

```bash
sudo pacman -Syu juckz/codex-desktop
```

不要使用缺少 `-u` 的 `pacman -Sy`，因为 Arch Linux 不支持局部升级。配置
仓库后，日常执行 `sudo pacman -Syu` 就会随系统一起更新 Codex Desktop。

## 直接安装软件包

滚动 Release `repository-x86_64` 同时提供固定的最新版文件名。先导入上述
签名公钥，然后执行：

```bash
sudo pacman -U \
  'https://github.com/JuckZ/arch-repo/releases/download/repository-x86_64/codex-desktop-x86_64.pkg.tar.zst'
```

如果处于代理网络中，pacman 报告 `TLS connect error`，但普通 curl 可以下载，
可在 `/etc/pacman.conf` 的 `[options]` 下添加：

```ini
XferCommand = /usr/bin/curl -L --retry 5 --retry-all-errors -C - -f -o %o %u
```

## 从源码构建

如需审计或开发，仍可在本地从源码构建：

```bash
git clone https://github.com/JuckZ/codex-desktop-bin.git
cd codex-desktop-bin
./scripts/build-latest.sh
./scripts/install-local.sh
```

不要使用 `sudo` 运行 `makepkg` 或构建脚本。

## 维护与发布

`Sync prebuilt Codex Desktop` 工作流每六小时检查一次，时间比来源仓库的
定时构建晚 30 分钟。它会：

1. 解析最新的 `JuckZ/codex-desktop-bin` Release；
2. 验证来源元数据与 GitHub SHA-256 资产摘要；
3. 只下载滚动仓库中尚不存在的软件包；
4. 核对 pacman 包名、版本、架构和 SHA-256；
5. 使用现有 JuckZ 密钥签名软件包和仓库数据库；
6. 更新 `juckz.db` 与固定下载文件名。

也可以手动运行该工作流。只有确实需要重新签名并发布同一来源资产时才启用
`force`。`Publish existing artifact` 仅保留用于恢复流程。

## 致谢

感谢 [Linux.do](https://linux.do/) 社区提供的平台与交流环境，讨论与分享对本项目帮助很大。

重新分发第三方程序内容前，请阅读 [DISCLAIMER.md](DISCLAIMER.md)。
