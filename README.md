# lilya's NixOS configuration

个人 ThinkBook 16p 的 NixOS + Home Manager 配置（Flakes）。默认会话 **Niri + Noctalia**，备用 **Plasma (Wayland)**。自动化修改前先读 [AGENTS.md](AGENTS.md)。

## 布局

```text
flake.nix                    inputs、overlay、nixosConfigurations.nixos、checks、packages、formatter
configuration.nix / home.nix 系统与 Home Manager 入口
hosts/lilya-thinkbook/       主机事实：用户路径、显示器、GPU、外接 Windows 盘、age 身份路径
modules/system/              NixOS：boot、display、power、usb-c、mihomo、virtualization …
modules/home/                用户环境：apps、desktop、niri、theme、flatpak、services …
modules/shared/              theme-settings.nix，系统与用户共用的主题参数
pkgs/                        本地包与上游包的局部覆盖，导出为 pkgs.lilya
scripts/ + scripts/tests/    独立脚本与回归测试
checks/                      flake checks
assets/ patches/ secrets/    静态资源、上游补丁、age 密文
docs/                        仓库之外的手工状态（如音乐服务器）的记录与重建步骤
```

导入都是显式列出的；没有 `lib/`，没有目录扫描。

## 亮点

- **两层外观模型**：Nix 只写默认层，GUI 改动留在 Noctalia 的覆盖层，rebuild 不会改回去；调色板经 Noctalia 模板同步到 GTK、Qt、Niri、kitty。
- **秘密用 agenix**：订阅链接与自建节点、控制 API secret、LAN 认证、GitHub token 全在 `secrets/*.age`。
- **Mihomo TUN**：规则以 `GEOSITE` 类别为主，控制 API 同源限制，7890 对局域网开放但需认证，主机 IPv6 关闭以堵 WebRTC 泄漏。
- **硬件恢复脚本**：USB-C PD 事件后的 mux 复位、电池省电模式下的 CPU/PCIe 限制，失败自动回滚，`SYSROOT` 可注入测试。
- **外接 Windows 虚拟机**：libvirt 直通 USB 整盘，启动器先确认磁盘未挂载。
- **音乐**：beets 按 Deezer 整理 `~/Music`，本地插件 `zhlyrics` 补中文歌词（网易云 + LRCLib，统一简体）；`music-sync` 镜像到上海服务器上的 Navidrome；`music-discover` 每周用网易云「我喜欢的音乐」做种子，汇总网易云、ListenBrainz、YouTube Music 的相似推荐生成发现页。见 [docs/music-server.md](docs/music-server.md)。
- **checks**：脚本单测与 Mihomo 规则可达性、statix/deadnix/nixfmt、Niri KDL 校验。

## 使用

```bash
rebuild          # nh os switch
testbuild        # nh os test，不写引导项
nix fmt
nix flake check --no-build --no-update-lock-file
nix build .#checks.x86_64-linux.{configuration,lint,niri-config} --no-link
nix-update --flake <name>   # 升级 pkgs/ 里手 pin 的二进制包（见 packages 输出）
```

## 配置所有权

原则：Nix 提供默认层，GUI 拥有覆盖层，激活不碰覆盖层。

| 对象 | 方式 |
|---|---|
| Niri、快捷键、显示器、MIME、字体、GTK/Qt 主题文件 | Nix 持续管理 |
| Noctalia `config.toml` / `settings.toml` | 默认层 / GUI 覆盖层（`~/.local/state/noctalia/`） |
| Plasma 里 plasma-manager 声明的键 | 每次激活重写；其余由 Plasma 保存 |
| Zed `settings.json`、LibreOffice 工具栏 | 首次种子，之后由应用保存 |
| Flatpak 应用、Noctalia 插件 | 运行时安装，不由 flake.lock 固定 |

`config-drift noctalia|zed` 显示 GUI 相对默认层的差量，想固化时抄进对应模块。Noctalia 模板没生效时运行 `noctalia msg templates-apply`。

## 不在 Git 里的状态

`~/.config/age/mihomo.txt`（解密 `secrets/` 的身份，整套秘密的信任根）、`~/.local/state/noctalia/settings.toml`、`~/.config/openlist/`、`~/.config/rclone/rclone.conf`、浏览器 profile、libvirt NVRAM/TPM 与外接 Windows 盘。磁盘未加密是有意的取舍。

`modules/system/backup.nix` 每天用 restic 把其中除浏览器 profile 和 Windows 盘以外的部分，连同 `~/.ssh`、`~/.gnupg`，加密备份到首尔服务器（SFTP，chroot 的 `restic` 账号）和 Google Drive（rclone 远端 `gdrive`，`drive.file` 范围）。restic 密码在 `secrets/` 里，而 `secrets/` 又要靠 age 私钥解密，所以 **age 私钥和 restic 密码必须另存一份在机器之外**，否则备份无法恢复。手动操作用 `sudo restic-seoul …` / `sudo restic-gdrive …`。

## 备注

- Mihomo 配置由前片段 + 密文 + 后片段拼接到 `/run/mihomo/config.yaml`，三者任一变化都会重启代理。改规则后 `mihomo -t` 校验，再跑 `configuration` check（含 `scripts/tests/test_mihomo_*.py`）。
- 订阅节点由密文里的 `glados` proxy-provider 拉取（12 小时一次，经 `Default Proxy`），缓存在 `/var/lib/private/mihomo/proxy_providers/`；策略组按节点名标签（`Dedicated`、`IPv6`、`D1` …）用 `filter` 选取，不写死节点名。换套餐只需更新密文里的 URL。
- Qt 平台主题等变量只在 Niri 的 `environment {}` 里设置，Plasma 使用标准会话。
- 合盖不休眠（s2idle 在这台机器上恢复不可靠）。Home Manager 在用户会话允许之后才激活，冷启动后若主题未齐，注销再进一次。
- 外接 Windows：来宾内先关机再拔盘；宿主运行期间不要挂载该盘；来宾不暴露 VMX。
