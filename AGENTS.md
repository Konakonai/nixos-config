# Agent Notes

单机 NixOS 配置（Flakes + Home Manager）。保持简洁、清晰、高内聚；先读 `README.md` 了解目录职责与所有权模型。

## 提交流程

分两类改动，按类处理：

| 改动类型 | 例子 | 流程 |
|---|---|---|
| 简单改动 | 增删包、改一个选项值、改注释、改 mihomo 策略组成员 | 直接在 `main` 提交。提交前 `nix-instantiate --parse <file>` 即可。 |
| 影响运行时行为或需要试错的改动 | compositor / 驱动 / 会话 / 电源 / USB / 脚本 / 代理规则 / 主题所有权 / 任何要反复 `rebuild` 观察的东西 | 在 `wip/<topic>` 分支上提交，可以随意多次提交。用户 `rebuild` 确认后 `git merge --ff-only` 进 `main`；放弃则删除分支。 |

原则：`main` 上的每个提交都应该是在本机 `rebuild` 过并确认可用的状态。探索性调试不要落在 `main` 上。

其他规则：

- Commit message 用简短英文祈使句（`add xxx to system packages`）。
- 不推送 `wip/*` 分支到远端，除非用户要求。`main` 按用户指示推送。
- 触及 `scripts/`、`modules/system/mihomo/`、`modules/home/niri/`、`modules/system/virtualization.nix`、`checks/` 时，提交前运行对应的 check（见 README「验证」）。改 Nix 文件后跑 `nix build .#checks.x86_64-linux.lint`。
- 系统切换只由用户执行 `rebuild`；agent 不自行 `nh os switch`、不重启服务。

## 编码规范

- **纯声明式**：软件与配置通过 Nix 声明，不用 `nix-env` / `nix profile`。GUI 应用的运行时状态按 README「配置所有权」处理，不要新增 activation 脚本去改用户文件，除非确认没有配置层可用。
- **就近与复用**：直接用 `pkgs` / `lib` / Home Manager / plasma-manager 已有能力，不建 `lib/`。修改上游包优先局部 override。
- **新文件先 `git add`**，Flake 才能看到。
- **敏感信息**：密钥、令牌、代理节点只进 `secrets/*.age`；不进日志、注释或提交说明。
- 每个 workaround 写清"为什么"，没有原因的规则会在下次审计被删。
- 格式：`nix fmt`（nixfmt）；`statix.toml` 里已禁用与本仓库风格冲突的规则。

## 目录职责

| 位置 | 职责 |
|---|---|
| `flake.nix` | inputs、overlay、`nixosConfigurations.nixos`、`checks`、`packages`、`formatter` |
| `configuration.nix` / `home.nix` | 系统与 Home Manager 入口 |
| `hosts/lilya-thinkbook/` | 主机事实：用户路径、显示器、GPU、外接 Windows 盘、age 身份路径 |
| `modules/system/` | NixOS 系统级选项、服务、权限 |
| `modules/home/` | 用户环境：应用、桌面、主题、用户服务 |
| `modules/shared/theme-settings.nix` | 系统与用户共用的主题参数（色板、字体、圆角） |
| `pkgs/` | 本地包，由 `pkgs/default.nix` 导出为 `pkgs.lilya` |
| `scripts/` + `scripts/tests/` | 独立脚本与其回归测试 |
| `checks/` | Flake checks |
| `assets/`、`patches/`、`secrets/` | 静态资源、上游补丁、age 密文 |
| `docs/` | 不归 Nix 管理的外部机器状态（`music-server.md`：上海 Navidrome）。改了那边的配置要同步更新文档 |
