# 配置优化计划（85 分之后）

状态：**P2 已实施**（A 无差异跳过 + 主题 CLI 回退到文件；C 二次探测；D 校验标记；E 检查；B 只更新 README）。P3 仍待观察或用户决策。没有改 `trusted-users`、Zed 种子、Home Manager 相对登录的顺序或 flake inputs。

基线：`4cb41f6`（KDE Connect 事件刷新）。上一轮 [改进计划](configuration-improvement-plan-2026-09-12.md) 的 P1（A–D）已在 generation 594 核对；Qoder/ClassIn 已卸载；主题目录与 LibreOffice 种子改为原子替换；`QT_PLUGIN_PATH` 改为 prepend。那些工作不要重做。

按单机长期维护暂评 **85/100**：模块组织 18/20，声明式 16/20，正确性 18/20，简洁性 16/20，权限及故障隔离 17/20。本计划的目标是把所有权和故障窗口写清楚并收口可验证的缺口，不承诺机械到 90 分。90 取决于 Noctalia/登录竞争是否有应用参与的协调，以及用户是否接受收紧 `trusted-users`。

证据来自当前 Git 源码和此前已激活的 594 运行时。实施前必须再查 HEAD、`git status` 和 `/run/current-system`：`4cb41f6` / `86d4f66` 若尚未 `rebuild`，不要把未应用的 Git 状态当成运行时事实。

优先级：P2 为可靠性和可见性；P3 为结构或需用户决策的权限。没有新的 P1 失败即继续类缺陷。

## 1. 不要做的事

| 项目 | 原因 |
|---|---|
| 新建 `lib/`、自动扫描 imports、按行数拆文件 | 没有新的稳定复用点 |
| 恢复休眠、改默认会话、卸一批应用 | 使用偏好或设备规避，需单独实测 |
| 给 Noctalia `settings.toml` 加文件锁 | 应用不参与的锁不能协调 GUI |
| 全局 udev 忽略规则挡 Windows 盘自动挂载 | 未在本机对照，影响面大于启动器窗口 |
| 为结构整理更新 flake inputs | 与本计划无关的全局重建 |
| 把计划中的未来状态写进 README 当现状 | README 只描述已落地行为 |

## 2. P2：已确认缺口

### A. Noctalia 协调仍有竞争窗口

**证据**：`scripts/reconcile-noctalia.py` 对 Nix-owned 键做原子 replace，并在 replace 前比较字节。比较后到 replace 前 GUI 仍可写入；写入后的 GUI 改动也会在下次激活被 Nix 字段覆盖。锁定 Noctalia CLI 有 `theme-mode-set` / `color-scheme-set`，没有 bar/dock/backdrop 等 OWNED 键的通用配置层。`home.activation.reconcileNoctaliaSettings` 在文件存在时无条件跑。

**实施**：

1. 再核对当时锁定的 Noctalia：若仍无这些键的配置层，不要伪称已解决并发。
2. 把协调从“每次激活都写文件”收窄为“仅当 OWNED 字段与种子不同才写”；无差异则不 touch。
3. 若 CLI 已能设置 `theme.mode/source/custom_palette`，优先走 CLI，文件只处理 CLI 覆盖不了的键。
4. 日志区分：跳过、CLI 成功、文件协调、因并发中止。不要把 `config-drift` 返回码 1 当成错误。

**验收**：种子与 GUI 状态一致时激活不改 `settings.toml` 的 mtime/inode；并发写入时仍失败并保留 GUI 文件；无新锁文件。用临时 HOME 和假 `noctalia` 命令，不杀正在跑的桌面。

**剩余边界**：没有应用参与就不能消除“激活后 GUI 再写回”。写进 README。

**回退**：独立提交；保留用户 `settings.toml`。

### B. 登录与 Home Manager 激活重叠

**证据**：`modules/system/user.nix` 把 `home-manager-lilya` 调到 `systemd-user-sessions` 之后，并 `before = mkForce []`，避免挡住 SDDM。登录可以在激活写完 Dolphin/Noctalia/主题目录之前开始。`modules/home/desktop/dolphin.nix` 每次激活 `kwriteconfig6` 指定键。

**实施**：不要为了“声明式更纯”把激活拉回图形目标之前，除非测量证明 SDDM 不再被拖住。

可选、需对照的收窄：

- 图形会话的 `After=` 只等待与该会话相关的激活步骤（主题、niri 配置链接），不把整个 Home Manager 绑回 `display-manager.service`。
- 或保持现状，在 README 写明：首次登录后若主题/快捷键未齐，注销再进一次。

**验收**：冷启动到 SDDM 可登录的时间不差于现状（记 journal 时间戳）；Niri 与 Plasma 都能进会话；激活失败不得让显示管理器超时。

**回退**：恢复 `user.nix` 的 after/before；独立提交。

### C. 虚拟机检查通过到启动之间的挂载窗口

**证据**：`scripts/external-windows.sh` 在 `require_disk_state` 确认未挂载后调用 `virsh start`。两者之间 udisks/桌面仍可能挂上分区。没有 flock 能协调所有挂载工具。

**实施**：不要上全局 udev ignore。可做的最小收紧：

1. `virsh start` 前再探测一次；若已挂载则失败，不启动。
2. 启动失败且磁盘又变为已挂载时，给出同一错误，不重试 start。

**验收**：在假 `lsblk` 于两次探测之间插入挂载名时，不得出现 `virsh start`。不操作真实块设备。

**回退**：独立提交启动器脚本。

### D. Mihomo：`rebuild` 成功不等于新规则已加载

**证据**：`scripts/generate-mihomo-config.sh` 在 `mihomo -t` 失败或超时时，若 `/run/mihomo/config.yaml` 已存在则 exit 0，避免拖垮 switch。journal 里只有 stderr 一句。`checks` 不断言“失败时用户可见”。

**实施**：

1. 失败时写 `/run/mihomo/last-validation`（无密文：时间、exit、是否保留旧文件）。
2. `config-dump` 不读该文件中的配置正文。
3. README 已有“失败保留旧文件”；补一句：看 `journalctl -u mihomo-config` 或该标记，不要只看 switch 退出码。

**验收**：假 `mihomo -t` 失败时标记存在、dest 不变、switch 仍为 0；标记和日志不含代理条目。不重启真实代理做实验。

**回退**：独立提交；不删除 `/run/mihomo/config.yaml`。

### E. 检查缺口（随 A–D 补，不先写框架）

**证据**：`checks/default.nix` 覆盖脚本、portal 断言、Niri KDL、vCPU XML、Flatpak 接电目标、Mihomo restartTriggers。未覆盖：

- NetworkManager dispatcher 是否调用 `kdeconnect-refresh always`
- 定时器 ExecStart 是否为 `if-unreachable`
- `QT_PLUGIN_PATH` 不是整表 `mkForce`（patched 路径在列表中，且长度 > 1 或与 nixpkgs 条目并存）
- `copy-theme-dir` 已在 fileset（`../scripts` 已包含，确认测试会被 discover）

**实施**：eval 断言 dispatcher 脚本文本含 `always` 与 `runuser`；home 单元 ExecStart 含 `if-unreachable`。不要为检查去跑 NetworkManager。

**验收**：删掉 dispatcher 或改回无条件 2 分钟 `--refresh` 时，对应检查失败。

## 3. P3：条件项，先决策或观察

| 项目 | 判断 | 需要的证据 |
|---|---|---|
| `trusted-users` 含 `lilya` | 单机方便，等于信任该用户的 Nix | 用户是否接受只留 root；改前说明对 `nh`/`rebuild` 的影响 |
| Zed `trust_all_worktrees = true` | 只在种子里；已有 `settings.json` 不会被迁移 | 明确策略后再改种子；不要改用户文件 |
| KDE Connect 2 分钟不可达检查 | 覆盖手机切网、电脑网络未变 | `rebuild` 后观察一周：NM 事件是否足够；不要只因“有 timer”就删 |
| 升级 KDE Connect 以获得 ~60s TCP keepalive | 26.08.0 库中未见 `TCP_KEEPIDLE` | 上游进 nixpkgs 后再评估，不为此提前 `flake update` |
| `fcitx5.nix` 主题 SVG、`plasma.nix` | 按资源/职责拆可以，不是缺陷 | 有第二调用方或改包装时再拆 |
| 双桌面、补丁、镜像、GC、内核 | 有明确用途或规避 | 不因配置长而改 |

## 4. 操作顺序

1. 核对 HEAD、工作区、当前系统代是否已包含 `86d4f66`/`4cb41f6`。未应用则先让用户 `rebuild`，再拿运行时证据。
2. 实施 C（启动器二次探测）和 D（校验标记）——局部、可测、不碰桌面。
3. 实施 A 的“无差异不写”和检查 E；CLI 路径仅在锁定 Noctalia 确实支持时使用。
4. B 只在有启动时间对照时做；否则只更新 README 边界。
5. P3 等用户或观察结果，不顺手改。

验证入口与上一轮相同：

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.configuration .#checks.x86_64-linux.portal .#checks.x86_64-linux.niri-config .#checks.x86_64-linux.external-windows-cpu --no-link
git diff --check
```

提交按项独立；说明行为前后、证据、风险与回退。未另行限制则按 AGENTS 推送。系统切换仍由用户 `rebuild`。

完成标准：A 的无差异激活可测；C 的二次探测可测；D 的失败可见且无密文；E 能抓住 dispatcher/不可达刷新被删；B/P3 要么有对照，要么明确保持现状。新增文件数不是指标。
