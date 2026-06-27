# Agent Notes

本文件适用于整个 `nixos-config` 仓库。这里是用户的本机精确 NixOS 配置，不是通用模板；通用化工作应放在专门的 template/portable 分支，而不是削弱 `main` 的本机可复刻性。

## 核心原则

- 保持声明式、可复刻、可审计。不要用手动系统状态、一次性 shell hack 或未记录的本机运行态来“修好”配置。
- 先读现有结构再改。优先沿用 `hosts/`、`modules/`、`pkgs/` 里的既有模式，不为了显得通用而引入多余抽象。
- 本机特有值留在 `hosts/lilya-thinkbook/default.nix`：显示器 connector/EDID 名称、GPU/PCI/render node、电源适配器、电池路径、USB 设备、用户家目录下的服务路径。
- 不要回滚或覆盖用户/其他 agent 的未提交改动。遇到 dirty worktree 时先看清楚，只改本任务需要的文件。
- 改完 NixOS 配置后提交，除非用户明确说不要提交。

## 关键不变量

- 控制台方案是 `kmscon`，不要退回 getty。
- 登录链路是 `greetd` + `gtkgreet` + `niri`。gtkgreet 主题应保持“外屏壁纸 + 半透明登录卡”的方向。
- 默认启动使用外屏优先参数 `video=DP-2:3840x2160@60D`，不要重新改回 `video=eDP-1:d`。`internal-display-fallback` specialisation 应保留，用于无外屏/离开 dock 启动。
- niri 显示布局必须保留外屏为全局原点 `(0,0)`，这是为了修复 Steam/XWayland 游戏点击问题。内屏物理上在外屏左侧，因此应使用负坐标，例如 `eDP-1` 在 `(-1829,149)`，不要为了避免负数把内屏放到外屏右侧。
- NVIDIA/niri GPU 选择在登录时决定：接外接电源时用 NVIDIA 配置，电池时用 Intel 配置。不要做 niri 运行中 GPU 热切换。
- Codex Desktop 使用上游 `codex-desktop-computer-use-ui`。不要恢复本地 AppShot/Zed opener 补丁；Linux AppShot 无法完美复刻 macOS AppShot 时宁可不启用。
- Codex 自动更新走本仓库的 Nix 定时器：只更新 `codex-desktop-linux` 的 `flake.lock`、构建验证并提交，不自动 `switch`。不要接入上游 native `codex-update-manager`，当前 Nix/AppImage 路径没有完整 updater/service/polkit/update-builder。
- SPlayer 保留当前稳定 AppImage 包装，桌面入口由 Nix 声明式生成。除非 SPlayer-Next 有稳定 release 并验证可用，否则不要迁移。

## 补丁与硬编码

- 补丁只保留功能性修复，并在附近注释说明原因和移除条件。确认上游支持后优先删除本地补丁。
- 不要新增无必要硬编码。确实属于本机硬件/布局/secret 路径的值，放入 host profile；通用模块通过 `hostProfile` 读取。
- 不要提交运行态数据库、secret 明文、临时备份、`result` symlink 或构建产物。

## 验证要求

常规 NixOS 配置改动至少运行：

```bash
rg --files -g '*.nix' | xargs nix-instantiate --parse --quiet >/dev/null
nix flake check --no-build
nix eval .#nixosConfigurations.nixos.config.warnings --json
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link --print-out-paths
```

涉及 boot/display 时额外检查：

```bash
nix eval .#nixosConfigurations.nixos.config.boot.kernelParams --json
nix eval .#nixosConfigurations.nixos.config.specialisation --apply 's: builtins.toJSON (builtins.attrNames s)' --raw
```

涉及 niri 时，用实际 include 布局验证 Intel/NVIDIA 两份配置：

```bash
tmpdir=$(mktemp -d)
cp /nix/store/...-hm_niriconfigintel.kdl "$tmpdir/config.kdl"
cp /home/lilya/.config/niri/noctalia.kdl "$tmpdir/noctalia.kdl"
niri validate -c "$tmpdir/config.kdl"
rm -rf "$tmpdir"
```

涉及闭包变化时运行：

```bash
nvd diff /run/current-system /nix/store/<new-toplevel>
```

完成后给用户说明改了什么、验证了什么、是否需要运行 `rebuild`。不要把长 `nixos-rebuild` 命令写给用户；用户有 `rebuild` alias。
