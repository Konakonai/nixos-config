# lilya's NixOS configuration

个人 ThinkBook 16p 的 Nix Flakes + Home Manager 配置。默认会话是 **Niri + Noctalia**，备用 **Plasma (Wayland)**。自动化修改前先读 [AGENTS.md](AGENTS.md)。

## 目录

```text
flake.nix                      inputs、overlay、nixosConfigurations.nixos、checks、packages、formatter
configuration.nix / home.nix   系统与 Home Manager 入口
hardware-configuration.nix     文件系统与基础硬件（nixos-generate-config 生成）
hosts/lilya-thinkbook/         主机事实：用户路径、显示器、GPU、外接 Windows 盘、age 身份路径
modules/system/                系统模块（boot、display、power、mihomo、services、virtualization …）
modules/home/                  用户环境（apps、desktop、niri、theme、flatpak、services …）
modules/shared/                共享主题参数（theme-settings.nix）
pkgs/                          本地包，导出为 pkgs.lilya
scripts/ + scripts/tests/      独立脚本与回归测试
checks/                        Flake checks
assets/ patches/ secrets/      静态资源、上游补丁、age 密文
```

`modules/system/default.nix` 与 `modules/home/default.nix` 显式列出导入；不做目录扫描，没有自建 `lib/`。

## 日常命令

```bash
rebuild                 # nh os switch，应用当前工作树
testbuild               # nh os test，切换但不写引导项
nix fmt                 # nixfmt 全仓
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.{configuration,lint,portal,niri-config,external-windows-cpu} --no-link
```

`checks.configuration` 跑 `scripts/tests/`（脚本失败路径、mihomo 规则顺序、KDE Connect 契约）；`lint` 跑 statix / deadnix / `nixfmt --check`；`niri-config` 用锁定的 Niri 校验最终 KDL；`portal` 与 `external-windows-cpu` 是跨模块契约。它们不等于全系统构建或图形会话测试。

本地直跑脚本测试需要 `pyyaml`（`nix build .#checks.x86_64-linux.configuration` 自带）。

## 配置所有权

原则：**Nix 提供默认层，GUI 拥有覆盖层，rebuild 不碰覆盖层**。

| 对象 | 管理方式 |
|---|---|
| Niri 主配置、快捷键、显示器、MIME、字体、GTK/Qt 主题文件 | Nix 持续管理（只读符号链接） |
| Noctalia `~/.config/noctalia/config.toml` | Nix 写入的默认层（`programs.noctalia.settings`，构建时 `noctalia config validate`） |
| Noctalia `~/.local/state/noctalia/settings.toml` | GUI 写入的覆盖层，永远优先，激活时不触碰。GUI 改回与默认相同的值时 Noctalia 自动删除该键 |
| Plasma（plasma-manager 声明的键） | 每次激活重写这些键；其余键由 Plasma 自己保存 |
| Zed `settings.json` | 首次种子，之后由 Zed 保存；Zed 没有配置分层 |
| LibreOffice 工具栏模式 | 激活时只补未配置的初始值 |
| Flatpak 应用与 Noctalia 插件 | 运行时安装/更新，不由 flake.lock 固定 |

工具：

- `config-dump noctalia` 导出合并后的用户配置；`config-drift noctalia` 显示 GUI 相对 Nix 默认层的差量（返回码 1 = 有差量，不是错误）。想把 GUI 里调好的外观变成默认值时，把差量抄进 `modules/home/noctalia.nix`。
- `config-dump zed` / `config-drift zed` 同理（解析 JSONC）。
- `config-repair noctalia-templates` 重新应用 Noctalia 模板。

主题联动：Noctalia 的调色板通过模板生成 GTK3/4、Niri（`noctalia.kdl`，可选 include）、Qt（darkly）、kitty（`~/.config/kitty/themes/noctalia.conf`，`kitty.conf` 末尾 include）。`modules/shared/theme-settings.nix` 里的色板只作为 Nix 侧默认值（starship、fastfetch、fcitx、控制台）。Noctalia 的 starship 模板无法写入 HM 管理的 `starship.toml`，不要启用。

## 会话与环境变量

- SDDM 提供 `Niri`（默认）与 `Plasma (Wayland)`；`RememberLastSession = false`。
- Niri 会话前先跑 `niri-gpu-probe`：外接屏在 NVIDIA 上时把渲染设备写进 `~/.config/niri/gpu.kdl`（可选 include），否则用 Intel 核显。
- `QT_QPA_PLATFORMTHEME=qt6ct`、`QT_WAYLAND_DECORATION`、`GSK_RENDERER` 只在 Niri 的 `environment {}` 里设置；`home.sessionVariables` 只放桌面无关变量。Plasma 用标准会话，不需要 unset 任何东西。
- `KITTY_CONF_NIRI_*` 让 kitty 只在 Niri 下隐藏装饰。

## 不在 Git 里的状态

| 状态 | 用途 |
|---|---|
| `~/.config/age/mihomo.txt` | 解密 `secrets/*.age` 的身份文件，也是整套秘密的信任根 |
| `~/.local/state/noctalia/settings.toml` | Noctalia GUI 覆盖层 |
| `~/.config/openlist/`、`~/.config/rclone/rclone.conf` | OpenList 数据与 WebDAV 凭据 |
| 浏览器 profile、应用账号 | 会话恢复 |
| libvirt NVRAM / TPM、外接 Windows 磁盘 | 虚拟机持续身份与数据 |

这些单独备份。明文凭据不进仓库。

**待办：全盘加密。** 磁盘目前未加密，上表中的一切在丢机时都是明文。它与当前引导布局冲突（256 MB ESP，`/boot-grub` 在根分区，`copyKernels = false` 让 GRUB 直接读 `/nix/store`），需要离线重分区或 GRUB cryptodisk，不能通过 rebuild 完成。

## 网络与代理

- Mihomo TUN 模式，配置由 `modules/system/mihomo/config-before-proxies.yaml` + age 密文 + `config-after-proxies.yaml` 拼接到 `/run/mihomo/config.yaml`，经 systemd credential 提供给守护进程。三者任一变化都会重启 `mihomo`（会中断当前连接）。生成器只拼接、不运行 `mihomo -t`。
- 密文里除 `proxies` 还有控制 API 的 `secret` 和 mixed 端口的 `authentication`。控制 API 绑定 `127.0.0.1:9090`，CORS 只允许自带的 metacubexd 同源，`allow-private-network` 关闭。Noctalia 的 mihomo-control 插件里的 secret 是 GUI 状态，不进 Nix。
- 7890 对局域网放行（防火墙），连接需要 `authentication` 里的账号；本机 `127.0.0.0/8` 免认证。
- 规则：STUN / IP 检测站 / 显式 pin → 各策略组的 `GEOSITE,<category>` → `.cn` 与 `GEOSITE,cn|private` 直连 → `GEOIP` → `MATCH`。`GEOSITE` 类别来自 `geox-url` 指向的 MetaCubeX geosite.dat（DNS 的 `nameserver-policy` 已依赖同一文件）。改规则后先 `mihomo -t` 校验，再看 `scripts/tests/test_mihomo_*.py` 的顺序断言。
- 主机 IPv6 关闭、STUN 走代理、外部 DNS 走代理 DoH：都是为了堵 WebRTC 泄漏。
- OpenList（5244）与 LocalSend（53317）对 LAN 开放；`refresh-openlist` 刷新目录并重挂 WebDAV。

## 本地包与更新

- `pkgs/` 里的手 pin 二进制包通过 `packages.x86_64-linux` 暴露，`nix-update --flake <name>` 可自动改版本和 hash（GitHub release 的包能自动找最新版；`antigravity` 这类需要 `--version=<v>`）。能用 nixpkgs 的就不自己 pin（eden、splayer-next 已切回 nixpkgs）。
- `codex-update` 每日检查 Codex Desktop / CLI，在临时 worktree 里构建通过后仅当主工作区未变时快进提交；不推送、不 rebuild。日志在 `~/.local/state/codex-update/update.log`。
- Flatpak 每周定时更新（接电条件），`rebuild` 不负责安装新声明的 Flatpak；需要时 `systemctl --user start flatpak-managed-install.service`。Flatpak 通过 `/nix/store:ro` 与 `~/.local/share/{themes,icons}` 的 store 符号链接读取主题。

## 电源与硬件

- power-profiles-daemon 管普通策略；电池 + 省电模式时 `power-saver-cpu` 关 turbo、限频 400–1800 MHz、PCIe ASPM powersupersave，离开该状态或服务停止即恢复。
- 合盖不休眠（s2idle 在这台机器上恢复不可靠），面板自行关闭。
- USB-C：`modules/system/usb-c.nix` 的 udev 规则与 `reset-{pch,tb}-usbc.sh` 处理 PD 事件后 mux 停在充电态的问题；脚本可用 `SYSROOT` 注入测试。
- Home Manager 在用户会话允许之后才激活，避免拖住 SDDM；冷启动后若主题未齐，注销再进一次。

## 外接 Windows 虚拟机

菜单里的 **External Windows 11** 用指定 USB 盘启动 KVM 来宾。启动器先确认磁盘拓扑与来宾状态：`virsh` / `lsblk` / `jq` 失败、磁盘不在或卸载失败都不会 `virsh start`；已运行的来宾只打开 viewer。首次启动可在来宾内运行 `SPICE_TOOLS` 光盘里的 `Install-Guest-Tools.cmd`。来宾内先关机再拔盘；宿主运行期间不要挂载该盘。来宾不暴露 VMX。
