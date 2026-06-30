# 配置审计处理记录

审计时间：2026-06-30

本文件记录 2026-06-30 审计后已经处理的遗留配置，以及确认需要保留的项目。

## 已处理

### NTFS 支持与只读 udisks 策略

机器当前没有 NTFS 文件系统，因此删除了相关配置：

- `modules/system/display/desktop-services.nix` 不再读取 `hostProfile.storage.readOnlyNtfsVolumes`。
- 删除了 `udisks2/mount_options.conf` 的 NTFS 只读生成逻辑。
- 删除了显式安装的 `pkgs.ntfs3g`。
- `modules/system/boot.nix` 不再设置 `boot.supportedFilesystems.ntfs = true`。

### `internal-display-fallback` specialisation

显示切换现在通过 gtkgreet 里的 Niri session 选择完成，不再通过 GRUB/kernel param fallback 完成，因此删除了：

- `hostProfile.boot.preferredDisplayParam` 的读取逻辑。
- `internal-display-fallback` specialisation。
- 对主 kernel params 做过滤后生成 fallback 的逻辑。

当前保留的 specialisation 只有 `battery-saver`。

### 外部截图工具

当前截图快捷键使用 niri 原生 action：

- `Mod+Shift+S`: `screenshot`
- `Print`: `screenshot`
- `Ctrl+Print`: `screenshot-screen`
- `Alt+Print`: `screenshot-window`

已删除未启用的外部截图工具包：

- `swappy`
- `grim`
- `slurp`

### 本地空 Kvantum 目录

删除了工作区里的空目录：

- `assets/kvantum/`
- `assets/kvantum/KvNordLight/`

这些目录原本没有被 Git 跟踪，不影响提交内容。

## 确认保留

### agenix / `age` option namespace

`age` 不是一套独立的旧配置，而是 agenix NixOS module 暴露出来的 option namespace。当前 mihomo 代理 secret 仍依赖它：

- `flake.nix` 引入 `agenix.nixosModules.default`。
- `modules/system/mihomo.nix` 使用 `age.identityPaths` 和 `age.secrets.mihomo-proxies`。
- `secrets/mihomo-proxies.yaml.age` 仍是加密代理配置来源。
- `mihomo-config` service 通过 `/run/agenix/mihomo-proxies` 生成运行时 `/run/mihomo/config.yaml`。

因此不删除 `agenix` input，也不删除 `modules/system/mihomo.nix` 里的 `age = { ... };`。`README.md` 已把外部状态描述从 `age identity` 改成 `agenix identity`，避免把 agenix 的 option namespace 误解成另一个应删除的系统。

### 仍在使用的历史 workaround

这些不是本次清理目标，仍与当前配置一致：

- QQ Flatpak XWayland override：`modules/flatpak.nix` 仍通过 X11 socket 和 `qq-flags.conf` 修复 QQ 剪贴板路径。
- GTK4 `GSK_RENDERER=ngl`：`modules/theme/environment.nix`、`modules/niri/core.nix`、`modules/flatpak.nix` 仍用于 GTK4/NVIDIA/niri 渲染稳定性。
- `battery-saver` specialisation：`modules/system/power.nix` 仍实际生成并用于省电启动项。
