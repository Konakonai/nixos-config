# 音乐服务器（上海）

本机 beets 整理 `~/Music`，`music-sync` 镜像到上海阿里云 ECS，Navidrome 在那里提供 Subsonic 服务给手机。服务器不归本仓库声明式管理，本文件记录它的全部手工状态，重建时照做即可。

| 项 | 值 |
|---|---|
| 主机 | 阿里云轻量应用服务器 `106.14.0.229`，Ubuntu 24.04，2C / 1.6G，40G 系统盘 + 40G 数据盘（与实例绑定、同到期、须一起续费）。SSH 别名 `shanghai`（`root`，本机 ed25519；阿里云密钥对 `~/.ssh/shanghai.pem` 备用） |
| 入口 | `https://106.14.0.229:8443`（nginx TLS → `127.0.0.1:4533`），账号 `lilya`，密码在 Bitwarden；`/discover/` 是每周的音乐发现页（静态，不设密码） |
| 曲库 | `/srv/music`：mergerfs 合并系统盘的 `/srv/music-sys` 与数据盘的 `/mnt/data/music`（root 所有，navidrome 只读） |
| 数据 | `/var/lib/navidrome`（SQLite、缓存） |
| 同机其他服务 | `trial-run` 容器占 80 端口（nginx 默认站点），与本服务无关，只借用它的 `/.well-known/acme-challenge/`；Tailscale 节点 `shanghai-relay`（`100.82.32.65`）兼 peer relay，见下文 |
| 安全组 | 放行 22、80、443、8443，以及 UDP 40000（Tailscale peer relay） |

## 日常

```bash
beet-deezer ~/Downloads/<专辑目录>   # 导入（Deezer UPC 定位）
music-sync -n                        # 预览要同步的改动
music-sync                           # 同步并全量重扫
```

`music-sync` 用 `rsync --delete` 镜像，本地删除的文件服务器也会删；本地库为空时拒绝执行。Navidrome 的文件监视器跟不上 rsync 的临时文件改名，增量扫描又只看目录 mtime（只改标签不会变），所以有改动就跑 `scan --full`。

- 发现页：本机 systemd 用户定时器每周一跑 `music-discover`（`modules/home/music-discover.nix`，脚本在 `scripts/music-discover.py`），生成后 rsync 到 `/var/www/discover/`。手动跑：`music-discover`；状态和缓存在 `~/.local/state/music-discover/`（`artists.json` 是 MusicBrainz 风格标签缓存，删掉会重新查；新收藏很多时可以 `--tag-budget 3000` 一次查完）。
- 网易云登录：发现页用 `secrets/netease-cookie.age` 里的 `MUSIC_U` cookie 调「相似艺人」、读关注列表和粉丝数。页面「同圈子」说明里出现「登录 cookie 已失效」时，浏览器重新登录 music.163.com，复制新的 `MUSIC_U`，然后 `nix shell nixpkgs#age -c bash -c 'read -rsp "MUSIC_U: " c; echo; printf %s "$c" | age -r "$(age-keygen -y ~/.config/age/mihomo.txt)" -o ~/nixos-config/secrets/netease-cookie.age && echo "saved (${#c} chars)"'` 并 rebuild。
- 忘记密码：`ssh -t shanghai 'runuser -u navidrome -- /opt/navidrome/navidrome user edit -u lilya --set-password -c /etc/navidrome/navidrome.toml'`
- 升级：按下文「安装」换版本号重新下载校验，`systemctl restart navidrome`。数据库迁移由 Navidrome 启动时完成，升级前可 `navidrome backup create`。
- 证书：`/root/.acme.sh/acme.sh --list` 查看；root 的 crontab 每天 4 次检查，3 天续期一次，续期后自动 `systemctl reload nginx`。

## 重建步骤

以下都在服务器上以 root 执行。

### 安装

Docker Hub 在这台机器上不通，GitHub 可达，所以用官方二进制而不是容器。

```bash
apt-get install -y ffmpeg sqlite3 mergerfs
useradd --system --home-dir /var/lib/navidrome --shell /usr/sbin/nologin navidrome
install -d -o navidrome -g navidrome -m 750 /var/lib/navidrome
install -d -o root -g navidrome -m 755 /srv/music /srv/music-sys
install -d -m 755 /opt/navidrome /etc/navidrome

V=0.64.2; F=navidrome_${V}_linux_amd64.tar.gz; cd /tmp
curl -fsSLO https://github.com/navidrome/navidrome/releases/download/v$V/$F
curl -fsSLO https://github.com/navidrome/navidrome/releases/download/v$V/navidrome_checksums.txt
grep " $F\$" navidrome_checksums.txt | sha256sum -c - && tar -xzf $F -C /opt/navidrome navidrome
```

### 存储

数据盘 `/dev/vdb` 整盘 ext4（`mkfs.ext4 -L music-data -m 0`，不给 root 预留），再用 mergerfs 把它和系统盘剩余空间合成一个曲库。新文件写到剩余空间多的分支（`mfs`）；系统盘分支保留 10G 给系统、日志和 `trial-run`，数据盘只留 1G。可用约 56G。

`/etc/fstab` 追加（UUID 以 `blkid /dev/vdb` 为准）：

```text
# Aliyun data disk (40G) for the music library; see docs/music-server.md.
UUID=be655c96-fdd1-4255-b9cb-4e7f6ca87359 /mnt/data ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
# Music pool: leftover system-disk space + the data disk. New files go to the branch with
# the most free space; the system disk keeps 10G for the OS, logs and the trial-run container.
/srv/music-sys=RW,10G:/mnt/data/music=RW,1G /srv/music fuse.mergerfs allow_other,cache.files=off,category.create=mfs,fsname=music-pool,nofail,x-systemd.requires-mounts-for=/mnt/data 0 0
```

```bash
systemctl daemon-reload && mount /mnt/data
install -d -o root -g navidrome -m 755 /mnt/data/music
mount /srv/music
```

`allow_other` 必须有，否则 navidrome 用户看不到 root 挂的 FUSE。核对生效的分支：`python3 -c 'import os; print(os.getxattr("/srv/music/.mergerfs", "user.mergerfs.branches"))'`。某首歌在哪块盘上，直接在两个分支目录里找。

### `/etc/navidrome/navidrome.toml`

```toml
# Managed by hand; see docs/music-server.md in the laptop's nixos-config.
MusicFolder = "/srv/music"
DataFolder = "/var/lib/navidrome"
# Only nginx (TLS on :8443) talks to Navidrome.
Address = "127.0.0.1"
Port = 4533
DefaultLanguage = "zh-Hans"
EnableInsightsCollector = false
# music-sync runs a full scan after each upload; this schedule is a backstop.
Scanner.Schedule = "@every 6h"
```

### `/etc/systemd/system/navidrome.service`

```ini
[Unit]
Description=Navidrome music server
After=network-online.target
Wants=network-online.target
# The library is a mergerfs pool over the system and data disks.
RequiresMountsFor=/srv/music

[Service]
User=navidrome
Group=navidrome
Type=simple
ExecStart=/opt/navidrome/navidrome --configfile /etc/navidrome/navidrome.toml
WorkingDirectory=/var/lib/navidrome
TimeoutStopSec=20
KillMode=process
Restart=on-failure

# Hardening: read-only view of the system and the library.
ProtectSystem=strict
ReadWritePaths=/var/lib/navidrome
ReadOnlyPaths=/srv/music
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
NoNewPrivileges=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictRealtime=true
LockPersonality=true
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
MemoryMax=600M

[Install]
WantedBy=multi-user.target
```

`systemctl daemon-reload && systemctl enable --now navidrome`

### 先建管理员，再开放端口

Navidrome 在没有用户时，**第一个打开网页的人成为管理员**，而 8443 在安全组里是开着的。所以在第一次 reload 带 8443 的 nginx 之前先建好账号：本机 `ssh -N -L 4533:127.0.0.1:4533 shanghai`，浏览器开 `http://localhost:4533` 创建 `lilya`；或者先在下面的 `server` 块里临时加 `deny all;`。

### 证书

没有域名（也没备案），用 Let's Encrypt 的 IP 证书，只有 `shortlived` profile（约 6 天有效）。HTTP-01 验证借用 80 端口的 `trial-run` 站点，在 `/etc/nginx/sites-available/trial-run` 的 `location / {` 前加：

```nginx
    # Let's Encrypt HTTP-01 for the Navidrome IP certificate (acme.sh).
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/acme;
    }
```

```bash
install -d -m 755 /var/www/acme && nginx -t && systemctl reload nginx
git clone --depth 1 https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh
(cd /tmp/acme.sh && ./acme.sh --install --home /root/.acme.sh)
A="/root/.acme.sh/acme.sh --home /root/.acme.sh"
$A --register-account --server letsencrypt
$A --issue --server letsencrypt -d 106.14.0.229 --cert-profile shortlived --days 3 --webroot /var/www/acme
install -d -m 700 /etc/nginx/ssl/navidrome
$A --install-cert -d 106.14.0.229 --ecc \
  --key-file /etc/nginx/ssl/navidrome/key.pem \
  --fullchain-file /etc/nginx/ssl/navidrome/fullchain.pem \
  --reloadcmd "systemctl reload nginx"
```

必须显式 `--home /root/.acme.sh` 且 `HOME=/root`：在 `systemd-run` 等没有 `HOME` 的环境里 acme.sh 会装进 `/.acme.sh`，cron 找不到它，证书 6 天后过期。

### `/etc/nginx/sites-available/navidrome`

Ubuntu 24.04 的 nginx 是 1.24，不认识 `http2 on;`，要写在 `listen` 上。

```nginx
# Navidrome over TLS with a Let's Encrypt IP certificate (acme.sh, renewed
# every 3 days by root's crontab; see /root/.acme.sh).
server {
    listen 8443 ssl http2;
    listen [::]:8443 ssl http2;
    server_name 106.14.0.229;

    ssl_certificate     /etc/nginx/ssl/navidrome/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/navidrome/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:navidrome:10m;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Weekly music-discover page, uploaded from the laptop (see docs/music-server.md).
    location = /discover {
        return 301 /discover/;
    }
    location /discover/ {
        alias /var/www/discover/;
        index index.html;
        charset utf-8;
    }

    location / {
        proxy_pass http://127.0.0.1:4533;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        # Long FLAC streams and seeking.
        proxy_buffering off;
        proxy_read_timeout 1h;
    }
}
```

```bash
install -d -m 755 /var/www/discover
ln -sf /etc/nginx/sites-available/navidrome /etc/nginx/sites-enabled/navidrome
nginx -t && systemctl reload nginx
```

然后在本机 `music-sync`。

## Tailscale peer relay

校园网和手机的移动数据都是对称 NAT，Tailscale 打不了洞，原来只能绕旧金山/西雅图的 DERP（400–600ms）。这台机器有公网 IP，开 peer relay 后电脑↔手机经上海中转，约 60–130ms（NectarLink 在外面用的就是这条路）。中继只在直连失败时使用，流量计入轻量服务器的月流量包。

重建：

```sh
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list
apt-get update && apt-get install -y tailscale
tailscale up --hostname=shanghai-relay --accept-dns=false --accept-routes=false   # 打开输出的链接登录
# 实例在 1:1 NAT 后（eth0 是 172.24.23.226），自己发现不了公网地址，要显式公布
tailscale set --relay-server-port=40000 --relay-server-static-endpoints="106.14.0.229:40000"
```

还要：

- 阿里云控制台 → 防火墙放行 UDP 40000（本机 ufw 未启用）。
- Tailscale 管理后台 Access controls 的 `grants` 里有一条（电脑、手机 → 本机，只授予中继能力）：
  `{"src": ["100.83.187.102", "100.121.227.28"], "dst": ["100.82.32.65"], "app": {"tailscale.com/cap/relay": []}}`
  重建后本机 Tailscale IP 会变，记得改 `dst`。

验证：本机 `tailscale ping 100.121.227.28`（手机在移动数据下）应显示 `via peer-relay(106.14.0.229:40000:…)`。

手机（Xiaomi 12S Pro，KernelSU，tailscale-root 模块）一侧要两处改动，否则它的 UDP 根本出不去、永远走 DERP：

- `/data/adb/service.d/tailscale_bypass_route.sh`：开机加 `ip rule add pref 5240 fwmark 0x80000/0xff0000 goto 29998`（v4/v6）。tailscaled 自发的 UDP 带 0x80000 标记、按 Linux 惯例查 `main` 表，Android 的 `main` 没有默认路由，于是全部 `network is unreachable`（netcheck `UDP: false`）；跳到 netd 维护的默认网络规则（29998）后跟随当前上行。
- Box for Root 的 `tun.route-exclude-address` 加了 `106.14.0.229/32`（备份 `config.yaml.bak.20261122-before-relay-exclude`）。有了上面的规则后已非必需，留作保险。
- 手机 adb 固定在 TCP 5555（`persist.adb.tcp.port`），可从电脑经 Tailscale `adb connect 100.121.227.28:5555`。

## 容量

曲库可用约 56G（系统盘分支约 17G + 数据盘约 39G），CD 规格 FLAC 每首 25–30MB，约 2000 首。`df -h /srv/music` 看的是两块盘的原始合计，不扣保留空间。满了就在控制台给数据盘扩容（`resize2fs /dev/vdb`，mergerfs 自动看到），别在服务器上存有损副本。
