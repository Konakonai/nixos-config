# lilya's NixOS configuration

个人 ThinkBook 的 Nix Flakes + Home Manager 配置，同时提供 **Niri + Noctalia** 和 **Plasma Wayland**。当前默认登录会话为 `plasma-hdr`；这个名称本身不保证 HDR 已开启。

自动化修改请先读 [AGENTS.md](AGENTS.md)。最新深入审计与后续实施计划见 [配置改进计划](docs/configuration-improvement-plan-2026-09-12.md)。计划中的改动尚未实施；较早的 [2026-09-11 审计](docs/configuration-audit-2026-09-11.md) 仅作历史记录。

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

# 运行脚本回归与 portal 检查
nix build .#checks.x86_64-linux.configuration .#checks.x86_64-linux.portal --no-link

# 示例：只构建一个本地包
nix build .#nixosConfigurations.nixos.pkgs.lilya.qoder --no-link

# 应用当前配置；由用户执行
rebuild
```

还提供 `testbuild`（`nh os test`）。这会实际切换当前运行配置用于测试，不是只读检查。当前没有顶层 `packages` 输出，因此 `.#packages.x86_64-linux.<name>` 不是本仓库的包构建入口。

`checks` 覆盖部分脚本行为和 portal 选项契约；不等于全系统构建、图形会话测试、真实磁盘测试或所有应用配置的验证。运行前应查看检查输出，确认实际执行的目标。

## 配置与外部状态

`flake.lock` 固定 Nix 输入，本地下载包固定源哈希。完整用户会话仍依赖不在 Git 中的状态：

| 状态 | 用途 |
|---|---|
| `~/.config/age/mihomo.txt` | 解密仓库内 age 密文的身份文件 |
| `~/.config/antigravity/brave-search.env` | Brave Search API 凭据 |
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
| Noctalia `settings.toml` | GUI 覆盖；激活脚本同步部分 Nix 管理字段 |
| Zed `settings.json` | 首次种子，后续由应用/用户修改 |
| LibreOffice 工具栏 | 激活时补充未配置的初始值 |
| Dolphin / Plasma 部分键 | 激活时重新写入指定值 |
| Flatpak 应用和 Noctalia 插件 | 运行时安装/更新，不由 flake.lock 固定其实际版本 |

`config-dump noctalia` 导出合并后的用户配置；`config-drift noctalia` 与仓库种子按解析后的值比较，返回码 1 表示存在差异，不必然是错误。Zed 的这两个工具当前使用 `jq`，只支持严格 JSON；带注释的用户设置支持待改进。

`config-repair noctalia-templates` 请求应用模板。Niri 当前依赖 Noctalia 生成的 `noctalia.kdl`，干净目录缺少该文件时的启动问题已写入计划，尚未修复。

## 更新与服务

- `codex-update` 每日检查上游，使用临时 Git worktree 构建 Desktop/CLI，通过检查后仅在主工作区未变化时快进并本地提交。它不自动推送或执行 `rebuild`；日志位于 `~/.local/state/codex-update/update.log`。
- Codex 定时服务有接电条件。Flatpak 每周定时器实际启动 `flatpak-managed-install-timer.service`；目前接电条件仅加在手动服务上，尚不能保证每周更新只在接电时运行。
- Flatpak 已关闭激活/登录时的自动安装，因此声明新增应用后，`rebuild` 本身不负责立即下载安装。接电后可按需执行 `systemctl --user start flatpak-managed-install.service`，或等待每周任务。
- Mihomo 使用 age 密文生成 `/run/mihomo/config.yaml`，再通过 systemd credential 提供给守护进程。规则变化到进程重启的传播契约仍需完善，不应仅凭 `rebuild` 成功认定新规则已加载。
- 正常功耗策略由 power-profiles-daemon / UPower 管理；电池且省电模式时，单独服务禁用 Intel turbo，退出条件满足时恢复原值。自动休眠的既有规避配置保留。

## 外接 Windows 虚拟机

菜单中的 **External Windows 11** 使用指定 USB 磁盘运行 KVM/libvirt 来宾。当前启动器先检查磁盘、尝试卸载已挂载分区，再启动并打开 SPICE 窗口；检查命令失败时的处理尚不完善，详见计划，不能把它视为严格的磁盘互斥保证。

首次启用 `libvirtd` 用户组后需重新登录。首次虚拟启动可在 Windows 内以管理员身份运行 `SPICE_TOOLS` 光盘中的 `Install-Guest-Tools.cmd`，随后重启来宾，以使用动态分辨率与剪贴板。

先在来宾内关闭 Windows，再拔盘或原生启动；运行期间不要在宿主挂载该盘的文件系统。当前禁用来宾 VMX 暴露，虚拟机内不提供 Hyper-V/WSL2 的嵌套虚拟化路径。NVRAM、TPM 状态和 Windows 数据不应作为可随意删除的生成缓存处理。
