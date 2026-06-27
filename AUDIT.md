# NixOS 配置历史审计与修复记录

日期：2026-06-25

范围：审阅 `/home/lilya/nixos-config`，结合当时配置、git 历史、boot 日志，以及你补充的意图说明。本文是历史记录；当前状态以仓库配置和 README 复刻清单为准。

## 2026-06-27 当前状态更新

- `zramSwap.enable = true`，当前系统有 zram swap。
- `services.kmscon.enable = true` 是最终目标，不再按“临时禁用 kmscon”处理。
- 本机硬件、显示器、GPU、AC/BAT 和用户路径硬编码已集中到 `hosts/lilya-thinkbook/`。
- 登录时按 AC 状态选择 niri Intel/NVIDIA 配置；运行中不做 GPU 热切换。

## 2026-06-25 当时已确认事实

- 当前系统 generation：269，NixOS `26.05.20260608.bd0ff2d`，kernel `7.0.11`。
- `nix flake check --no-build` 曾通过，说明当前配置不是基础语法或普通 option 求值失败。
- 当时启动使用 dGPU 直连路径：Niri 从 `/home/lilya/.config/niri/config-nvidia.kdl` 加载，并使用 `/dev/dri/renderD128` 作为 render node。
- 历史状态：当时系统没有 swap，后续已改为 zram swap。
- OpenList 端口开放是有意行为，不再作为错误处理。
- NVIDIA 电源切换被关闭是有意的临时止血：动态切换阶段确实出现过连续 OOM。

## 本次已实施修复

1. Fcitx：移除 Home Manager 侧的重复 daemon 和重复包管理，只保留系统侧 `i18n.inputMethod` 负责启动，Home Manager 继续保留用户配置和 Flatpak 兼容环境变量。
2. OOM：新增 `modules/system/memory.nix`，启用 zram swap 作为 Electron/Niri/Noctalia 突发内存压力缓冲；不恢复 NVIDIA 动态切换。
3. 外设延迟：关闭全局 `powertop --auto-tune`，并给 Razer 鼠标、Telink 键盘、VIA hub 添加 USB autosuspend 禁用规则。
4. kmscon：历史上曾建议临时禁用用于 A/B 验证；当前策略是保留 kmscon，并把配置整理为最终路径。
5. gtkgreet：调整 greeter 输出名、字体、宽度、padding、圆角和阴影比例，让登录界面更克制，并减少多显示器命名漂移。
6. 主题：删除未启用的旧 Nordic/Kvantum 字段和 `KvNordLight` 资产。
7. Zen：保留禁止 session/crash restore 的重复窗口修复，但改用 Zen profile 声明式配置，而不是直接覆盖随机 profile 下的 `user.js`。
8. 维护项：加固 Mihomo 临时文件清理，修 desktop entry 绝对路径，修 Antigravity 构建目录和 `mainProgram`，补 OpenList/Flatpak/dGPU-only 注释，并修正 `configuration.nix` 属主。

## 仍需重启后验证

1. Fcitx 日志里应只剩一个 `fcitx5` 实例，且不再有 duplicate `org.fcitx.Fcitx5`。
2. `zramctl` 或 `swapon --show` 应显示 zram swap；后续观察是否还出现 OOM kill。
3. 鼠标静置后应无需点击即可移动，键盘连续输入应更顺滑。
4. 外接显示器上的开机控制台/自检应回到普通 getty 表现；若仍异常，再查 boot framebuffer、NVIDIA DRM 和输出选择。
5. gtkgreet 在内屏和外屏上的比例需要肉眼确认；这类 UI 问题最终仍以实际登录界面为准。

## 高优先级

### Fcitx 现在确实是双启动

文件：

- `modules/system/localization.nix`
- `modules/fcitx5.nix`

证据：

- NixOS `i18n.inputMethod` 在 `modules/system/localization.nix:19-37` 启用了 Fcitx 5。
- Home Manager 又在 `modules/fcitx5.nix:33-50` 安装同类包并启动 `fcitx5 --replace`。
- 当前 boot 日志中 `fcitx5[2703]` 和 `fcitx5[2675]` 同时启动。
- 前一 boot 中也有两个 Fcitx 实例竞争，随后其中一个卸载 addon 退出。
- DBus 日志反复出现 duplicate `org.fcitx.Fcitx5` service file。

影响：

这会造成输入法启动顺序不稳定、DBus 名称竞争、环境变量诊断不一致，以及偶发输入状态异常。它是实锤问题，应该优先修。

建议修法：

- 只保留一个 daemon owner。
- 推荐方案：让 NixOS `i18n.inputMethod` 负责 daemon 和 addons；Home Manager 只保留用户配置、Rime 图标、Flatpak 输入法兼容 env。
- 如果 Niri 下需要等 Wayland socket，则反过来保留 Home Manager 用户服务，但要关闭 NixOS 自动启动路径，并写明原因。
- 修完后检查日志里只剩一个 `fcitx5` 实例，且没有 duplicate `org.fcitx.Fcitx5`。

### OOM 根因要先处理，暂时不要恢复 NVIDIA 动态切换

文件：

- `modules/system/power.nix`
- `modules/system/graphics.nix`
- `modules/niri/effects.nix`
- `modules/system/display/login.nix`

证据：

- git 历史显示 `b7aacf9 feat(power): configure dynamic GPU switching and system energy saving` 之后出现多轮 OOM。
- `3cd17a4 fix(dgpu): configure login and power for dgpu-only mode...` 把系统改成 dGPU-only 止血。
- 日志里在 2026-06-25 17:17-17:21 多次 OOM kill，目标包括 `noctalia`、`niri`、`electron`、`Xwayland`。
- 2026-06-25 18:37 也有 `noctalia` 与 `niri` 被 OOM kill。
- 当前系统没有 swap/zram，`systemd-oomd` 每次启动都会提示 `No swap; memory pressure usage will be degraded`。

影响：

之前把 NVIDIA 切换逻辑关掉不是单纯 bug，而是为了避免动态切换/混合渲染期间的 OOM 和会话崩溃。现在不应该简单恢复“插电 on、电池 auto”的切换逻辑，否则可能重现 Niri/Noctalia/Electron 被杀。

建议修法：

- 第一阶段保留 dGPU-only，不恢复动态切换。
- 先启用 zram swap，例如 `zramSwap.enable = true` 并设置合理内存比例，给 Electron/Niri/Noctalia 突发内存压力留缓冲。
- 保留当前 NVIDIA 直连 profile，但把 `nvidia-power-control` 的脚本文案改清楚：它现在不是动态切换器，而是 dGPU-only 保活/诊断工具。
- 等 OOM 不再复现后，再单独做“Intel/hybrid/dGPU 三 profile”实验，不和其他修复混在一起。

### 外设延迟和冻结优先怀疑 USB autosuspend / powertop

文件：

- `modules/system/power.nix`

证据：

- `powerManagement.powertop.enable = true`。
- 当前 USB 状态显示 Razer Basilisk V3 和 Telink Wireless Gaming Keyboard 都是 `power=auto`，`autosuspend_delay_ms=2000`。
- 前一 boot 中 `powertop` 启动后，Razer 鼠标发生重新枚举。
- 当前和前一 boot 都有 Niri/libinput 日志：`event processing lagging behind`，涉及 Razer 鼠标和 Telink 键盘。
- Telink 键盘枚举阶段出现过 `usb 3-9: device descriptor read/64, error -71`。

影响：

你描述的“鼠标经常被冻结，要点击一下才能移动，键盘也不顺滑”非常像 HID 设备被 autosuspend 后唤醒不顺，或者 Niri 主线程在某些时刻处理输入事件延迟。现在最可疑的是 `powertop --auto-tune` 把 HID 设备设为自动挂起。

建议修法：

- 第一选择：关闭全局 `powerManagement.powertop.enable`，观察鼠标/键盘是否恢复。
- 如果仍想保留 powertop：加 udev 规则，只对 Razer `1532:0099`、Telink `320f:5088`、相关 VIA USB hub 禁用 autosuspend。
- 同时保留 Niri/libinput 日志观察；如果禁用 HID autosuspend 后仍有 `processing lagging behind`，再查 Niri 渲染压力和 dGPU frame pacing。

### kmscon 外接显示器显示问题需要单独迁移/回退

文件：

- `modules/system/services.nix`
- `modules/system/display/console.nix`

证据：

- `services.kmscon.enable = true`，`hwRender = true`，并设置了 `multi-monitor=largest`。
- 当前 `systemctl list-unit-files` 显示 `kmsconvt@.service` 已启用，`autovt@tty1.service` 被 masked。
- 直接求值 `config.services.kmscon` 会触发 Nixpkgs 里已移除的 `services.kmscon.autologinUser` 兼容错误；这提示 kmscon 模块在当前 Nixpkgs 版本上存在迁移痕迹。
- 你反馈开机自检/kmscon 在外接显示器上无法全屏，且上一个或上上个 generation 没有。

影响：

kmscon 在多显示器、高 DPI、dGPU 直连、GRUB framebuffer/NVIDIA DRM 组合下很容易出现输出选择或缩放异常。当前问题不一定是配置一行写错，更像 kmscon 与当前显示栈组合的回归。

建议修法：

- 先做保守回退：临时禁用 `services.kmscon`，回到普通 getty，确认外接显示器自检/TTY 是否恢复正常全屏。
- 如果必须保留 kmscon，再尝试去掉 `multi-monitor=largest` 或关闭 `hwRender` 分别验证。
- 把 kmscon 修复和 gtkgreet UI 修复分开做，避免控制台问题和登录界面问题混在一起。

### gtkgreet 登录界面比例不够优雅

文件：`modules/system/display/login.nix`

证据：

- gtkgreet CSS 当前硬编码 `font-size: 15px`、`padding: 34px`、`min-width: 360px`。
- greetd 里运行 sway greeter，并硬编码了 `eDP-1 scale 1.75 pos 0 149` 和 `DP-5 scale 1.5 pos 1829 0`。
- 实际 Niri 日志里外接显示器 connector 是 `DP-2`，而 greetd sway config 仍写 `DP-5`。

影响：

登录界面和实际会话的输出命名/布局不完全一致，高 DPI 下固定 min-width/padding/font 很容易显得比例怪。外接屏连接路径变化时，`DP-5` 这种名字也可能失效。

建议修法：

- 把 greeter 输出配置集中成可维护变量，至少跟当前 Niri 输出命名对齐。
- UI 上改成更克制的比例：更大的整体容器但更小的 padding，减少阴影和圆角，字体跟 scale 更协调。
- 避免在 C patch、CSS、sway config 中散落主题常量；让它们从 `lilyaGlass` 或登录模块局部变量统一派生。

## 中优先级

### Zen Browser 的重复窗口修复需要保留，但当前方式太硬

文件：`modules/home/zen.nix`

背景：

你说明这个配置是为了解决 prefs/session 导致每次启动打开两个一模一样窗口的问题。这个目标是合理的，不能简单删除。

历史现状：

- 当前把 `user.js` 写到 `zen/i41yvfec.Default Profile/user.js`。
- `force = true` 会强制覆盖该 profile 的本地修改。
- prefs 禁用了 crash/session restore 相关行为。

影响：

这个修复能止血，但绑定了随机 profile ID。以后 Zen 换 profile 或新建 profile 时，修复可能静默失效。

建议修法：

- 保留“禁用 session/crash restore，避免重复窗口”的 prefs。
- 改成更声明式的 profile 管理：优先用 Zen/Firefox policies 或 Home Manager 可识别的 profile 机制。
- 如果上游模块暂时不支持，就至少把 profile ID 抽成局部变量并加注释，说明它是为修重复窗口保留的。

### Mihomo secret 管理已迁到 agenix

文件：`modules/system/mihomo.nix`

现状：

- `mihomo-proxies.yaml.age` 由 agenix 解密到 `/run/agenix`。
- `mihomo-config.service` 在 `mihomo.service` 前生成 runtime `config.yaml`。
- 最终配置仍由公开的 before/after 片段和 secret proxy 片段拼接，避免把完整代理配置写进仓库。

注意：

- `/home/lilya/.config/age/mihomo.txt` 仍是本机外部状态，需要在复刻机器时恢复。
- 如果以后 secret 数量增多，或需要结构化编辑多个 YAML/JSON secret，再考虑迁到 sops-nix。

后续可选：

- 把通用 secret identity 路径从 `hostProfile.services.mihomo.identityFile` 提升成 `hostProfile.secrets.ageIdentityFile`。

### Flatpak 的严格声明式策略可以保留，但要写注释

文件：`modules/flatpak.nix`

证据：

- `services.flatpak.uninstallUnmanaged = true`。

结论：

这不是 bug。它代表“只保留配置里声明的 Flatpak”。如果这是你的预期，可以保留，但建议加注释，避免以后误以为手动安装被系统吞了。

## 清理和可维护性

### 主题配置漂移：删掉没有启用的旧主题

文件：

- `modules/glass-settings.nix`
- `modules/theme/qt.nix`
- `modules/theme/gtk.nix`
- `modules/theme/flatpak-assets.nix`
- `assets/kvantum/*`

证据：

- `glass-settings.nix` 仍写着 `gtkThemeName = "Nordic-Polar"`、`qtStyleName = "kvantum"`、`kvantumThemeName = "KvNordLight"`。
- 实际 GTK 用的是 `adw-gtk3`。
- 实际 Qt 用的是 `Darkly`。
- Kvantum 资源还在仓库里，但当前没有启用。

建议修法：

- 按你的意图：删除没有启用的旧主题字段和 Kvantum 遗留资源。
- 保留当前真正生效的 `adw-gtk3`、`Darkly`、`Colloid-Light`、`Nordzy-cursors`。

### `configuration.nix` 属主是 root

文件：`configuration.nix`

证据：

- 文件属主是 `root:root`，仓库其他文件基本是 `lilya:users`。

影响：

普通编辑容易失败，也会让自动化补丁或提交流程别扭。

建议修法：

- 改回 `lilya:users`。

### desktop entry 依赖裸命令名

文件：`modules/desktop/entries.nix`

证据：

- `antigravity`、`kitty`、`yazi`、`qt6ct` 使用裸命令名。

影响：

桌面启动环境的 PATH 不总是等于交互式 shell，少数情况下 launcher 会找不到命令。

建议修法：

- 用 `${lib.getExe ...}` 或包的完整路径替换。

### Antigravity 自定义包构建时写 `/tmp/app`

文件：`pkgs/antigravity.nix`

证据：

- icon derivation 把 app.asar 解包到 `/tmp/app`。

影响：

构建不够 hermetic，可能受旧文件或并发构建影响。

建议修法：

- 解包到 derivation 本地构建目录，例如 `app`。

## 暂不作为问题处理

### OpenList 对外开放

你确认这是有意行为，因此不建议默认改成本地-only。

可以做的只是补注释：

- 说明 `5244` 是有意开放。
- 如果未来只需要本地 WebDAV/刷新脚本，再改回 localhost。

### NVIDIA 电源切换没有按 AC 状态切换

原文档把它当 bug，但现在应改为“有意关闭动态切换”。当前真正要做的是：

- 不恢复自动切换。
- 加固 OOM 缓冲。
- 把 dGPU-only 设计写清楚。
- 后续单独做可回退 profile，而不是直接修回 `boot|change -> ac_online`。

## 建议实施批次

### 第一批：稳定性

1. 修 Fcitx 单实例。
2. 开启 zram swap。
3. 禁用或限制 powertop 对 HID/USB hub 的 autosuspend。
4. 暂时回退 kmscon 或调整 kmscon 配置做 A/B 验证。

### 第二批：界面和体验

1. 重做 gtkgreet CSS 和输出配置。
2. 优雅化 Zen 重复窗口修复。
3. 清理未启用主题和 Kvantum 遗留。

### 第三批：维护性

1. 加固 Mihomo activation script。
2. 修 desktop entry 路径。
3. 修 Antigravity `/tmp/app`。
4. 修 `configuration.nix` 属主。
5. 给 OpenList/Flatpak/dGPU-only 策略补注释。

## 修完后的验证清单

- `nix flake check --no-build`
- `rebuild` 后重启
- `journalctl -b | rg -i "oom|out of memory|fcitx|libinput error|usb 3-9|powertop|kmscon|greetd|niri"`
- `pgrep -a fcitx5` 应只有一个实例
- `swapon --show` 或 `zramctl` 应显示 zram/swap
- 鼠标静置后无需点击即可移动
- 键盘连续输入不卡顿
- 外接显示器开机控制台显示正常
- gtkgreet 在内屏和外屏比例都自然
