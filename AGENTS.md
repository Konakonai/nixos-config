# Agent Notes

本文件适用于整个 `nixos-config` 仓库，定义 AI Agent 在本机配置下的开发、打包、验证与提交流程。

---

## 1. 仓库架构与现状

- **架构定位**：基于 Nix Flakes + Home Manager 的个人配置仓库。系统配置入口为 `configuration.nix`，用户配置入口为 `home.nix`。
- **模块分层**：
  - `modules/system/`：系统级 NixOS 模块（显示、引导、音频、虚拟化、系统服务等）。
  - `modules/home/`：用户级 Home Manager 模块（应用、桌面环境、主题、Shell、开发工具等）。
  - `modules/shared/`：系统与用户共享配置（如主题设计 Token）。
  - `hosts/lilya-thinkbook/`：本机硬件与事实配置（GPU/显示器 ID、路径、电源及设备特征）。
  - `pkgs/`：自定义本地包与包装脚本，由 `pkgs/default.nix` 汇总并通过 `pkgs.lilya.<name>` 导出。
  - `assets/` / `patches/`：壁纸、图标等静态资产及局部源码补丁。
- **桌面环境**：Niri (Wayland 合成器) + Noctalia (桌面 Shell / Launcher)。

---

## 2. 开发与打包规范

- **绝对声明式**：严禁使用 `nix-env` 或 `nix profile` 命令安装软件，所有应用与环境均通过声明式配置管理。
- **Git 追踪（Flakes 规则）**：新建任何 `.nix` 或静态资源文件后，**必须先执行 `git add`**，否则 Nix Flakes 会忽略该文件导致求值/构建失败。
- **分层与边界**：
  - 通用逻辑放 `modules/`，本机硬件与特定事实放 `hosts/`。
  - 复杂打包与应用封装放 `pkgs/`，不要将大段 Derivation 逻辑直接写在 NixOS/Home Manager 模块内。
- **AppImage 打包**：
  - 专有 AppImage 优先使用 `pkgs.appimageTools.wrapType2` 打包。
  - 使用 `extractType2` 提取 `.desktop` 和图标，并在 `.desktop` 中将 `Exec=AppRun` 替换为包装后的可执行文件名（如 `Exec=splayer %U`）。
- **桌面环境重载**：
  - 当安装/更新桌面应用导致应用菜单或图标未刷新时，可在后台重启 Noctalia：
    ```bash
    pkill noctalia && noctalia & disown
    ```

---

## 3. 轻量化验证流程

为避免不必要的全量构建开销与冗长等待，**严禁对常规修改机械运行耗时的 `nix build system.build.toplevel`**。请按以下轻量阶梯按需验证：

- **文档、注释、静态资源修改**：
  - 仅检查 `git diff`，无需运行任何 Nix 验证。
- **普通配置修改（NixOS / Home Manager 配置调整、新增已有软件包）**：
  - 快速检查改动文件的语法：
    ```bash
    nix-instantiate --parse <改动的.nix文件> >/dev/null
    ```
    或进行无构建的 Flake 结构与求值检查：
    ```bash
    nix flake check --no-build
    ```
  - 语法/求值无误后即可提交，实际系统生效直接交给用户运行 `rebuild`。
- **新增/修改本地包 (`pkgs/`)**：
  - 仅对目标 Package 进行针对性局部构建验证：
    ```bash
    nix build .#packages.x86_64-linux.<包名> --no-link
    ```
- **核心系统/引导等高风险改动**：
  - 仅在涉及内核参数、驱动重构或 flake inputs 大版本升级时，才按需进行进一步求值或构建测试。

---

## 4. Git 与提交流程

- **暂存与提交范围**：
  - 提交前检查 `git status --short`，确保只包含当前任务相关的文件。
  - 自动更新或生成的预期固定源变更（如 `flake.lock`、`pkgs/codex.nix`）可一同提交。
- **Commit 风格**：
  - 使用简短清晰的英文祈使句描述行为变化，例如 `Configure Celluloid stream cache`、`Add splayer package`。
- **推送规则**：
  - 提交完成后默认直接推送到对应 remote 分支（`git push`），除非用户明确要求不推送或环境受限。
  - 禁止使用 `--force` 推送。

---

## 5. 与用户沟通

- 简要说明改动内容、轻量验证结果、提交 Hash 以及是否已推送。
- 用户配置了系统切换 alias；如需应用配置，提示用户在终端运行 `rebuild`（无需输出冗长的 `nixos-rebuild switch ...` 命令）。
