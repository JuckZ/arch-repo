# JuckZ Arch 软件仓库

[English](README.md) | [简体中文](README.zh-CN.md)

这是一个适用于 Arch Linux 及其兼容发行版的签名 pacman 软件仓库，同时提供可审查的 PKGBUILD。

## 推荐项目

本仓库参考并基于
[ilysenko/codex-desktop-linux](https://github.com/ilysenko/codex-desktop-linux)，推荐大多数用户优先使用该项目。

本仓库主要用于个人使用，仅针对 Arch Linux 的软件包构建和分发流程进行了适配。如果你需要通用的 Linux 转换流程、更广泛的发行版支持，或者希望了解上游实现细节，建议直接从该参考项目开始。

当前包含：

- `codex-desktop`：从官方 Codex DMG 和固定版本的 `codex-desktop-linux` 在本地构建。
- `codex-desktop-bin`：快速安装对应的预构建软件包。

两个软件包互相冲突，不能同时安装。

上游可选更新管理器的 Rust 原生依赖目前无法在 Arch 构建容器中稳定链接，因此默认关闭。桌面应用仍可正常打包，Codex CLI 的更新也不依赖该组件。

部分上游版本还可能出现 Linux Computer Use 后端的原生链接错误。桌面主体和常规 Codex/CLI 集成仍会打包，但 Computer Use 功能可能暂时不可用。

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

使用 pacman 安装：

```bash
sudo pacman -Syu juckz/codex-desktop-bin
```

使用 paru 安装：

```bash
paru -S juckz/codex-desktop-bin
```

使用 yay 安装：

```bash
yay -S juckz/codex-desktop-bin
```

## 直接安装软件包

滚动 Release `repository-x86_64` 提供固定的最新版下载地址。先导入上面的签名公钥，然后执行：

```bash
sudo pacman -U \
  'https://github.com/JuckZ/arch-repo/releases/download/repository-x86_64/codex-desktop-bin-x86_64.pkg.tar.zst'
```

本地构建版本对应的固定文件名为：

```text
codex-desktop-x86_64.pkg.tar.zst
```

如果处于代理网络中，pacman 报告 `TLS connect error`，但普通 curl 可以下载，可在 `/etc/pacman.conf` 的 `[options]` 下添加：

```ini
XferCommand = /usr/bin/curl -L --retry 5 --retry-all-errors -C - -f -o %o %u
```

## 从 PKGBUILD 构建

```bash
git clone https://github.com/JuckZ/arch-repo.git
cd arch-repo/packages/codex-desktop
makepkg -si
```

使用预构建配方：

```bash
cd arch-repo/packages/codex-desktop-bin
makepkg -si
```

不要使用 `sudo makepkg`。

## 维护与发布

### 每日自动更新

`Check and publish new Codex DMG` 工作流每天在北京时间 **06:00**（UTC 22:00）运行，自动完成：

1. 检查上游 DMG 的 ETag、修改时间和文件大小；
2. 仅在远程指纹发生变化时下载 DMG；
3. 校验完整 SHA256，并从 `Info.plist` 读取应用版本；
4. 构建并签名 `codex-desktop` 和 `codex-desktop-bin`；
5. 更新 `juckz` pacman 数据库和固定下载地址；
6. 将新的固定版本、校验值和 DMG 状态提交回 `main`。

也可以手动运行该工作流。只有需要对相同 DMG 强制重新构建时才启用 `force`。

### 手动发布

`Build and publish package` 工作流默认启用发布。它以普通用户构建软件包，完成签名，更新 `juckz` 数据库，并发布到固定的 `repository-x86_64` Release。

重新分发第三方程序内容前，请阅读 [DISCLAIMER.md](DISCLAIMER.md)。
