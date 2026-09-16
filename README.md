# lilya's NixOS configuration

个人 ThinkBook 的 Nix Flakes + Home Manager 配置，同时提供 **Niri + Noctalia** 和 **Plasma Wayland**。当前默认登录会话为 `plasma-hdr`；这个名称本身不保证 HDR 已开启。

自动化修改请先读 [AGENTS.md](AGENTS.md)。待实施的后续工作见 [配置优化计划](docs/configuration-optimization-plan-2026-09-12.md)。已落地的 P1 修复与当时边界见 [2026-09-12 改进计划](docs/configuration-improvement-plan-2026-09-12.md)；[2026-09-11 审计](docs/configuration-audit-2026-09-11.md) 仅作历史记录。

## 入口与目录

```text
flake.nix                         inputs、overlay、NixOS 与 checks 输出
configuration.nix                 系统入口
home.nix                          Home Manager 入口
hardware-configuration.nix        文件系统与基础硬件配置
hosts/lilya-thinkbook/             主机、用户、设备与路径事实
modules/system/                   系统模块；user.nix 管理系统账号
modules/home/                     应用、桌面和用户服务
modules/shared/                   共享主题参数
pkgs/                             本地包与兼容包装
scripts/                          更新、状态迁移和缓存脚本
scripts/tests/                    回归测试
checks/                           Flake 检查定义
assets/、patches/                 静态资源与上游补丁
```

`modules/system/default.nix` 和 `modules/home/default.nix` 显式组织模块。当前是单机仓库，未设置自建 `lib/`；通用操作直接使用 Nixpkgs / Home Manager 的库，局部辅助函数就近定义。

## 使用与验证

从仓库目录执行：

```bash
# 求值，不更新 lock、不构建系统
nix flake check --no-build --no-update-lock-file

# 运行脚本回归、portal、Niri KDL 与虚拟机 CPU XML 检查
nix build .#checks.x86_64-linux.configuration .#checks.x86_64-linux.portal .#checks.x86_64-linux.niri-config .#checks.x86_64-linux.external-windows-cpu --no-link

# 示例：只构建一个本地包
nix build .#nixosConfigurations.nixos.pkgs.lilya.grok --no-link

# 应用当前配置；由用户执行
rebuild
```

还提供 `testbuild`（`nh os test`）。这会实际切换当前运行配置用于测试，不是只读检查。当前没有顶层 `packages` 输出，因此 `.#packages.x86_64-linux.<name>` 不是本仓库的包构建入口。

`checks` 覆盖脚本失败路径、portal 选项、最终 Niri KDL、虚拟机 CPU 拓扑，以及 Flatpak/Mihomo 的部分 systemd 契约；不等于全系统构建、图形会话测试、真实磁盘测试或所有应用配置的验证。运行前应查看检查输出，确认实际执行的目标。

Niri 下可在 Steam 的游戏属性 → 启动选项中填写 `steam-follow %command%`。启动器会把本次游戏新建的 `steam_app_<AppID>` 窗口移到启动时 Steam 所在屏幕，之后不干预手动移动；窗口首次出现时可能短暂位于另一屏。全屏游戏跨屏使用 `Super+Ctrl+Shift+←/→`，鼠标拖动仍遵循 Niri 的退出全屏行为。目标尺寸由 Niri 通知游戏，游戏内部渲染分辨率是否同步仍取决于游戏本身。Plasma 或无法取得 Steam 所在屏幕时直接启动原命令。删除该启动选项即可停用。

Steam《With Your Coworker》（AppID 4564320）是逐像素桌面挂件，启动选项为 `WINE_LAYERED_OVERLAY_ALPHA=1 %command%`；`niri-float-overlay` 负责把窗口移到浮动层，并盖住挂件的点击区。

Xwayland 会把 X11 ShapeInput 转成 `wl_surface.set_input_region`，`xwayland-satellite` 再转发给 Niri。但 satellite 在把指针坐标乘上 viewport 缩放（本机 1.5）的同时，**没有把输入区坐标除掉同一缩放**。只按 X 窗口（3840×2160）盖矩形时，Niri 会在逻辑像素（2560×1440）里命中测试，点在挂件上却打不中。`niri-float-overlay` 因此同时盖两个矩形：缓冲像素下的挂件框（Wine 收到缩放后的点击）和逻辑像素下的挂件框（Niri 把点击送给挂件）。两框之外的透明区域会穿透到下面的窗口。Proton 侧保持 `WINE_LAYERED_OVERLAY_INPUT_SHAPE=0`（写在 GE-Proton 的 `user_settings.py`，仓库外状态），避免逐像素 alpha 区在分数缩放下把点击打丢。矩形比例见脚本里的 `PET_*` 常量，取自实测的挂件+HUD 范围。

## 配置与外部状态

`flake.lock` 固定 Nix 输入，本地下载包固定源哈希。完整用户会话仍依赖不在 Git 中的状态：

| 状态 | 用途 |
|---|---|
| `~/.config/age/mihomo.txt` | 解密仓库内 age 密文的身份文件 |
| `~/.config/openlist/` | OpenList 配置与数据库 |
| `~/.config/rclone/rclone.conf` | WebDAV 挂载凭据 |
| 浏览器 profile、应用账号、用户数据 | 会话和数据恢复 |
| libvirt NVRAM / TPM 状态、外接 Windows 磁盘 | 虚拟机持续身份与系统数据 |

这些文件应单独备份恢复，不要将明文凭据提交到仓库。Git 配置、已构建包和 `/run/current-system` 是不同状态，不能用提交成功推断已经生效。

### 用户配置由谁管理

| 对象 | 当前管理方式 |
|---|---|
| Niri 主配置、主题资源、MIME | Nix 持续管理 |
| Noctalia `config.toml` | 首次创建；已有文件保留 |
| Noctalia `settings.toml` | GUI 覆盖；激活时仅当 Nix-owned 字段与种子不同才写。主题模式/色板在 Noctalia 已运行时走 CLI，其余字段仍改文件。激活后 GUI 再写回无法消除 |
| Zed `settings.json` | 首次种子，后续由应用/用户修改 |
| LibreOffice 工具栏 | 激活时补充未配置的初始值 |
| Dolphin / Plasma 部分键 | 激活时重新写入指定值 |
| Flatpak 应用和 Noctalia 插件 | 运行时安装/更新，不由 flake.lock 固定其实际版本 |

`config-dump noctalia` 导出合并后的用户配置；`config-drift noctalia` 与仓库种子按解析后的值比较，返回码 1 表示存在差异，不必然是错误。Zed 的这两个工具解析 JSONC（行/块注释），比较的是去掉注释后的值。

`config-repair noctalia-templates` 请求应用模板。Niri 把 `noctalia.kdl` 和 `gpu.kdl` 都标为 optional include：干净目录缺少颜色文件时可以启动，使用 `layout.focus-ring` 等声明式默认；Noctalia 生成颜色后覆盖这些键。损坏的已存在 include 仍会使 `niri validate` 失败。最终会话 KDL（含手写效果块和显示器段）在构建时用锁定 Niri 校验。

## 更新与服务

- `codex-update` 每日检查上游，使用临时 Git worktree 构建 Desktop/CLI，通过检查后仅在主工作区未变化时快进并本地提交。它不自动推送或执行 `rebuild`；日志位于 `~/.local/state/codex-update/update.log`。
- Codex 定时服务有接电条件。Flatpak 的手动服务和每周定时器实际目标 `flatpak-managed-install-timer.service` 都有接电条件；条件写在对应 Service 的 Unit 段，不写在 Timer 段。
- Flatpak 已关闭激活/登录时的自动安装，因此声明新增应用后，`rebuild` 本身不负责立即下载安装。接电后可按需执行 `systemctl --user start flatpak-managed-install.service`，或等待每周任务。
- Mihomo 使用 age 密文拼接 `/run/mihomo/config.yaml`，再通过 systemd credential 提供给守护进程。前/后片段或密文源变化会进入 `mihomo` 与 `mihomo-config` 的 restartTriggers。生成器只拼接、不运行 `mihomo -t`。应用配置后代理会重启，可能中断当前连接。
- 正常功耗策略由 power-profiles-daemon / UPower 管理；电池且省电模式时，单独服务禁用 Intel turbo，并将 CPU 频率限制为 400–1800 MHz；离开该状态或服务停止时恢复原值。自动休眠的既有规避配置保留。
- Home Manager 在用户会话启用之后才激活，以免拖住登录界面。冷启动后若主题或快捷键尚未写完，注销再进入一次即可。
- KDE Connect：电脑网络变化由 NetworkManager dispatcher 立刻 `--refresh`；两分钟定时器仅在没有可达设备时广播，用于手机自己切网。

## 外接 Windows 虚拟机

菜单中的 **External Windows 11** 使用指定 USB 磁盘运行 KVM/libvirt 来宾。启动器先成功采集磁盘拓扑和来宾状态，再决定卸载或启动：`virsh`/`lsblk`/`jq` 失败、磁盘消失或卸载失败时不会调用 `virsh start`。已启动来宾只打开 viewer。`virsh start` 前会再探测一次挂载；启动失败且磁盘又被挂上时不会重试 start。两次探测之间仍可能被其他进程重新挂载，这不是对所有挂载工具的互斥。

首次启用 `libvirtd` 用户组后需重新登录。首次虚拟启动可在 Windows 内以管理员身份运行 `SPICE_TOOLS` 光盘中的 `Install-Guest-Tools.cmd`，随后重启来宾，以使用动态分辨率与剪贴板。

先在来宾内关闭 Windows，再拔盘或原生启动；运行期间不要在宿主挂载该盘的文件系统。当前禁用来宾 VMX 暴露，虚拟机内不提供 Hyper-V/WSL2 的嵌套虚拟化路径。NVRAM、TPM 状态和 Windows 数据不应作为可随意删除的生成缓存处理。
