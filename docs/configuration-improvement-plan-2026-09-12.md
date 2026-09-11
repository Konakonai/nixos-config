# 配置深入审计与实施计划

状态：**P1（A–D）已实施**；E/F 只核对了接口与缓存体积，未伪称并发/增长问题已解决。第三阶段结构拆分只做了启动器脚本与域 XML 模板这两处测试所需提取。

实施基线：`9718e74`（执行时 HEAD；审计基线 `18c61b8` 之后已有 Mihomo 路由提交）。A–D 在该 HEAD 上仍可复现，已按项修复。

## 1. 对 Grok 三点意见的判断

| 意见 | 判断 | 证据与建议 |
|---|---|---|
| 缺少 `uer.nix` | 字面上不是 NixOS 必需文件；若指 `user.nix`，意见不成立 | 已有 `modules/system/user.nix`，由 `modules/system/default.nix` 导入；`home.nix` 是 Home Manager 入口；主机用户信息在 `hosts/lilya-thinkbook/default.nix`。不再创建重复入口。若 Grok 指其他职责，应先提供原文。 |
| 缺少 `lib/` 工具函数库 | 不是缺陷，暂不新建 | 已注入 Nixpkgs 的 `lib`，有 `pkgs.lib` 和 Home Manager 工具。局部 `let` 函数、`pkgs/default.nix` 的包集合已覆盖现有需要。只有两个以上真实调用方共享稳定语义时，才提出具体的小型工具。 |
| 配置文件体积较大 | 局部成立，不能据此全仓拆分 | 102 个受 Git 跟踪的 Nix 文件，共 6196 行，中位数 46 行；39 个文件不足 30 行。最大为 Noctalia 353 行、虚拟化 347 行、Plasma 203 行。重点分离异构模板与运行逻辑，不设置机械行数门槛。 |

代理 YAML 有 1276 行，主要是策略数据；与 1276 行控制逻辑的维护风险不同。Nix 文件数量已多，继续把纯配置列表拆成大量小文件可能降低可导航性。

## 2. 再评分与边界

按单机长期维护用途，暂评 **76/100**：模块组织 16/20，声明式与可复现性 15/20，正确性与验证 14/20，简洁性 16/20，权限及故障隔离 15/20。分数是工程判断，不是性能测量或安全认证。

上一轮已改善 portal、规则去重、GPU/虚拟机参数、字体作用域、Noctalia 导出和 Qoder 缓存。深入检查仍发现生命周期与错误路径缺口，因此不应仅凭文件变短或测试数量增加评到 90 分。

本轮证据来自当前源码、锁定依赖实现、生成的 service/desktop 文件，以及临时目录实验。没有切换系统、重启代理/桌面、实际共享屏幕、启动 Windows 或操作真实块设备。

优先级：P1 为先修复的行为缺陷；P2 为可靠性和职责改进；P3 为条件性清理。这里只安排工作，不声称问题均已在实际会话触发。

## 3. 已确认问题与实施顺序

### A. P1：虚拟机磁盘检查必须在检查失败时停止

**证据**：`modules/system/virtualization.nix:230-255`。

- `virsh list` 出错会落入“虚拟机没有运行”的分支。
- `mapfile < <(lsblk | jq)` 不可靠地传播进程替换内部的失败。
- 最后一个 `if lsblk | jq -e ...; then ... fi` 把 jq 的正常 false 和命令错误都当成可继续启动。
- 用假的 `lsblk` 返回 1、`jq` 返回 4，在 `set -euo pipefail` 下复现检查后仍继续执行。没有调用真实 virsh。

**实施**：把设备探测/状态查询结果先成功采集并解析，再判断业务状态。无法确认磁盘和来宾状态时给出明确错误并退出。保留按稳定设备身份识别磁盘、仅卸载指定磁盘、8 vCPU/16 GiB 默认值、禁用 VMX 等现有行为。

把 launcher 提取为可注入假命令的脚本，并由现有包包装器提供真实工具路径；不顺便重构整个虚拟化栈。

**验收**：模拟 virsh 失败、lsblk 失败、无效 JSON、磁盘消失、卸载失败时，均不得调用 `virsh start`；已启动来宾只打开 viewer；合法且未挂载路径才启动。另测参数改变时 XML vCPU 与拓扑一致。测试不得操作真实磁盘。

**剩余边界**：检查通过到启动间仍可能发生重新挂载；先记录并研究宿主自动挂载与 libvirt 协调，不把“加了 flock”称为对所有挂载工具的互斥。不要未经验证引入全局 udev 忽略规则或修改 Windows 文件系统。

**回退**：独立提交，保留原来宾身份和持久状态；代码回退不删除 NVRAM/TPM，不重定义正在运行的来宾作为测试手段。

**实施结果（2026-09-12）**：启动器抽出为 `scripts/external-windows.sh`，PATH 可注入假命令。磁盘/`virsh`/`jq` 失败、卸载失败或仍挂载时不调用 `virsh start`。域 XML 用同一 `vcpus` 参数生成 `<vcpu>` 与 topology；检查用生产值与 vcpus=3 对照。未引入 flock 或 udev 忽略规则。

### B. P1：Flatpak 接电条件加在了错误的定时服务上

**证据**：`modules/home/flatpak.nix:183-190` 与锁定 nix-flatpak 的 `modules/home-manager.nix:19-43`。

生成后的定时器 `flatpak-managed-install-timer.timer` 指向 `flatpak-managed-install-timer.service`；该服务的 `Unit.ConditionACPower` 为空。现在设置为 true 的是另一个 `flatpak-managed-install.service`。已从求值和用户单元文件交叉确认。

**实施**：接电条件同时覆盖实际定时服务和当前手动服务。保留 weekly、禁用启动时在线安装、保留 unmanaged 应用的现有策略；不恢复开机网络等待。

**验收**：从定时器的 `Timer.Unit` 获取实际目标，断言其接电条件存在；不能只按猜测服务名检查。确认不会把条件写到 Timer 段。无需拔掉电源或发起实际在线更新。

**回退**：独立小提交；只影响下次任务是否启动，不中止正在进行的 Flatpak 更新。

**实施结果（2026-09-12）**：`flatpak-managed-install` 与定时器 `Timer.Unit` 指向的 `flatpak-managed-install-timer` 均设置 `Unit.ConditionACPower`。检查从 Timer.Unit 解析目标，并断言条件不在 Timer 段。

### C. P1：Niri 干净配置启动失败，最终配置绕过验证

**证据**：`modules/home/niri/effects.nix:26-28,78`。

临时空目录放入求值得到的最终 `config.kdl`，使用锁定 Niri 执行 `niri validate -c`，返回 1：缺少必需的 `noctalia.kdl`。`gpu.kdl` 已是可选，缺失只产生警告。由于 Noctalia 是 Niri 启动后才 spawn，不能依赖它修复启动前的必需 include。

上游 niri-flake 的 Home Manager 模块使用 `validated-config-for` 构建配置；本仓库 `mkForce (pkgs.writeText ...)` 替换了此验证生成物。当前 checks 的 portal 断言不能覆盖这个问题。

**实施**：让首次启动不依赖未生成的 Noctalia 颜色文件，可用锁定 Niri 支持的 optional include 或声明式默认片段。恢复对最终 KDL（含手写效果块、显示器段）的实际 parser 验证，不只验证 `programs.niri.finalConfig` 前半段。

**验收**：干净目录缺少两个运行时 include 时通过；合法生成 include 存在时通过；损坏的已存在 include 应报错，不能通过忽略所有解析错误隐藏故障。明确颜色生成前后的合理默认效果。不启动/替换当前 compositor。

**回退**：独立提交，保持已有会话入口、显示器位置/缩放和快捷键；不要删除用户实际生成的 Noctalia 文件。

**实施结果（2026-09-12）**：`noctalia.kdl` 改为与 `gpu.kdl` 一样的 optional include。缺少文件时使用 `programs.niri.settings` 里的 focus-ring 等默认颜色；Noctalia 生成后覆盖 layout 颜色。最终会话 KDL 经 niri-flake `validated-config-for` 校验。检查覆盖干净目录、合法 include、损坏 include。

### D. P1：Mihomo 配置更新缺少向消费者传播的契约

**证据**：`modules/system/mihomo.nix:19-74` 及锁定 nixpkgs 的 Mihomo 模块。

- 守护进程以 `LoadCredential=config.yaml:/run/mihomo/config.yaml` 读取配置副本。
- `mihomo.restartTriggers` 为空；生成脚本和密文变化没有显式进入消费者的重启触发条件。
- 在只读的 `extendModules` 实验中改变生成器脚本，`mihomo.service` 的生成文本完全不变。
- `requiredBy` 的反向依赖确实生成了实际 Requires，运行时可以看到 `mihomo-config.service`。不能因为 Nix 中 `requires = []` 就断言首次启动缺少生成器依赖。

**实施**：让公开配置片段和加密源变化显式触发消费者更新，并保证先成功生成新配置，再启动读取 credential 的进程。优先最小 restartTriggers/依赖修复；不要假设原地替换 `/run` 文件会刷新现有 credential。验证配置后再发布；失败时保留最后可用文件并报告错误。

**验收**：分别改变前片段、后片段、加密源引用时，消费者的重启依据发生变化；无关主题改动不触发代理更新。用假凭据和临时服务验证首次启动、重复启动、生成失败及更新顺序。禁止在测试日志或 derivation 中放解密内容。

**回退**：独立提交。在线代理重启可能中断当前连接，应在实际应用阶段说明；本计划的离线测试不重启真实代理。

**实施结果（2026-09-12）**：生成器抽出为 `scripts/generate-mihomo-config.sh`，`mihomo -t` 通过后才发布；失败保留旧文件。`mihomo.service` 显式 Requires/After 生成器，并对前片段、后片段、加密源设置 restartTriggers。离线测试使用假凭据，未重启真实代理。应用本配置会导致 Mihomo 重启。

## 4. 第二阶段：配置所有权与可测试性

### E. P2：Noctalia 和其他 GUI 状态的并发写入边界

**证据**：`scripts/reconcile-noctalia.py:60-76` 原子替换前只做一次内容比较；比较后到 replace 前仍有竞争窗口，GUI 稍后写回也可能覆盖结果。上一轮已改善半写文件问题，尚未证明并发安全。`modules/system/user.nix:21-24` 将 Home Manager 排在用户会话允许之后，增加启动时与 GUI 同时改状态的可能；不能仅凭它推断已经发生数据丢失。

**实施**：先核对锁定 Noctalia 是否提供适合管理这些键的应用接口或配置层优先级。优先让 Nix-owned 字段从明确的配置层生效，避免反复修改 GUI 文件；若必须迁移，定义应用退出后的迁移时机或应用参与的协调机制。单方面加文件锁不解决 GUI 并发。

同时检查 `flatpak-assets.nix` 的“先删后复制”、LibreOffice 运行时 registry 的原地修改。统一的是“所有权/恢复约定”，不是把三种不同文件格式强塞进一个通用函数。

**验收**：保留 GUI-owned 键、注释和插件自定义值；二次激活幂等；解析错误不覆盖原文件；可控制地注入并发写入、复制失败、中断。已有 16 个测试只是基线，不要把现有成功结果当成并发证明。

**回退**：迁移前按文件备份；若实际所有权迁移会覆盖用户选择，先列出具体字段和变化，不能静默以种子替换整个目录。

**实施结果（2026-09-12）**：锁定 Noctalia CLI 提供 `config export/validate`、`msg theme-mode-set`、`msg color-scheme-set` 和 `msg config-reload`，没有按键写入 bar/dock/backdrop 等 Nix-owned 字段的配置层。继续文件协调会与 GUI 竞争，因此未加文件锁、也未改 Home Manager 相对 `systemd-user-sessions` 的顺序。`flatpak-assets.nix` 仍是先删后复制；LibreOffice registry 仍是原地补种。剩余边界：比较后到 replace 前的窗口、GUI 稍后写回、登录时并发。

### F. P2：Qoder 缓存更新的成本与生命周期

**证据**：`scripts/qoder-bundle-cache.sh` 使用包含整个 Qoder 输出路径的 source 标记，变化就重新复制并留下 `cache.previous.*`；没有保留数量或大小策略。独立 launcher 的 flock 只能串行化初始化，不能协调已经运行的 Qoder。

**实施**：先测实际缓存体积及上游写入范围。只有证明确有增长问题，才把标记改为真正的 bundle 内容版本，并提供明确的旧备份整理入口。正常启动必须保持廉价；不要自动删除不确定归属的插件目录。

**验收**：同内容不同包装输出不必重新复制（若选择内容标记）；失败保留可用旧目录；应用正在运行的升级行为可解释；清理策略先 dry-run，用户修改和最近可用版本可恢复。

**回退**：恢复脚本即可；保留的旧缓存不能随代码 revert 自动清空。

**实施结果（2026-09-12）**：用户确认卸载 Qoder 与 ClassIn。包、启动包装和 `qoder-bundle-cache.sh` 已从仓库移除。未删除 `~/.qoder` 用户数据。

### G. P2：把有效检查接入 checks，补齐跨模块契约

**证据**：`checks/default.nix` 当前有脚本回归与两个 portal 选项断言，尚不覆盖实际定时目标、完整 KDL、消费者重启传播、虚拟机失败路径。

**实施**：随 A–F 的修复新增相应检查，而不是先写一套空测试框架。使用真实生成配置和假命令；XML CPU 参数用不同于生产的值验证。Zed 的 config-dump/drift 当前使用 jq，补充 JSONC 支持或明确提示，不应把合法注释设置误报为损坏。

**验收**：故意移除关键修复时对应检查能失败；检查可在临时 HOME/配置目录内完成、不联网、不依赖现有 GUI 状态、不读真实私钥。文件系统操作只作用于测试目录。

网络分流检查另有边界：当前测试只证明特定 DOMAIN/DOMAIN-SUFFIX 遮蔽不存在，不能证明代理节点可用、所有规则类型语义正确或某策略符合用户意图。上一轮 2048 样本等价测试是有限样本证据，不是完整形式化证明。

## 5. 第三阶段：定向拆分，不建立框架

在 A–D 行为修复稳定后，以独立提交处理纯结构整理，不能混入软件升级或视觉调整。

| 当前文件 | 适合的拆分 | 应留在模块内的内容 |
|---|---|---|
| `modules/system/virtualization.nix` | launcher → `scripts/`；Guest Tools 的 PowerShell/CMD → 独立资源；ISO/desktop 包装 → `pkgs/` | enable、用户组、udev、systemd 与主机参数连接 |
| `modules/home/noctalia.nix` | 长 Qt/Heroic 模板 → `assets/noctalia/templates/`；颜色 hook → 独立脚本/包 | 种子设置、模板输入输出、配置所有权 |
| `modules/home/fcitx5.nix` | 主题/SVG 等资源按实际需要迁出 | 图标安装、应用配置和主题选择 |
| `modules/home/apps/libreoffice.nix`、`modules/system/packages.nix` | 若继续改包装，将 LibreOffice/Celluloid 包构造移到 `pkgs/` | 包选择及用户配置 |
| `modules/home/desktop/mime.nix` 与 apps/desktop | 共享确实重复的 MIME 数据列表 | 默认应用选择与 desktop entry 各自的语义 |

**验收**：生成配置内容、desktop entry、运行参数保持一致；比较生成物而不只看源码行数。路径变化造成 store hash 改变不自动代表语义变化；必须解释差异。不设“全部文件小于 100 行”之类指标。

`lib/` 只作为未来选项：比如包装器入口重写真的出现多个共同调用方时，先定义最小契约，再决定是否提取。`mkWaylandSession` 目前只在一个模块使用，`outputOn` 也只有局部用途，保持局部函数即可。

不要改成目录自动扫描 imports：当前显式 imports 易审查，也避免测试文件、旧模块被意外启用。

## 6. 条件性验证清单，不自动实施

| 项目 | 当前判断 | 决策需要的证据 |
|---|---|---|
| Qoder/ClassIn `--no-sandbox` | 已卸载，不再适用 | 用户于 2026-09-12 确认移除包装与 `--no-sandbox` 入口 |
| 全局 `QT_PLUGIN_PATH = mkForce ...` | 作用域偏大，可能干扰其他 Qt 程序 | 两个桌面中的实际环境、插件加载和输入法验证 |
| Zed `trust_all_worktrees = true` | 当前是首次种子，不等于当前 GUI 状态 | 明确所需信任策略；只改 seed 无法迁移已有文件 |
| KDE Connect 两分钟刷新 | 手机切网时电脑侧 QNetworkInformation 不会触发；`--refresh` 即 `forceOnNetworkChange` | 已改为：电脑 NetworkManager 事件立即刷新；定时器仅在没有可达设备时广播。未删除恢复路径 |
| 多套音量、监控、浏览器/音乐工具 | 使用偏好，不是确定冗余 | 用户实际用途；不按包数量评分或批量卸载 |
| GRUB/Plymouth、Fcitx 等外观补丁 | 有成本但也有明确视觉收益 | 定位源补丁大小与升级频率；只移除确认不用/已修复的补丁 |
| 强制关闭休眠和设备工作区设置 | 既有设备规避方案 | 硬件对照测试；不作为“清理默认值”顺手恢复 |
| 镜像源、GC 周期、内核版本 | 不因配置长就改变 | 实际失败率、空间、更新和回退需求 |

已核实不应误报的事项：系统 user 模块存在；没有 lib 目录不是缺少标准依赖；LibreOffice/LocalSend/CC Switch 的已生成 desktop entry 使用 PATH 命令，未发现绝对路径绕过包装；systemd 反向 requiredBy 会形成实际依赖；包重复声明通常不会复制一份 store 内容。

## 7. 给执行模型的操作顺序

1. 阅读当前 AGENTS/README、检查 HEAD 和 `git status --short`，复核本计划 A–D 的证据；不照抄过时行号。
2. 逐项实施 A、B、C、D，每项独立验证与提交。不要因为便于重构而先移动整个目录。
3. 随修复加入 G 的相关回归检查，再处理 E/F；无法确认的并发/缓存策略写明剩余边界，不伪称已解决。
4. 最后按真实收益选择结构拆分；没有稳定复用点就不创建 lib。
5. 只对受影响包做局部构建；规则检查、模板和脚本在临时目录验证。不要为结构整理更新 flake inputs。
6. 提交说明包含行为前后、验证证据、风险与回退方式。用户未另行限制时按 AGENTS 提交推送；实际系统切换由用户 `rebuild`。

可用检查入口：

```bash
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.configuration .#checks.x86_64-linux.portal .#checks.x86_64-linux.niri-config .#checks.x86_64-linux.external-windows-cpu --no-link
nix build .#nixosConfigurations.nixos.pkgs.lilya.<受影响包> --no-link
git diff --check
```

检查锁定模块实现可用：

```bash
nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nix-flatpak.outPath'
nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.niri.outPath'
```

交付完成的标准是：A–D 的原失败路径都有能检出回归的证据；E/F 的所有权与恢复边界清晰；结构整理不改变未授权行为；README 与实际状态一致。新增文件数、删除行数和抽象层数不是完成指标。

当前对照：A–D 已有脚本/单元/flake 检查；E/F 边界已写入本节与 README；结构上只提取了启动器脚本和域 XML 模板。第三阶段其余拆分未做，因为没有新的稳定复用点。Zed dump/drift 已支持 JSONC。
