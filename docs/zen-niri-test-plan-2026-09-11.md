# Zen 双窗口与 Niri 混合显卡测试计划

## 交接目标与边界

工作目录 `/home/lilya/nixos-config`，先读 README.md 和 AGENTS.md。
用户已重启、关闭独显直连，允许调查和后续测试。本计划供另一个模型执行，
本次调查没有修改应用状态、显示模式、驱动或会话配置。

按顺序执行 Z1–Z3、N1–N3；每一步记录结论，不同时叠加多个变量。
不启用 SMT/USB 旧策略，不恢复 battery-saver，不全量更新 flake，不删除浏览器会话文件。
关浏览器、注销 Niri 前让用户保存工作并自行完成，先把测试状态写到本地记录。
中断后先核实当前配置和进程，不能以“配置文件已经修改”代替运行时确认。

## 调查基线（2026-09-11，本次会话）

### Zen

- 包：`zen-beta-1.22b`，应用 build ID `20260904060728`。
- 正式 profile：`/home/lilya/.config/zen/i41yvfec.Default Profile`。
- `profiles.ini` 只有一个 profile。正式 desktop entry 使用 `%U`，没有 `X-MultipleArgs=false`。
- 当前包 wrapper 已带 `--name=zen-beta --class=zen-beta`；仓库 launch-zen-beta 又加了一次
  `--name zen-beta`。这是冗余，尚未证明是双窗口起因。
- 浏览器未运行时，只读解码 `sessionstore.jsonlz4` 和 `sessionstore-backups/previous.jsonlz4`：
  均有 `windows=2`、`_closedWindows=0`，每个窗口 13 个 tabs，并有 closedAt/closedId。
  一个窗口仍带 `_shouldRestore=true`。两个窗口的导航 entries **并不完全相同**，不能直接去重删除。
- 随后用户运行 Zen，Niri 窗口 10、11 均对应 PID 7570，命令行没有 URL 或 `--new-window`。
  同一进程本身不能排除第二次启动经 remote handshake 进入同一实例，但结合会话文件，
  恢复路径是第一优先级。
- 包内 `SessionStore.sys.mjs`：非 macOS 关闭窗口时设置 `_shouldRestore`；后续标签事件
  调用 `_clearRestoringWindows()` 清除此标记。
- 包内 `SessionSaver.sys.mjs`：保存前把带该标记的已关闭窗口重新放回 `state.windows`。
- 包内 `ZenSessionManager.sys.mjs:onCrashCheckpoints`：即便 `browser.startup.page=1`，
  仍处理会话里的所有窗口；该偏好主要改变恢复哪些标签。
- 包内 `zen.window-sync.enabled` 默认为 true，正式 prefs.js 没有覆盖。

结论：非常符合“连续关窗被视为退出时保留多窗口 + Zen 窗口同步恢复”的路径。
第一次额外窗口是如何产生的仍需 Z1/Z2 区分，不能把所有原因都归给启动器。

### Niri

- 内核 `7.2.4`、NVIDIA closed driver `595.99.02`，Niri `dd75865`。
- Intel `0000:00:02.0` / i915：`card1`、`renderD128`，负责 `eDP-1`。
- NVIDIA `0000:01:00.0`：`card2`、`renderD129`，负责正在连接的 `HDMI-A-1`。
- Niri 启动日志明确选择 `/dev/dri/renderD128`，即 Intel 渲染。
- 外屏实际为 3840×2160@60Hz、scale=1.5；内屏虽连接，但 current_mode/logical 为 null，即关闭。
  因而这次现象不能简单归因于“内外屏刷新率不同”。
- 稳定 NVIDIA render 路径：`/dev/dri/by-path/pci-0000:01:00.0-render`。
- 有一条 HDMI vblank 节流警告；没有本次扫描到的 NVIDIA Xid/GPU hang。单条警告不证明根因。
- 两个 satellite：手动自启动 PID 2261，及 Niri 内置按需启动 PID 2410（带 :0/-listenfd）。
- 启动日志还有 AccessKit 辅助功能线程 panic，Niri 主进程继续运行；单列记录，不当作渲染卡顿证据。

结论：Intel 合成 → 跨 GPU 传输 → NVIDIA HDMI 扫描输出，是当前首要性能嫌疑。
尚未测量具体复制/同步耗时；需要 N1 单变量 A/B 才能确认效果。

## Z1：用隔离 profile 验证恢复路径

1. 记录当前正式 profile、Zen 包路径、进程/窗口数量。不要打印标签 URL、Cookie 或完整 prefs.js。
2. 用户正常退出 Zen，确认主进程和 profile lock 已释放。不要强制杀进程来制造崩溃状态。
3. 在 `~/.local/state/nixos-config-tests/zen-<时间戳>/` 创建权限 0700 的目录。
   完整复制正式 profile 为 `golden`，再从 golden 复制各测试 case；原 profile 不修改。
   复制完成后记录文件数与大小，不把这些目录提交 Git 或上传。每个 case 从同一 golden 复制。
4. 动态获取当前包：

   ```sh
   nix eval --raw .#nixosConfigurations.nixos.config.home-manager.users.lilya.programs.zen-browser.package.outPath
   ```

5. 直接用该包的 `bin/zen-beta --no-remote --profile <case绝对路径>` 启动一个克隆。
   用 Niri 窗口列表和进程 `--profile` 参数确认确实是克隆，不是正式 profile。
6. 记录首次窗口数；若为两个，先在克隆中确认各窗口标签内容，关闭一个多余窗口，
   在剩余窗口 `Ctrl+T` 再 `Ctrl+W`，等待 15 秒再正常退出，重新启动同一克隆。
7. 连续正常退出/启动 3 次；每次只发一次启动命令。记录窗口数。
8. 另一个 golden 克隆做对照：开两个窗口后连续关闭，不做中间标签操作，再启动。

判定：标签操作组稳定为 1、连续关窗组恢复为 2，支持已定位的 restoring-window 路径。
如果两组都不稳定，进入 Z2，不重复清空 sessionstore。

正式 profile 的处理：只有克隆验证通过后，才在用户确认保留所有需要的标签后，
通过浏览器 UI 关闭多余窗口并进行标签操作，让浏览器自己保存单窗口状态。
优先保留窗口同步功能；不直接改写 JSONLZ4、不清空恢复数据。

## Z2：启动入口对照与最小修复

使用独立 case，不复用上一组已经改变的初始会话。记录 PID、窗口数和启动参数。

| case | 启动入口 | 目的 |
| --- | --- | --- |
| A | 包内 `bin/zen-beta --no-remote --profile <case>` | 排除额外 launcher 的影响 |
| B | 读取正式 desktop entry 指向的 launch-zen-beta，附加同样的隔离 profile 参数 | 仅比较重复 `--name` 的影响 |
| C | 空目录 profile，直接启动包内命令 | 区分已有状态问题与首次启动问题 |

若 A/B 相同，双窗口不归咎于重复 `--name`。这层参数仍可作为独立无行为变化的清理移除，
但不能宣称它修好了会话恢复。若仅 launcher 路径失败，先记录实际调用次数和参数，
再检查 Noctalia/desktop entry；不要凭 `%U`/`%u` 的网上建议盲改。

通过 UI 修复状态后验收：菜单冷启动 3 次各一个窗口；已有窗口时打开一个测试链接，
没有多余空窗口；显式“新建窗口”仍能工作；标签、固定标签、workspace 保留。

## Z3：仅当 Z1 不足时评估长期选项

- 若用户很少用窗口同步，可在**克隆 profile**测试 `zen.window-sync.enabled=false`。
  克隆里的 user.js 若控制某个偏好，要同步处理，否则 GUI 修改会在重启时被覆盖。
- 该选项会改变多窗口共享标签行为，不默认用于正式 profile。
- 如果用户需要同步、且正常 UI 修复后仍反复复发，再评估上游修复版本或精确局部补丁。
  不引入每次启动删文件、无限自动关窗或未经审查的高权限 autoconfig 脚本。
- 暂不删除现有 startup/sessionstore 偏好来与其他变量混测；确认窗口根因后再单独简化。

## N1：只切换 Niri 合成 GPU

1. 保存仓库状态、Niri PID/start time、输出模式、DRM by-path、启动日志。
   `card1/card2/renderD128` 是本次编号，下一次先重新映射，不能硬编码编号。
2. 保持 HDMI 4K60、scale=1.5、内屏关闭，固定同样两个窗口。
   基线做 3 轮各 30 秒：打开/关闭 overview、横向滚动工作区、移动窗口。
   用户分别记录流畅度；采样 GPU 利用率只能作为辅助，不能把它直接换算成 FPS。
3. 只在 `modules/home/niri/core.nix` 的 `programs.niri.settings` 中加入：

   ```nix
   debug.render-drm-device = "/dev/dri/by-path/pci-0000:01:00.0-render";
   ```

   本次确认当前 Niri 支持该选项及设备路径。不要设置 GBM_BACKEND、WLR_DRM_DEVICES、
   __NV_PRIME_RENDER_OFFLOAD，不更换驱动，不同时添加等待帧完成的选项。
4. `nix-instantiate --parse`、`nix flake check --no-build`；构建生成的 Niri config，
   用 `niri validate` 检查。配置含相对 `include "noctalia.kdl"`，验证目录需要附带该文件。
5. 写下回滚步骤与 checkpoint，用户运行 `testbuild` 并正常注销、重新登录 Niri。
   选择渲染节点发生在 compositor 初始化；热重载或在现有会话里 nested niri 不是有效测试。
   不要由助手直接杀死当前 Niri/显示管理器。
6. 新会话先检查新 PID/start time 和日志 `using as the render node`，必须映射到 NVIDIA。
   仍为 Intel 时不接受性能结果，先修正测试启动路径。
7. 保持同样显示状态，重复基线动作。然后移除本次唯一配置改动，testbuild、重新登录，
   再做一轮 Intel 回测。不要用 git restore 丢弃用户同时产生的其他修改。

判定：NVIDIA 明显改善且回到 Intel 再次卡顿，则将跨 GPU 路径确定为主要影响因素。
“明显改善”需有相同条件下的用户比较；没有帧时间工具时诚实记录主观 A/B，不编造数字。

异常回滚：用户切到 TTY 或保留的 Plasma 会话，移除这一条 debug 设置后运行 testbuild，
再登录 Niri。若只是 testbuild 尚未持久化，重启也会回到之前的启动 generation。
不要为测试删除 Plasma 登录入口或更改 BIOS。

## N2：仅在 N1 仍有问题时细分同步与带宽

以 N1 的 NVIDIA 组为基础，只增加一个选项：

```nix
debug.wait-for-frame-completion-before-queueing = [];
```

同样重新登录核实配置和 PID，再比较卡顿、输入延迟以及 vblank 警告。
该选项会改变队列同步，可能增加延迟；没有收益就移除，不能与 GPU 切换同时首次加入。

若仍卡顿，用 `niri msg output HDMI-A-1 mode --help` 确认语法，临时降低外屏到其实际列出的
1080p60 模式；记录原模式并恢复 4K60。只把这作为带宽/像素量对照，不当作最终解决方案。
之后才考虑驱动 open/closed 对照或版本升级，单独询问并制定回退方案。

## N3：单独清理重复 Xwayland 启动

GPU A/B 完成后，移除 `modules/home/niri/core.nix` 中显式启动 `xwayland-satellite` 的一行，
保留包和现有 Steam 菜单补丁。Niri 已内置按需启动，官方文档建议移除手动启动配置。
重新登录，启动一个 X11 应用，确认只留下内置管理实例、DISPLAY 正常。
检查 Steam 菜单、WeChat 输入、X11 字体；若字体脚本只作用于旧 DISPLAY，再做独立修复。
不能把此项和 N1 同时修改后将流畅度提升全部归给 GPU。

## 成功后的配置方案

- N1 成功：保持 BIOS 混合模式，外屏场景用 NVIDIA 合成、移动场景用 Intel。
  优先实现两个明确的 Niri 会话/渲染配置；或在会话启动时根据连接到 NVIDIA 的外接输出选择。
  使用稳定 PCI by-path，保留 Intel 回退。当前 Niri 单个会话使用一个主渲染 GPU，
  不承诺热插拔时无缝切换主 GPU；内屏双屏模式还要验证跨 GPU 传输方向变化后的效果。
- 用户常用外接单屏时，可先保留一个 NVIDIA Niri 配置，代价是移动使用时耗电更高。
- Zen 优先正常化会话状态，移除无用 launcher 参数；只有经验证的必要行为才持久化。

最终交付：测试矩阵、通过/失败/未测、运行时证据、保留的最小差异、回滚方法。
验证通过的仓库改动按 AGENTS.md 提交推送；测试临时数据不提交。需要保存的用户备份不自动删除。

## 参考

- [Niri FAQ：混合显卡外屏卡顿](https://github.com/niri-wm/niri/blob/main/docs/wiki/FAQ.md)
- [Niri debug 选项](https://github.com/niri-wm/niri/blob/main/docs/wiki/Configuration%3A-Debug-Options.md)
- [Niri Xwayland 集成](https://github.com/niri-wm/niri/blob/main/docs/wiki/Xwayland.md)
- [Zen 双窗口报告与恢复逻辑讨论](https://github.com/zen-browser/desktop/issues/12140)
- [Zen Window Sync 恢复报告](https://github.com/zen-browser/desktop/issues/14229)

这些 issue 中的解释仅作线索；上面的关键恢复逻辑已与本机 1.22b 包内代码核对。
