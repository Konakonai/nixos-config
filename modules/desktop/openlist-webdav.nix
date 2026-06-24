{ pkgs, ... }:

let
  refreshOpenList = pkgs.writeShellScriptBin "refresh-openlist" ''
    set -euo pipefail

    openlist="${pkgs.openlist}/bin/OpenList"
    curl="${pkgs.curl}/bin/curl"
    jq="${pkgs.jq}/bin/jq"
    sed="${pkgs.gnused}/bin/sed"
    tail="${pkgs.coreutils}/bin/tail"
    systemctl="${pkgs.systemd}/bin/systemctl"

    path="''${1:-/quark}"
    data_dir="$HOME/.config/openlist"

    token="$("$openlist" admin token --data "$data_dir" 2>/dev/null | "$sed" -n 's/^Admin token: //p' | "$tail" -n 1)"
    if [ -z "$token" ]; then
      echo "Could not read the OpenList admin token from $data_dir." >&2
      exit 1
    fi

    payload="$("$jq" -cn --arg path "$path" '{path: $path, password: "", page: 1, per_page: 0, refresh: true}')"
    response="$("$curl" -fsS --connect-timeout 5 -X POST \
      -H "Authorization: $token" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      http://127.0.0.1:5244/api/fs/list)"

    count="$(printf '%s' "$response" | "$jq" -r '
      if .code == 200 then
        (.data.content // [] | length)
      else
        error(.message // "OpenList refresh failed")
      end
    ')"

    "$systemctl" --user restart openlist-webdav.service
    echo "OpenList $path refreshed, and the WebDAV mount was restarted. Current item count: $count"
  '';
in
{
  home.packages = [ refreshOpenList ];

  systemd.user.services.openlist-webdav = {
    Unit = {
      Description = "Mount OpenList WebDAV with rclone";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
    };

    Service = {
      Type = "notify";
      Environment = [
        "PATH=/run/wrappers/bin:${pkgs.fuse3}/bin:${pkgs.coreutils}/bin"
      ];
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Mounts/OpenList %h/.cache/rclone/openlist";
      ExecStart = "${pkgs.rclone}/bin/rclone mount openlist: %h/Mounts/OpenList --config %h/.config/rclone/rclone.conf --cache-dir %h/.cache/rclone/openlist --vfs-cache-mode full --vfs-cache-max-size 8G --vfs-cache-max-age 24h --vfs-cache-poll-interval 1m --dir-cache-time 30s --poll-interval 0 --umask 022 --log-level INFO";
      ExecStop = "-/run/wrappers/bin/fusermount3 -u %h/Mounts/OpenList";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
