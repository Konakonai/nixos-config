# Agent Notes

本仓库为 NixOS 单机配置与环境管理。保持配置简洁、清晰、高内聚。

## 1. 架构与模块职责

- 系统入口：`configuration.nix`
- Home Manager 入口：`home.nix`
- 单机装配：`flake.nix`（`nixosConfigurations.nixos`）

| 目录/位置 | 职责 |
|---|---|
| `hosts/lilya-thinkbook/` | 主机硬件事实、用户路径、显示器等设备专属信息 |
| `modules/system/` | NixOS 系统级选项、服务与权限（如 `packages.nix`、驱动、系统服务） |
| `modules/home/` | 用户环境与应用配置（桌面、CLI 工具、主题、用户服务） |
| `modules/shared/` | 系统与用户共用的数据（如色彩、主题参数） |
| `pkgs/` | 自定义包与衍生构建，由 `pkgs/default.nix` 导出为 `pkgs.lilya` |
| `scripts/` | 独立辅助脚本与维护工具 |
| `assets/`、`patches/` | 静态资源与上游补丁 |

## 2. 开发与配置规范

- **纯声明式管理**：软件与配置均通过 Nix 声明式管理，不使用 `nix-env` 或 `nix profile` 命令。
- **Flake 文件暂存**：新建的文件必须先 `git add` 暂存，Flake 才能识别和求值。
- **职责清晰**：常规 CLI 工具优先放在 `modules/home/cli-tools.nix` 或系统级 `modules/system/packages.nix`；图形应用在 `modules/home/apps/`。
- **就近与复用**：直接使用 `pkgs` / `lib` / Home Manager 已有能力，避免过度抽象。修改上游包优先局部 override。
- **敏感信息**：切勿在仓库或日志中暴露明文密钥或令牌。

## 3. 验证与生效

- **敏捷优先，无需过度验证**：
  - 常规增删包和简单配置修改直接生效，不需要运行耗时的 `nix flake check`、提前构建下载或跑全量回归测试。
  - 如需快速排查语法拼写错误，使用毫秒级单文件语法解析即可：
    ```bash
    nix-instantiate --parse path/to/changed.nix >/dev/null
    ```
- **系统生效交由用户**：配置变更完成后留给用户执行 `rebuild`（如 `nh os switch`）生效，无需自行切换系统或重启服务。

## 4. 提交与交付

- 修改完成后自动提交并推送到当前分支：
  - Commit message 使用简短英文祈使句（例如 `add xxx to system packages`）。
- 简明汇报变更内容与文件即可。
