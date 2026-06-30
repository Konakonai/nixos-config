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

### Qoder CN desktop entries

`pkgs/qoder-cn.nix` 已经安装并修正 upstream 自带的 `qoder-cn.desktop` 和 `qoder-cn-url-handler.desktop`，因此删除了 `modules/desktop/entries.nix` 里的同名 Home Manager desktop entries。

### Codex Desktop entry

`modules/codex.nix` 的 wrapper 阶段已经能修正 upstream `codex-desktop.desktop` 的 `Exec` 路径。现在同时在 wrapper 阶段删除 upstream 里不可用的 `/usr/bin/codex-update-manager` update actions，并删除后续同名 Home Manager desktop entry，避免同一个 desktop 文件在两个层级重复生成。

## 功能语义审计

这轮审计重点不是“同一个文件出现两次”，而是检查不同模块是否在实现同一类功能。

### 授权与提权

- `security.polkit.extraConfig` 在 `modules/system/display/desktop-services.nix` 中只处理 udisks 本地挂载/卸载授权，目标是图形文件管理器和 udisks。
- `security.sudo.extraConfig = "Defaults pwfeedback"` 只改变 sudo 密码输入反馈，不授权新能力。
- `programs.ssh.askPassword`、`GIT_ASKPASS` 和 `ksshaskpass` 在 `modules/system/programs.nix` 中服务于 SSH/Git 图形密码提示。
- `programs.yazi` 的 sudo plugin 只是在 Yazi 内部执行需要提权的文件操作入口。

结论：授权方向没有发现 Polkit、sudo、askpass 互相重复实现同一件事。它们分别覆盖 udisks/polkit、sudo TTY 行为、SSH/Git askpass、Yazi 内部操作。

### Portal、Flatpak 与主题可见性

- `xdg.portal` 在 `modules/system/display/desktop-services.nix` 中选择 GTK portal 和 file chooser backend。
- `modules/flatpak.nix` 管理 Flatpak 应用、sandbox override 和 Flatpak 环境变量。
- `modules/theme/flatpak-assets.nix` 把主题/icon 复制到 Flatpak 可读的用户目录。

结论：这三块都和 Flatpak/portal 体验有关，但边界清楚：portal backend、sandbox policy、sandbox-readable assets，不是重复实现。

### 桌面会话与 Niri 配置

- `modules/system/display/login.nix` 启用系统级 Niri/greetd/gtkgreet login session。
- `modules/niri/*.nix` 生成用户级 Niri 配置、bindings 和多输出配置。
- `modules/system/display/console.nix` 与 `modules/system/services.nix` 中的 kmscon 配置只处理虚拟控制台。

结论：登录会话、用户 compositor 配置、TTY console 是三层不同功能，没有发现重复 session 管理。

### 主题、环境变量与渲染

- GTK/Qt/cursor/dconf 分别在 `modules/theme/*.nix` 中管理不同 toolkit 的配置文件。
- `home.sessionVariables`、`programs.niri.settings.environment`、Flatpak overrides 中重复设置的 `GSK_RENDERER=ngl`、`GTK_USE_PORTAL=1`、Wayland/Electron 变量，是为了覆盖 shell、niri 启动应用和 Flatpak sandbox 三个入口。

结论：这里存在刻意重复，不建议合并成单点；单点设置覆盖不了所有启动路径。

### Desktop entry 覆盖

- Loupe/font-viewer 覆盖是为了关闭 `DBusActivatable` 并确保 `Exec` 可直接启动。
- Zen 覆盖是为了使用 `launch-zen-beta` 处理重复窗口/session restore。
- Yazi 覆盖是为了用 kitty 包裹 terminal file manager。
- Zed 覆盖是为了补充 MIME 类型和绝对路径 `Exec`。
- Qt6 Settings 覆盖是为了 `NoDisplay=true`，隐藏菜单项。

结论：这些同名 `.desktop` 覆盖不是语义重复；它们是对 upstream desktop 文件的行为修正。已处理的 Qoder/Codex 属于可以收敛的重复表达。

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
