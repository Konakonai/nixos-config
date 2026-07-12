# NixOS 仓库结构与运行态配置所有权建议

调研日期：2026-07-12

## 实施状态

截至 2026-07-12，路线图阶段 1–5 已完成：

- Hermes 及其本机数据已移除；
- Noctalia 与 Zed 已改为应用拥有的可写配置，并通过二次部署验证；
- `config-drift`、`config-dump` 与 `config-repair` 已部署并完成运行态验收；
- 模块已收敛为 `modules/system/`、`modules/home/`、`modules/shared/`；
- NixOS 与 Home Manager 使用显式薄聚合器；
- `lilyaGlass` 只在 flake 入口构造一次，并统一通过模块参数传递；
- OpenList daemon 与 WebDAV mount 已分别归入 system/home services；
- 应用专属 Desktop Entry 已跟随对应应用模块；
- 本地包统一由 `pkgs/default.nix` 构造，并通过 `pkgs.lilya` 提供给模块；
- 普通 system services 与 Home 应用组已按职责拆分；
- LocalSend wrapper、GRUB theme 与 Plymouth theme 的 packaging 已移入 `pkgs/`；
- 旧的兜底 `apps.nix`、通用 Desktop Entry 模块、空目录与 Hermes 遗留 Electron 包已清理。

阶段 4 的每个纯路径迁移，以及阶段 5 的 package/service/application 收敛，均通过完整 toplevel 构建与闭包差异审查。下一步是阶段 6 的高影响模块设计；在获得明确确认前，不改变 boot、display、network 或 power 行为。

## 结论

当前仓库不需要迁移到 dendritic、flake-parts 或“所有模块全局导入”的大型框架。最适合这台单主机配置的方向是：

1. 保留当前 `configuration.nix`、`home.nix` 和 `hostProfile` 的显式入口；
2. 用薄聚合器统一 NixOS 与 Home Manager 的目录层级；
3. 优先拆分已经超过单一职责的 `power.nix`、`services.nix` 和 boot theme packaging；
4. 建立统一的本地 package set，避免安装模块和 desktop-entry 模块分别实例化同一 package；
5. 按文件所有权区分声明式配置和运行态配置，而不是以“能否写成 Nix”作为判断标准；
6. Noctalia、Zed、Qt6ct 等会主动保存 GUI 设置的应用应获得真实可写文件；
7. Nix 只强制兼容性、安全和跨应用契约，个人界面偏好默认留在运行态；
8. 若要让运行态设置可回收到 Git，提供显式的 `dump`、`diff`、`apply` 工具，不在每次 `rebuild` 时静默覆盖。

推荐的目标不是“100% 声明式”，而是：稳定事实可复刻，运行态偏好可调，所有权冲突可见，持久化动作明确。

## 调研范围与筛选方法

通过 GitHub repository search 检索以 Nix 为主、描述为 NixOS configuration/dotfiles、star 数不少于 500 的仓库。排除了 `nvf`、`niri-flake`、NixOS 配置编辑器、操作系统发行版等产品或框架仓库，只保留个人或团队实际使用的系统配置。

star 数是调研当日通过 GitHub API 读取的快照，会继续变化；它只用于满足样本门槛，不代表设计必然适合本仓库。

| 仓库 | Stars | 选取原因 |
| --- | ---: | --- |
| [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration) | 5421 | 单机桌面配置、out-of-store symlink 和可写复制 |
| [mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) | 3049 | 简洁的 machine/user 分离和 `mkSystem` 组合 |
| [max-baz/dotfiles](https://github.com/max-baz/dotfiles) | 1077 | 按平台和功能拆分、Home Manager 与 NixOS 组合 |
| [sioodmy/dotfiles](https://github.com/sioodmy/dotfiles) | 916 | system/user 分层和求值性能意识 |
| [MatthiasBenaets/nix-config](https://github.com/MatthiasBenaets/nix-config) | 741 | feature-oriented dendritic modules 和 Noctalia 声明 |
| [wimpysworld/nix-config](https://github.com/wimpysworld/nix-config) | 697 | typed host metadata、self-gating modules、运行态文件字段级合并 |
| [EmergentMind/nix-config](https://github.com/EmergentMind/nix-config) | 635 | core/optional/host/user 分层和完整 Noctalia 声明 |
| [srid/nixos-config](https://github.com/srid/nixos-config) | 583 | KISS、flake-parts 和自动接线目录 |
| [kclejeune/system](https://github.com/kclejeune/system) | 525 | Noctalia 可写播种、运行态 diff/dump 工作流 |

## 第一部分：仓库结构与模块层级

### 1. 主机事实、用户事实和功能实现应分开

[mitchellh/nixos-config 的 `mkSystem`](https://github.com/mitchellh/nixos-config/blob/d314004/lib/mksystem.nix) 分别选择：

- `machines/<name>.nix`：机器配置；
- `users/<user>/nixos.nix`：用户在系统层的配置；
- `users/<user>/home-manager.nix`：用户环境；
- `lib/mksystem.nix`：组合逻辑。

这与本仓库现有的 `hostProfile` 方向一致。值得借鉴的不是复制目录名称，而是维持三种信息的边界：

- 主机事实：显示器身份、PCI 地址、sysfs 路径、用户目录；
- 功能实现：如何生成 Niri、power specialisation、systemd unit；
- 组合关系：本机启用哪些模块。

本仓库的 `hosts/lilya-thinkbook/default.nix` 已经正确承担“事实”角色，不应继续塞入 shell script 或完整 module implementation。

### 2. `core` 必须足够小，其他能力应显式可选

[EmergentMind/nix-config 的结构说明](https://github.com/EmergentMind/nix-config/blob/d1ffb8b/README.md#structure-quick-reference) 把配置分成：

- `core`：所有目标无条件需要；
- `optional`：多个目标可复用但并非必需；
- host/user-specific：只描述特定机器或用户；
- `modules`：带 option 的通用实现；
- `pkgs`、`overlays`、`lib`：各自独立。

其最有价值的规则是“如果不是所有目标都需要，就不能叫 core”。本仓库目前只有一个主机，不需要照搬 `core/optional` 两层，但可以采用同样的判断：

- `home.nix` 和 `configuration.nix` 只负责组合；
- `modules/home/apps.nix` 不应逐渐成为所有 GUI 应用的兜底文件；
- `modules/system/services.nix` 不应继续接收互不相关的 service；
- 新功能应落到最接近其能力边界的模块。

### 3. 按功能组织比按 Nix option 前缀组织更容易维护

[MatthiasBenaets/nix-config](https://github.com/MatthiasBenaets/nix-config/blob/583fcff/README.md#structure) 使用 feature-oriented modules：模块按编辑器、GUI、硬件、程序、服务、主题组织，而 host 只组合功能。

这个原则适用于本仓库，但不需要引入 import-tree 或 dendritic pattern。建议继续使用显式导入，并把 Home Manager 层收敛为：

```text
modules/
├── system/
│   ├── display/
│   ├── power/
│   ├── services/
│   └── ...
├── home/
│   ├── apps/
│   ├── desktop/
│   ├── niri/
│   ├── services/
│   ├── theme/
│   └── ...
└── shared/
    └── glass-settings.nix
```

`modules/home.nix` 和 `modules/system.nix` 可以作为薄聚合器；也可以保留当前 `home.nix`、`configuration.nix` 的显式列表。关键是不要同时保留 `modules/home/*.nix` 与 `modules/*.nix` 两套 Home Manager 落点。

### 4. 大型自动导入框架解决的是多主机扩展，不是目录美观

[wimpysworld/nix-config](https://github.com/wimpysworld/nix-config/blob/a8191e3/README.md#architecture) 使用 broadcast-and-gate：所有模块导入所有 host，再根据 typed host metadata 自行 `mkIf`。

[srid/nixos-config](https://github.com/srid/nixos-config/blob/10d3597/README.md#directory-layout) 和 MatthiasBenaets 则通过 flake-parts 自动接线目录。

这些方案在大量主机、用户和平台下能减少 import lists，但对当前单主机仓库会带来：

- 更长的求值和调试路径；
- 隐式激活关系；
- 需要维护额外 option schema；
- “文件存在即参与求值”的认知成本。

因此本仓库应继续显式导入。只有出现至少三个真实主机、共享 feature 组合不断重复时，再考虑 typed profile 或自动导入。

### 5. package 应有唯一构造入口

高星多主机仓库普遍把本地包集中在 `pkgs/`，再通过 overlay 或 package set 暴露给模块，而不是在多个功能模块中分别 `import ../../pkgs/foo.nix`。

本仓库应建立一个最小 package set，例如：

```nix
{
  lilyaPackages = {
    antigravity = pkgs.callPackage ./pkgs/antigravity.nix { };
    cc-switch-cli = pkgs.callPackage ./pkgs/cc-switch-cli { };
    hermes-desktop = pkgs.callPackage ./pkgs/hermes-desktop.nix { inherit inputs; };
    mindustry = pkgs.callPackage ./pkgs/mindustry.nix { };
  };
}
```

然后安装模块和 desktop-entry 模块消费同一个实例。对于单仓库，不必为了这一点单独引入复杂 overlay；通过 `specialArgs`/`extraSpecialArgs` 传递也足够。

### 6. 大模块的拆分应跟随验证边界

优秀的拆分不只是缩短文件，而是让每个模块有独立验证方法。本仓库建议：

```text
modules/system/power.nix                 # 聚合器
modules/system/power/base.nix            # upower、thermald、logind
modules/system/power/charge-limit.nix    # conservation helper 和权限
modules/system/power/device-rules.nix    # USB/input udev rules
modules/system/power/battery-saver.nix   # specialisation、脚本和 units

modules/system/services/openlist.nix
modules/home/services/openlist-webdav.nix

pkgs/touhou-grub-theme.nix
pkgs/touhou-plymouth-theme.nix
```

这样分别对应 systemd unit、udev、boot specialisation、package build 等验证缝隙，不是纯粹为了目录对称。

## 第二部分：声明式配置与运行态所有权

### 1. 先判断文件协议，再决定是否声明式

应用配置可以分为四类：

| 类型 | 典型特征 | 推荐策略 |
| --- | --- | --- |
| 静态文本配置 | 程序只读，不主动保存 | Home Manager store symlink |
| 稳定策略配置 | 安全、兼容性、服务契约 | Nix 完整拥有或每次重置 |
| GUI 运行态配置 | 应用会原子替换、即时保存 | 应用拥有真实文件 |
| 混合配置 | Nix 需要保证少量键，应用维护其他键 | 字段级 merge 到真实文件 |

Kitty、Fastfetch、Starship、MangoHud 的基线通常属于前两类；Noctalia、Zed、Qt6ct、当前 skin/theme/model 等属于后三类。

### 2. 高 star 不代表应该照抄完整 Noctalia 声明

[MatthiasBenaets 的 Noctalia 模块](https://github.com/MatthiasBenaets/nix-config/blob/583fcff/modules/programs/noctalia.nix) 声明了 bar、dock、颜色、插件和 widget。

[EmergentMind 的 Noctalia 模块](https://github.com/EmergentMind/nix-config/blob/d1ffb8b/home/common/optional/desktops/noctalia.nix) 更进一步，声明了数百行 launcher、audio、brightness、calendar、control center、widgets、animation 等设置。

这些仓库证明“完整声明 Noctalia”是一种常见选择，但不能证明它适合需要通过 GUI 高频试调的人。其代价仍然是：

- GUI 状态与仓库状态存在两个来源；
- store-backed symlink 可能阻止应用写入；
- 原子替换后会产生 drift 或下次 activation 冲突；
- 每个滑块都变成一次 Git 修改和 rebuild。

本仓库不应以 star 数为理由继续扩大 `programs.noctalia.settings`。

### 3. 可写播种适合“运行时可试，切换时回到基线”

[kclejeune/system](https://github.com/kclejeune/system/blob/2713d3c/modules/home/hyprland.nix#L147-L156) 明确把 Noctalia 配置定义为：

- activation 时从声明式 asset 重新播种；
- 部署后是 mode `0644` 的普通文件；
- GUI 修改在当前运行周期有效；
- 下次 switch/reboot 回到声明式基线；
- 通过专门命令 dump、diff、apply 运行态配置。

实际部署逻辑使用 `install` 而不是 Home Manager symlink，见 [bootstrap 代码](https://github.com/kclejeune/system/blob/2713d3c/modules/home/hyprland.nix#L663-L688)；同时提供 [运行态抓取与差异工具](https://github.com/kclejeune/system/blob/2713d3c/modules/home/hyprland.nix#L896-L954)。

这是比只读 symlink 更好的完整声明式方案，但它仍会在每次 activation 覆盖 GUI 修改。只有当“rebuild 即回到已提交基线”是明确产品语义时才应采用。

### 4. 字段级 merge 是混合配置的最佳默认

[wimpysworld 的 Paseo 配置](https://github.com/wimpysworld/nix-config/blob/a8191e3/home-manager/_mixins/agentic/paseo/default.nix#L91-L93) 明确指出应用会重写 JSON，因此不能使用 managed symlink。

其 activation 先读取现有 JSON，只覆盖 daemon 冲突等少量强制字段，再保留应用加入的其他内容，见 [字段级 merge](https://github.com/wimpysworld/nix-config/blob/a8191e3/home-manager/_mixins/agentic/paseo/default.nix#L128-L145)。

这一模式最适合：

- Zed 中必须存在的 MCP/context server；
- GUI 应用的兼容性开关；
- 应用可以自由维护、但 Nix 必须保证少数 invariant 的配置。

写入必须采用临时文件加原子 `mv`，并只改明确 allowlist 的键。不要用一份完整声明式对象覆盖现有 JSON。

### 5. 真实可写文件不等于放弃声明式

[wimpysworld 的 Codex 模块](https://github.com/wimpysworld/nix-config/blob/a8191e3/home-manager/_mixins/agentic/codex/default.nix#L251-L254) 选择 activation 部署真实可写 `config.toml`，因为应用需要保存运行态状态，store symlink 是错误目标。

该仓库同时保留声明式 baseline，并明确哪些 runtime key 可以被导入，见 [配置生成和 merge 说明](https://github.com/wimpysworld/nix-config/blob/a8191e3/home-manager/_mixins/agentic/codex/default.nix#L409-L419)。

可复刻性可以来自以下契约，而不一定来自只读文件：

- Nix 定义必须存在的键；
- 应用自由管理未受约束的键；
- activation 有确定的 merge 规则；
- diff/dump 工具让 drift 可检查；
- 恢复命令是显式动作。

### 6. out-of-store symlink 适合开发配置，不适合本仓库默认路径

[ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration/blob/d66c4a5/config/sessions/hyprland/default.nix#L53-L63) 混合使用：

- `mkOutOfStoreSymlink`，让脚本直接指向工作区；
- `rsync --update` 复制模板和配置；
- `chmod u+w` 保持运行态可写。

优点是修改仓库文件后可以立即生效，无需重建；缺点是：

- 路径硬编码到 `/etc/nixos`；
- 配置依赖工作区位置；
- 绕过 Nix store 快照；
- rollback 无法保证还原外部文件内容。

本仓库以可复刻、可审计为目标，不应把 out-of-store symlink 作为 Noctalia/Zed 的默认解法。它更适合正在开发的 Neovim、脚本或主题源码。

## 针对当前仓库的配置所有权矩阵

| 配置 | 当前状态 | 推荐所有权 | 推荐机制 |
| --- | --- | --- | --- |
| Noctalia shell/bar/OSD/notification | store-backed 完整声明 | Noctalia | 普通运行态文件，不在 Nix 中逐项声明 |
| Noctalia template 注册 | 与 GUI 设置共用文件 | 混合 | 一次性初始化或字段级 merge |
| Noctalia template 源码 | Nix store 生成 | Nix | 继续声明式生成 |
| Qt6ct `qt6ct.conf` | store-backed 完整声明 | Qt6ct | 普通文件；Nix 只保证平台主题与必要默认值 |
| Qt Noctalia color scheme | Noctalia 动态生成 | Noctalia/Nix 契约 | 保留模板生成 |
| Zed `settings.json` | Home Manager baseline，但已被应用替换为普通文件 | Zed/混合 | 应用拥有；必要键字段级 merge |
| Fcitx Classic UI 字体/主题 | store-backed | Fcitx 或 Nix | 若经常 GUI 调整则释放；否则保留 |
| Hermes skin 文件 | activation 生成并强制选择 | 混合 | Nix 生成 skin，不强制 active skin |
| QQ Wayland flags | activation 强制重写 | Nix | 保留，属于兼容性 invariant |
| Flatpak app 清单 | 严格删除 unmanaged | Nix 或用户 | 是否保留取决于是否允许临时试用应用 |
| Kitty/Fastfetch/Starship | store-backed | Nix | 保留，属于静态文本配置 |
| MangoHud baseline | store-backed | Nix | 保留；游戏差异放 profile/launch option |
| Yazi workflow/keymap | store-backed | Nix | 保留；确认 Noctalia 不同时写 `theme.toml` |

## 推荐的 Noctalia 方案

### 方案 A：运行态优先，推荐

Nix 负责：

- 安装和启用 Noctalia；
- 生成 Darkly Qt、Heroic、CC Switch 模板源码；
- 安装模板依赖；
- 提供 `noctalia-template-repair` 或首次初始化命令。

Noctalia 负责：

- 整个 GUI settings 文件；
- bar、widget、animation、wallpaper、theme 和位置；
- template 是否启用及运行态状态。

优点：GUI 即时设置是唯一来源；不会在 rebuild 后意外回退。缺点：新机器需要一次初始化，完整 GUI 偏好不自动复刻。

### 方案 B：可写播种，加显式 capture

采用 kclejeune 的模式：

- 仓库保存 Noctalia baseline asset；
- activation 用 `install` 写普通文件；
- 提供 `noctalia-settings-diff` 和 `noctalia-settings-dump`；
- 用户明确执行 capture 才把运行态变更带回 Git。

优点：可复刻且 GUI 当前会话可写。缺点：每次 `rebuild` 都会覆盖未 capture 的修改。

### 方案 C：字段级 merge

只强制模板注册、hook 或跨应用契约，其他字段全部保留。技术上最精确，但需要维护 TOML/JSON schema 和 merge 规则。

对于当前需求，建议先使用方案 A；只有确认需要在重装时复刻完整 Noctalia 布局，再升级到方案 B。不要直接实现方案 C，除非 Noctalia 提供稳定 schema 或独立 include 文件。

## 渐进实施顺序

以下步骤应分别提交，避免结构移动和行为变化混在一起。

### 阶段 1：消除运行态所有权冲突

1. 备份当前 Noctalia、Qt6ct 和 Zed 运行态设置；
2. 让 Noctalia 自己拥有主配置文件；
3. 保留模板源码生成，改为一次性初始化或 repair 命令；
4. 释放 `qt6ct.conf`，保留 Noctalia color scheme；
5. 释放 Zed 的模型、字号、主题和 favorites，仅 merge 必要键；
6. Hermes 只生成 skin，不更改当前选择；
7. 决定 Flatpak 是否继续 `uninstallUnmanaged = true`。

验证重点不是只有 `nix flake check`，还包括：

- GUI 修改后文件仍是普通文件；
- 应用重启后修改保留；
- `rebuild` 后符合选定的 A/B/C 语义；
- Noctalia 改色仍能更新 Qt/Heroic/CC Switch；
- Zed 保存设置时不会产生 Home Manager collision/backup。

### 阶段 2：统一模块结构

1. 统一 `lilyaGlass` 传递方式；
2. 把所有 Home Manager 模块收敛到 `modules/home/`；
3. 将 OpenList daemon 和 WebDAV mount 分别放入 system/home services；
4. 拆分 `power.nix`；
5. 把 boot theme derivation 移到 `pkgs/`；
6. 建立本地 package set。

只做路径迁移时必须保持生成结果不变，并用 `nvd diff` 确认没有闭包漂移。

### 阶段 3：补充可观察性

为混合配置提供统一 helper：

```text
config-drift noctalia
config-dump noctalia
config-drift zed
config-repair noctalia-templates
```

这些命令应默认只读；`dump` 输出到 stdout，由用户自行重定向并检查 Git diff。不要在 activation 中自动把运行态数据写回仓库。

## 不建议采用的做法

- 不因为高星仓库使用 flake-parts/dendritic 就迁移当前单主机配置；
- 不把整个 `~/.config` 纳入 Home Manager；
- 不用 `force = true` 掩盖应用与 Home Manager 的所有权冲突；
- 不用 activation 无条件删除并重建 GUI 配置，除非“每次部署重置”是明确语义；
- 不使用 out-of-store symlink 管理硬件、服务或安全关键配置；
- 不将运行态数据库、窗口历史、最近项目、当前壁纸和 active skin 提交到仓库；
- 不把高星仓库中的完整 Noctalia settings 当作最佳实践；它只是选择了更强的声明式所有权。

## 决策规则

新增配置前依次回答：

1. 应用是否会主动写这个文件？
2. 修改是否应在 GUI 中立即生效？
3. `rebuild` 后回退是否会让用户意外？
4. 这是兼容性/安全 invariant，还是个人偏好？
5. 能否只声明必要字段，而不是拥有整个文件？
6. 是否需要 diff/dump，而不是自动覆盖？

若答案是“应用会写、GUI 应即时生效、回退会意外、只是偏好”，则文件应由应用拥有。若只是其中少数字段必须受控，使用字段级 merge。只有程序从不写入或配置就是稳定策略时，才使用 store-backed symlink。

## 最终建议

本仓库应采用“显式模块组合 + hostProfile 主机事实 + 分层文件所有权”的中等复杂度方案：

- 结构上借鉴 mitchellh 和 EmergentMind 的边界，而不引入它们所有目录；
- 运行态上优先借鉴 wimpysworld 的字段级 merge；
- 需要完整复刻时借鉴 kclejeune 的可写播种和 dump/diff；
- 只把 ilyamiro 的 out-of-store symlink 用于需要即时开发的源码；
- 把 MatthiasBenaets/EmergentMind 的完整 Noctalia 声明视为可选取舍，而不是默认答案。

这样既保留 NixOS 配置的可复刻和可审计性，也不会让 Noctalia、Zed、Qt6ct 等本来支持即时调整的应用退化成“每调一个滑块都必须改 Nix 并 rebuild”。
