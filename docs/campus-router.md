# 宿舍路由器（OpenWrt）

宿舍的小米 AX3000T（RD03）刷了 OpenWrt 25.12，负责校园网上联和宿舍 LAN。它不归本仓库声明式管理，本文件记录手工改过的状态，重刷固件后照做即可。

| 项 | 值 |
|---|---|
| 访问 | LAN `192.168.1.1`，`ssh root@192.168.1.1`（本机 `~/.ssh/id_ed25519`） |
| 资源 | 256M 内存、128M NAND（overlay 约 57M 可用），无 USB |
| WAN | DHCP，保留原厂 MAC `a4:a9:30:28:66:b2`（认证绑定 MAC，换 MAC 要重新登录） |
| 认证 | Dr.COM ePortal `10.2.5.251`，由下文脚本自动登录 |

## 校园网自动登录

路由器拿到 WAN 地址后调用 portal 的 JSONP 登录接口，之后每分钟检查一次，掉线就重新登录。

| 文件 | 作用 |
|---|---|
| `/etc/campus-login.conf` | 账号、运营商后缀、密码（`600`，只在路由器上，不进 Git） |
| `/usr/bin/campus-login` | 登录脚本（内容见下） |
| `/etc/hotplug.d/iface/99-campus-login` | `wan` ifup 后 3 秒登录一次 |
| `/etc/crontabs/root` | `* * * * * /usr/bin/campus-login` |

另外：`system.@system[0].cronloglevel=9`，免得 cron 每分钟写一行日志；上面三个文件已加进 `/etc/sysupgrade.conf`，attended sysupgrade 升级时会保留。

- 查看日志：`logread -e campus-login`。只记录登录成功、失败（带 portal 返回的 `msg`）和配置错误，在线时不写日志。
- 强制登录：`campus-login --force`（跳过在线检查）。
- 改密码：编辑 `/etc/campus-login.conf` 的 `CAMPUS_PASS`。运营商后缀 `CAMPUS_ISP` 取 `@telecom` / `@cmcc` / `@unicom`，选「校园网」时留空。

接口是从 portal 页面的 JS 里读出来的（`a41.js` 设 `accountPrefix=0`、`jsVersion='3.0'`；`extern/123/config.js` 里 `10.3–10.4` 段走「学生_new」模板，`login_method=1`；该模板的 `pc.js` 给出运营商后缀）。portal 改版、登录失败时，先对照这几个文件。判断是否在线的依据：已认证时 `http://10.2.5.251/` 返回的是注销页（`Dr.COMWebLoginID_1.htm`）。

```sh
#!/bin/sh
# Dr.COM ePortal auto-login for the CUMT campus network.
# Credentials live in /etc/campus-login.conf (CAMPUS_USER, CAMPUS_ISP, CAMPUS_PASS).
# Usage: campus-login [--force]   (--force skips the online check)

PORTAL=10.2.5.251
CONF=/etc/campus-login.conf
TAG=campus-login

exec 9>/var/lock/campus-login.lock
flock -n 9 || exit 0

[ -r "$CONF" ] || { logger -t $TAG "missing $CONF"; exit 1; }
. "$CONF"
[ -n "$CAMPUS_USER" ] && [ -n "$CAMPUS_PASS" ] || { logger -t $TAG "CAMPUS_USER/CAMPUS_PASS not set"; exit 1; }

# The portal root serves the logout page (Dr.COMWebLoginID_1) while this IP is
# authenticated, and the login page otherwise.
if [ "$1" != "--force" ]; then
	page=$(wget -q -T 5 -O- "http://$PORTAL/" 2>/dev/null) || { logger -t $TAG "portal unreachable"; exit 1; }
	case "$page" in *Dr.COMWebLoginID_1.htm*) exit 0 ;; esac
fi

urlencode() {
	s=$1 out=
	while [ -n "$s" ]; do
		c=${s%"${s#?}"}
		s=${s#?}
		case "$c" in
			[a-zA-Z0-9.~_-]) out="$out$c" ;;
			*) out="$out$(printf '%%%02X' "'$c")" ;;
		esac
	done
	printf '%s' "$out"
}

. /usr/share/libubox/jshn.sh
json_load "$(ubus call network.interface.wan status)"
json_select ipv4-address && json_select 1 && json_get_var ip address
[ -n "$ip" ] || { logger -t $TAG "wan has no IPv4 address"; exit 1; }

# Mirrors login_portal() in the portal's a42.js: login_method=1, no account
# prefix, ISP suffix (@telecom/@cmcc/@unicom, empty for 校园网) appended.
resp=$(wget -q -T 10 -O- "http://$PORTAL:801/eportal/?c=Portal&a=login&callback=dr1003&login_method=1\
&user_account=$(urlencode "$CAMPUS_USER$CAMPUS_ISP")&user_password=$(urlencode "$CAMPUS_PASS")\
&wlan_user_ip=$ip&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.0")

case "$resp" in
	*'"result":"1"'* | *'"result":1'*) logger -t $TAG "logged in as $CAMPUS_USER$CAMPUS_ISP ($ip)" ;;
	# ret_code 2: this IP is already authenticated (seen with --force while online).
	*'"ret_code":"2"'* | *'"ret_code":2'*) logger -t $TAG "already online ($ip)" ;;
	*) logger -t $TAG "login failed: $resp"; exit 1 ;;
esac
```

## IPv6

校园网的 IPv6 走不通：DHCPv6 会给出 `2001:da8:100d:23::/128`，但 portal 只认证 v4（`m46=0`，会话 `v6ip='::'`），v6 流量过了校园网关就丢。路由器上已经预先配好 NAT6（`wan` 开 `masq6`，`wan6` 设 `sourcefilter=0`，LAN 用 ULA + SLAAC），等哪天校园 v6 能用了，`uci set dhcp.lan.ra_default=2` 就能启用。排查前先关掉代理测直连 v6，再看 portal 状态页的 `v6ip`。
