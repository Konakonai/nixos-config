# 东京应急备用节点（Azure `lab-jp`）

当主力机场（GLaDOS）全部节点不可用时的独立救命节点，平时零流量，不与首尔备份机共用。它不归本仓库声明式管理，本文件记录手工状态与运维命令（密钥与 UUID 仅存于服务器 `/etc/xray/config.json`、本机 `secrets/mihomo-proxies.yaml.age` 以及手机 Box 配置，不进 Git）。

| 项 | 值 |
|---|---|
| 主机 | Azure `japaneast`（`Standard_B2pts_v2`，2 vCPU ARM64 / 1G RAM + 2G Swap / Debian 13） |
| 访问 | `ssh lilya@20.222.1.138`（本机 `~/.ssh/id_ed25519`，免密 `sudo`） |
| 协议 | Xray-core `v26.6.27`（`/usr/local/bin/xray`）VLESS + XTLS-Vision + REALITY，TCP `443`（固定在 `v26.7.11` 之前，因后续版本默认强化 REALITY `minClientVer`，会拒绝 mihomo 的内置客户端版本号） |
| 伪装目标 | `www.sony.jp:443`（TLS 1.3 + H2 + X25519，无需自备域名和续期证书） |
| 拥塞控制 | BBR（`/etc/sysctl.d/99-bbr.conf`） |
| 防滥用 | Xray 路由屏蔽 `geoip:private`（含 Azure IMDS `169.254.169.254`） |

## 常用运维

```bash
# 查看状态与日志
ssh lilya@20.222.1.138 'sudo systemctl status xray --no-pager'
ssh lilya@20.222.1.138 'sudo journalctl -u xray -n 50 --no-pager'

# 校验配置并重启
ssh lilya@20.222.1.138 'sudo -u xray /usr/local/bin/xray run -test -config /etc/xray/config.json && sudo systemctl restart xray'
```

## 节点接入位置

- **电脑（NixOS）**：`secrets/mihomo-proxies.yaml.age` 中静态节点 `JP-Azure`；`Auto`（`Auto-GLaDOS` → `JP-Azure`）与 `Subscription`（`Default Proxy` → `JP-Azure` → `DIRECT` → `IN-NexIP-Sticky`）均在主力机场全挂时自动回退到它，`Default Proxy` / `Google` / `Research + AI` / `Developer` 也可手动切换。
- **手机（Box for Root）**：`/data/adb/box/mihomo/config.yaml` 中静态节点 `JP-Azure`，同时加了 `IP-CIDR,20.222.1.138/32,DIRECT,no-resolve` 避免电脑连手机热点使用 `JP-Azure` 时双重代理。
