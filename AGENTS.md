# Agent Notes

本文件适用于整个 `nixos-config` 仓库。它定义修改规范，而不是记录每个具体功能的历史细节。具体实现背景应写在对应模块注释、README/AUDIT 或提交信息里。

## 仓库定位

- `main` 是用户本机的精确 NixOS 配置，目标是可复刻、可审计、可长期维护。
- 通用模板、示例化配置或去本机化改造应放到独立分支，不要削弱 `main` 对本机的精确描述。
- 默认保留用户已经验证可用的行为。需要改变启动、登录、显示、输入、网络、secret、文件同步等高影响路径时，要有明确理由并做验证。

## 模块化原则

- 先读现有结构再改，优先沿用仓库已有模式，不为了“更抽象”而新增层级。
- 通用逻辑放在 `modules/`；本机硬件、路径、显示器、GPU、电源、用户目录、secret 位置等本机事实放在 `hosts/<host>/`。
- 自定义包或包装逻辑放在 `pkgs/`，不要把大段 packaging 塞进 Home/NixOS 模块。
- 资产放在 `assets/`，补丁放在 `patches/`，文档放在根目录或贴近相关模块的位置。
- 模块应小而有边界：一个模块负责一个主题；跨模块共享值优先通过 `hostProfile`、现有 option 或局部 `let`，不要用散落硬编码。
- 不要提交运行态数据库、明文 secret、临时备份、`result` symlink、下载缓存或构建产物。

## 变更风格

- 保持声明式。不要依赖手动系统状态、一次性命令、隐式 `/home` 文件或未记录的外部副作用来完成配置。
- 改动要尽量小而完整。不要把无关重构、格式化、依赖升级混进功能修复。
- 本地补丁必须有明确用途和移除条件。确认上游支持后优先删除补丁，而不是长期堆叠。
- 新增硬编码前先判断它属于“本机事实”还是“通用逻辑”。本机事实必须集中到 host profile。
- 不要回滚或覆盖用户/其他 agent 的未提交改动。遇到 dirty worktree 时先看清楚，只处理本任务需要的文件。

## 验证要求

验证应与改动的风险、影响面和失败成本相称，不要把完整 NixOS 验证链机械地用于所有修改：

- 仅修改文档、注释、说明文字或不影响求值结果的格式时，检查 diff、路径和引用即可，不需要运行 Nix 求值或构建。
- 仅安装普通用户态应用、注册本地应用包或把现有包加入 Home Manager 软件列表时，默认不运行 Nix 解析、求值、构建或启动验证；只检查变更范围和来源固定是否正确后提交。若同时修改 systemd 服务、驱动、boot/display/power/network 等系统行为，则按对应风险级别验证。
- 小型、局部的 Nix 修改，优先解析改动文件，并运行能覆盖实际行为接缝的定向 eval、生成配置检查或目标构建。
- 跨模块、系统级、flake input、包依赖以及 boot/display/power/network 等高风险修改，才默认运行下面的完整验证链。
- 用户明确要求快速提交或跳过验证时可以照做，但最终回复必须说明哪些检查没有运行，以及仍需怎样实机验证。

完整 NixOS 验证链：

```bash
rg --files -g '*.nix' | xargs nix-instantiate --parse --quiet >/dev/null
nix flake check --no-build
nix eval .#nixosConfigurations.nixos.config.warnings --json
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link --print-out-paths
```

按风险追加验证：

- 修改 boot/display/specialisation：检查 kernel params、specialisation 列表，并说明需要用户实机验证什么。
- 修改 niri/桌面会话：验证生成配置；如果包含 include，要按实际运行目录验证。
- 修改包、补丁或 flake input：构建 toplevel，并用 `nvd diff /run/current-system /nix/store/<new-toplevel>` 审查闭包变化。
- 修改 systemd service/timer：eval 或查看生成 unit，确认 `Install`、`WantedBy`、`ExecStart` 和运行条件合理。

如果某项验证因为环境限制不能跑，要在最终回复里明确说明。

## Git 流程

- 修改完成并验证后必须提交，除非用户明确说不要提交。
- Codex 自动更新器生成的预期 `flake.lock`、`pkgs/codex.nix` 或对应固定源变更属于正常待提交更新，不要仅因它来自后台任务就当作无关 dirty state 留下；先核对版本、来源、哈希和构建结果，再将它与相关 Codex 更新提交并按本节规则推送。若变更范围超出 Codex 固定源或验证失败，再暂停并向用户确认。
- 提交前检查 `git status --short` 和 staged diff，确保只包含本任务相关文件。
- 提交信息用简短祈使句，描述行为变化，例如 `Fix display geometry`。
- 提交成功后默认推送当前分支到对应 remote，除非用户明确说不要 push、当前分支没有 upstream、网络/权限失败，或仓库状态显示不适合推送。
- 不要使用 force push，除非用户明确要求并确认风险。
- 如果自动任务生成提交，也应保证工作区没有混入无关变更、完成与风险相称的验证，并禁用需要交互的签名流程。

## 与用户沟通

- 最终回复要说明改了什么、验证了什么、提交 hash、是否已 push，以及用户下一步是否需要运行 `rebuild`。
- 用户有 `rebuild` alias；需要应用配置时说 `rebuild`，不要默认给长 `nixos-rebuild` 命令。
- 不确定需求时优先从代码和系统状态中查证；确实需要取舍时再问用户。
