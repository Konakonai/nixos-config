# 配置审计清单

审计时间：2026-06-30

审计目标：检查当前 `main` 上是否存在实际没有被使用的模块、遗留补丁目录、以及与当前配置输出不一致的历史 workaround。本文档只记录清单，不直接删配置。

## 总览

- 已跟踪的 Nix 模块没有发现明显“文件存在但入口未引用”的情况。`configuration.nix`、`home.nix` 以及 `modules/{desktop,niri,system/display,theme}.nix` 聚合模块都能把对应子模块挂入当前配置。
- 仓库没有跟踪任何补丁文件。工作区里有空的 `patches/` 目录，但 Git 不跟踪空目录；当前提交里不存在需要清理的 `patches/*.patch`。
- `nix eval .#nixosConfigurations.nixos.config.warnings --json` 返回 `[]`，但部分 eval 会打印 `age.sshKeyPaths` 的 obsolete trace。源码里已经使用 `age.identityPaths`，所以这更像 agenix 兼容别名/输入版本问题，而不是本仓库直接写了旧 option。
- 当前实际生成的 specialisation 只有 `battery-saver`。`internal-display-fallback` 仍保留在代码里，但因为 host profile 没有设置 `boot.preferredDisplayParam`，当前不会生成。
- 当前截图快捷键已经回到 niri 原生 action；`swappy`、`grim`、`slurp` 仍在安装包列表里，属于最像“截图实验遗留”的可确认项。

## 可确认后删除或调整

### 1. `swappy` 可能是截图实验遗留

现状：

- `modules/home/apps.nix` 仍安装 `swappy`。
- `modules/niri/binds/system.nix` 的截图快捷键全部是 niri 原生 `screenshot` / `screenshot-screen` / `screenshot-window` action。
- `rg 'swappy|satty|screenshot'` 显示仓库内没有任何快捷键或脚本调用 `swappy`。

影响：

- 如果你不手动从 launcher/terminal 使用 `swappy`，它现在就是多余包。

建议：

- 确认不再需要外部截图编辑器后，从 `modules/home/apps.nix` 删除 `swappy`。
- `grim` 和 `slurp` 也没有被当前 niri 截图快捷键调用，但它们在 `modules/home/cli-tools.nix` 中更像通用 Wayland CLI 工具，建议单独确认，不和 `swappy` 一起武断删除。

证据：

- `modules/home/apps.nix:16`
- `modules/home/cli-tools.nix:23`
- `modules/home/cli-tools.nix:24`
- `modules/niri/binds/system.nix:14`
- `modules/niri/binds/system.nix:17`

### 2. 空目录 `patches/` 与 `assets/kvantum/`

现状：

- 工作区里存在空目录 `patches/`。
- 工作区里存在空目录 `assets/kvantum/KvNordLight/`。
- `git ls-files` 不包含这些目录；`git status --short --ignored` 只显示忽略的 `result` symlink。

影响：

- 它们不会进入提交，也不会影响构建。
- 容易在人工检查时造成“是不是还有补丁/主题资产”的误判。

建议：

- 可以在本地删除空目录，或保留作为未来资产位置。若希望仓库显式保留目录，需要加 `.gitkeep` 并说明用途。

### 3. `age.sshKeyPaths` obsolete trace

现状：

- `modules/system/mihomo.nix` 使用的是 `age.identityPaths`。
- `rg 'sshKeyPaths|identityPaths|age\.'` 没有发现本仓库直接写 `sshKeyPaths`。
- `nix eval .#nixosConfigurations.nixos.config.age --json` 会打印：`Obsolete option age.sshKeyPaths is used. It was renamed to age.identityPaths.`

影响：

- 目前 `config.warnings` 是空数组，主配置 eval 未失败。
- trace 会污染命令输出，之后如果变成严格 warning/error，会影响自动化验证。

建议：

- 优先确认当前 agenix 输入是否仍通过兼容别名暴露 `sshKeyPaths`。
- 如果升级 agenix 或改用新版 option 结构能消除 trace，再单独处理；不要在 `modules/system/mihomo.nix` 里回退到旧 option。

证据：

- `modules/system/mihomo.nix:13`
- `modules/system/mihomo.nix:14`

## 保留但当前是休眠分支

### 4. `internal-display-fallback` specialisation 当前不会生成

现状：

- `modules/system/boot.nix` 只有在 `hostProfile.boot.preferredDisplayParam != null` 时才生成 `internal-display-fallback`。
- 当前 `hosts/lilya-thinkbook/default.nix` 没有 `boot.preferredDisplayParam`。
- `nix eval .#nixosConfigurations.nixos.config.specialisation --apply builtins.attrNames --json` 返回 `["battery-saver"]`。

影响：

- 代码不是未引用模块，但当前不会出现在启动菜单。

建议：

- 如果显示 handoff 问题已经不靠 kernel param fallback 处理，可以删除这段 specialisation 逻辑。
- 如果它只是备用逃生路径，建议在 `hosts/lilya-thinkbook/default.nix` 加注释说明为什么暂时不设置 `preferredDisplayParam`。

证据：

- `modules/system/boot.nix:4`
- `modules/system/boot.nix:236`
- `hosts/lilya-thinkbook/default.nix:15`

### 5. NTFS 只读 udisks 配置当前不会生成

现状：

- `modules/system/display/desktop-services.nix` 从 `hostProfile.storage.readOnlyNtfsVolumes or [ ]` 读取 Windows/NTFS 卷列表。
- 当前 host profile 没有 `storage.readOnlyNtfsVolumes`。
- `nix eval .#nixosConfigurations.nixos.config.environment.etc --apply 'etc: etc ? "udisks2/mount_options.conf"' --json` 返回 `false`。

影响：

- `boot.supportedFilesystems.ntfs = true` 和 `ntfs3g` 仍启用，但专门的 udisks 只读挂载策略不生效。

建议：

- 如果现在没有需要保护的 Windows 分区，可以保留为模板化的本机逻辑。
- 如果你以为 Nemo/udisks 已经对某些 NTFS 卷强制只读，需要把卷 UUID 加进 `hosts/lilya-thinkbook/default.nix` 的 `storage.readOnlyNtfsVolumes`。

证据：

- `modules/system/display/desktop-services.nix:4`
- `modules/system/display/desktop-services.nix:53`
- `modules/system/boot.nix:234`

## 与现状一致的历史 workaround

### 6. QQ Flatpak XWayland override 仍在生效

现状：

- `services.flatpak.packages` 当前生成 `com.qq.QQ`、`com.tencent.WeChat`、`org.onlyoffice.desktopeditors`。
- QQ override 显式启用 `x11` socket，禁用 `wayland` 和 `fallback-x11`。
- Home Manager activation 会写入真实的 `~/.var/app/com.qq.QQ/config/qq-flags.conf`，内容为 `--ozone-platform=x11`。

判断：

- 这不是无用补丁；它是当前配置仍在使用的 app-level workaround。

证据：

- `modules/flatpak.nix:31`
- `modules/flatpak.nix:56`
- `modules/flatpak.nix:75`

### 7. GTK4 `GSK_RENDERER=ngl` 仍是全链路配置

现状：

- Home/session、niri environment、Flatpak override 都保留 `GSK_RENDERER=ngl`。

判断：

- 这不是无用补丁；它是当前桌面渲染行为的一部分。如果要移除，需要先实测 Foliate/GTK4/NVIDIA/niri 的卡顿是否已经被上游修复。

证据：

- `modules/theme/environment.nix:8`
- `modules/niri/core.nix:93`
- `modules/flatpak.nix:7`

### 8. `battery-saver` specialisation 是当前实际输出

现状：

- `modules/system/power.nix` 定义 `specialisation.battery-saver.configuration`。
- 当前 `nix eval` 看到的 specialisation 只有 `battery-saver`。
- 直接 eval `config.specialisation` 整体时曾触发 `fileSystems` 拓扑排序的 `cycle` 报错；但单独展开 `battery-saver.configuration.boot.kernelParams` 成功，标准 warning eval 也为空。

判断：

- 这不是未使用模块，但属于高影响启动路径。后续若继续改，应该构建 toplevel，并按需实机确认启动菜单和 battery-saver 项。

证据：

- `modules/system/power.nix:298`
- `modules/system/power.nix:313`
- `modules/system/power.nix:329`

## README/文档现状

- `README.md` 当前描述 `modules/system/display/` 为 `greetd/gtkgreet`，与现状一致。
- `README.md` 仍说 `modules/home/` 包含 Noctalia、Zen、Yazi、user scripts；当前确实有 `modules/home/noctalia.nix`、`zen.nix`、`yazi.nix`，但 OpenList WebDAV 的 user service 实际在 `modules/desktop/openlist-webdav.nix`。这不是错误，只是布局描述偏概括。
- 根 README 没有提到本次清单里的 dormant 分支；如果后续要减少误判，可以把 `hostProfile.boot.preferredDisplayParam` 和 `hostProfile.storage.readOnlyNtfsVolumes` 的“未设置即不生效”写进对应模块注释，而不是塞进 README。

## 本次用过的核对命令

```bash
git status --short --branch
git ls-files | sort
find patches assets/kvantum -maxdepth 3 -print -ls
rg -n 'swappy|grim|slurp|satty|screenshot' .
rg -n 'sshKeyPaths|identityPaths|age\.' .
nix eval .#nixosConfigurations.nixos.config.warnings --json
nix eval .#nixosConfigurations.nixos.config.specialisation --apply builtins.attrNames --json
nix eval .#nixosConfigurations.nixos.config.home-manager.users.lilya.services.flatpak.packages --json
nix eval .#nixosConfigurations.nixos.config.environment.etc --apply 'etc: etc ? "udisks2/mount_options.conf"' --json
```
