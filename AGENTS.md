# Agent Notes

单机 NixOS 配置（Flakes + Home Manager）。先读 `README.md`：目录布局、配置所有权模型、不在 Git 里的状态都写在那里，本文件只写 agent 的工作规则。

## 分支与提交

| 改动类型 | 例子 | 流程 |
|---|---|---|
| 简单改动 | 增删包、改一个选项值、改注释或文档、改 mihomo 策略组成员 | 直接提交到 `main`。 |
| 影响运行时行为或需要试错 | compositor / 驱动 / 会话 / 电源 / USB / 脚本 / 代理规则 / 主题所有权，任何要 `rebuild` 后观察的东西 | 提交到 `wip/<topic>`，可以多次提交。`rebuild` 后由用户确认可用，再 `git merge --ff-only` 进 `main`；放弃则删除分支。 |

`main` 上每个提交都应是在本机 `rebuild` 过并确认可用的状态。`rebuild` 构建的是当前工作树，所以 wip 改动要在该分支检出时 `rebuild`。

- agent 可以自己运行 `rebuild` / `testbuild` / `bootbuild`（wheel 已免密 sudo）。glibc / systemd / PAM 升级只用 `bootbuild`：live switch 曾弄坏 PAM 导致无法登录。需要重启或注销时交给用户。
- 可以自己 `systemctl start|stop|restart`（含 `--user`）非关键服务：OpenList、rclone 挂载、Jellyfin、restic 备份、普通用户应用服务等，挂了也只影响该服务本身。关键服务仍交给用户：网络与代理（mihomo、NetworkManager、ModemManager、Tailscale）、会话与显示（niri、Noctalia、SDDM、portal）、音频（PipeWire）、D-Bus、登录 / PAM 相关；拿不准就按关键处理。
- Commit message 用简短英文祈使句（`add xxx to system packages`）。
- 不推送 `wip/*`；`main` 按用户指示推送。

## 验证

提交前按改动范围运行（`nix build <attr> --no-link`，前缀 `.#checks.x86_64-linux.`）：

| 改了什么 | 运行 |
|---|---|
| 任何 `.nix` 文件 | `lint`（statix、deadnix、nixfmt；格式问题用 `nix fmt` 修） |
| `scripts/`、`modules/system/mihomo/` | 再加 `configuration`（跑 `scripts/tests/`） |
| `modules/home/niri/` | 再加 `niri-config` |
| mihomo 规则 | 另外 `mihomo -t` 校验生成的配置 |
| `checks/` 本身 | 跑改动的那个 check |

## 编码规范

- **纯声明式**：软件与配置通过 Nix 声明，不用 `nix-env` / `nix profile`。GUI 应用的运行时状态按 README「配置所有权」处理；不要新增 activation 脚本去改用户文件，除非确认没有配置层可用。
- **就近复用**：直接用 `pkgs` / `lib` / Home Manager / plasma-manager 已有能力，不建 `lib/`，不做目录扫描式导入。修改上游包优先局部 override。
- **新文件先 `git add`**，否则 Flake 看不到。
- **敏感信息**：密钥、令牌、代理节点只进 `secrets/*.age`，不进日志、注释或提交说明。
- 每个 workaround 写清"为什么"；没有原因的规则会在下次审计时被删。
- 改了 README 描述的东西（布局、亮点、所有权、备份范围），同步更新 README。
- `docs/` 记录不归 Nix 管理的外部机器状态（`music-server.md`：上海 Navidrome）；改了那边的配置要同步更新文档。
