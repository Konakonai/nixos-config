# 配置审查记录：2026-09-11

本轮检查系统、Home Manager、桌面会话、应用启动封装、本地包和自动更新路径。
判断依据是当前仓库、锁定依赖的模块源码及有限的本机只读检查；配置求值通过不代表
休眠、显示切换和所有应用功能已经重新做过实机测试。没有切换系统或更新 flake 输入。

## 已完成

| 范围 | 改动与理由 |
| --- | --- |
| 充电保护 | 删除 charge-limit 命令、sysfs 权限服务和主机路径。锁定 Noctalia 源码使用 UPower 的 EnableChargeThreshold，不依赖旧脚本。 |
| 极限省电 | 按用户确认删除整个 battery-saver specialisation，包括限功耗、CPU 热插拔、显卡屏蔽和自动重启进 BIOS 的守卫。 |
| CPU / USB | 按用户确认移除禁用 SMT、usbcore.autosuspend=-1 和所有 USB 强制 power/control=on 的规则。外设出现问题时再按具体设备处理。 |
| Plasma 电源 | 用 plasma-manager 的 powerdevil 选项替换 kwriteconfig6 激活脚本和每次重启 PowerDevil；保留 AC/Battery 的 AutoSuspendAction=0、LidAction=64。 |
| Zen | 删除启动时清空 sessionstore、recovery、previous 和 zen-sessions 文件的脚本。保留现有启动偏好，避免顺带改变窗口恢复策略。 |
| 主题历史迁移 | 删除已经执行完的 Plasma Overdose、Glass、旧 GTK overlay 清理钩子。本机对应旧目录及 CSS 引用已不存在，不再在每次激活时重写 gtk.css 或删除旧主题路径。 |
| MCP 密钥迁移 | 删除旧 Brave Search 内嵌密钥迁移脚本；确认 env 文件存在、配置已是受管理链接。保留现有私密 env 文件和引用。 |
| Flatpak | 删除重复的 QQ 激活时参数写入、WeChat 激活时 override；保留声明式 overrides 与启动封装。 |
| 剪贴板 | Noctalia 已有自己的 Wayland 剪贴板服务和历史存储，删除额外 cliphist 记录进程及包。没有删除旧剪贴板数据库。 |
| KDE / 网络 | 删除 Dolphin 对 kdeglobals 终端设置的重复写入，由 plasma-manager 管理；删除 KDE Connect 重复防火墙范围，由 NixOS 模块管理；删除关闭反向路径检查后不生效的附加规则。 |
| 无效配置 | 删除无人使用的 Scroll 配置导入、Niri 中旧 shell 的 layer 匹配、未消费的登录壁纸和登录位置字段。保留原壁纸资源文件。 |
| Codex 打包 | 将 Desktop derivation 移到 pkgs/codex-desktop.nix，更新器移到 pkgs/codex-update.nix 和 scripts/codex-update.sh，Home Manager 只负责安装与定时任务。 |
| Codex 更新 | 保留每日自动更新；无新版本时不下载 CLI 包；从 flake 根 inputs 映射解析锁节点；临时工作树更新、目标包构建，原分支保持干净且 HEAD 未变才快进合入。失败不再用旧备份覆盖用户工作区。 |

## 保留与后续验证

| 范围 | 本轮决定 |
| --- | --- |
| 合盖、空闲休眠 | 按用户确认保留系统与 Plasma 的现有规避措施。后续在保存工作后单独测试 s2idle 恢复。 |
| NVIDIA | 保留 closed driver、禁用 NVIDIA 电源管理的现有设置。当前只有 NVIDIA PCI 设备，不能据此声称 PRIME 混合模式验证通过；需明确 BIOS 模式并分别测试。 |
| Lenovo WMI | 保留 lenovo_wmi_gamezone 黑名单。当前性能模式由 ideapad-laptop 提供，但尚未测试取消黑名单是否安全。 |
| GTK 渲染 | 保留 Celluloid 局部 OpenGL 封装、File Roller 局部 GTK 补丁、Niri 的 GSK_RENDERER 和 QQ 的会话限定渲染修复。它们存在故障背景，不能仅凭“代码旧”删除；下一步应按应用做 A/B 测试。 |
| 输入法与桌面边界 | 保留 WeChat X11/Fcitx、LibreOffice GTK、Kitty 和 LocalSend 的会话隔离；本轮不更改输入法协议或渲染后端。 |
| 引导 | 保留 GRUB 的 ESP 布局、EFI fallback、启动顺序处理和 Plymouth/kmscon 配置，未修改引导结构。 |
| 网络服务 | 保留 Mihomo TUN、反向路径检查策略、OpenList、WebDAV、KDE Connect 刷新和现有 LAN 访问范围；没有证据证明这些服务已无用途。 |
| 外置 Windows | 保留准确设备匹配、卸载检查、QEMU 权限和 VMX 屏蔽。没有启动或修改正在运行的虚拟机。 |
| 软件清单 | 没有以“功能相似”为由删除浏览器、编辑器、监控工具或开发环境；包数量本身不能证明无用。 |
| 桌面状态 | 保留 Noctalia 的主题协调、Plasma 外观及应用首次初始化配置。本轮没有重置用户 GUI 状态。 |

## 验证与生效

- `nix flake check --no-build` 和修改后关键选项求值。
- Codex Desktop 与 codex-update 局部构建；writeShellApplication 同时检查脚本。
- `python3 scripts/tests/test_codex_update.py`：真实 Git 工作树，模拟网络与 Nix 构建，
  覆盖成功合入、下载失败、构建失败、并发编辑、并发提交、脏仓库跳过、版本不变，
  以及 Desktop 精确 revision 和 tracking URL 保持。
- Niri 生成配置验证；检查已删除功能无活动引用，`git diff --check`。

应用时运行 `rebuild`，然后重启以恢复 SMT 和 USB 内核默认策略，并结束旧会话中的
剪贴板记录进程。单纯切换配置不会回滚已经写入 sysfs 的所有状态。
旧 NixOS generations 仍可能含有旧省电启动项，这是回滚历史，不属于新配置。

nixos-hardware PR 仍应等显卡模式与最低测试范围明确后再准备；本轮没有提交上游 PR。
