{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  dbFile = lib.escapeShellArg "${hostProfile.services.openlistDataDir}/data.db";

  refreshOpenList = pkgs.writeShellScriptBin "refresh-openlist" ''
    set -euo pipefail

    openlist="${pkgs.openlist}/bin/OpenList"
    curl="${pkgs.curl}/bin/curl"
    jq="${pkgs.jq}/bin/jq"
    sed="${pkgs.gnused}/bin/sed"
    tail="${pkgs.coreutils}/bin/tail"
    systemctl="${pkgs.systemd}/bin/systemctl"

    path="''${1:-/quark}"
    data_dir=${lib.escapeShellArg hostProfile.services.openlistDataDir}

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
  environment.systemPackages = with pkgs; [
    openlist
    rclone
  ];

  # OpenList server (cloud storage -> WebDAV).
  systemd.services.openlist = {
    description = "OpenList Service";
    after = [ "mihomo.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      # Cloud storages are initialised once at startup and stay broken if DNS
      # isn't up yet (mihomo being started doesn't mean it resolves), which
      # makes every WebDAV listing return 500. Wait up to 60 s, then start
      # anyway so an offline boot isn't held up.
      ExecStartPre = [
        (pkgs.writeShellScript "openlist-wait-dns" ''
          for _ in $(${pkgs.coreutils}/bin/seq 60); do
            ${pkgs.getent}/bin/getent hosts drive.quark.cn >/dev/null && exit 0
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "DNS still not ready after 60 s, starting OpenList anyway" >&2
        '')
        # OpenList asks for WAL with mattn's `_journal=WAL`, which the
        # glebarez driver it's built with ignores, so the DB stayed in
        # rollback-journal mode. A driver token refresh then hit SQLITE_BUSY
        # against WebDAV reads and leaked its transaction, and every request
        # failed until restart (10-30, 11-03, 11-04). journal_mode=WAL is
        # stored in the file; re-applying it each start covers a restored DB.
        (pkgs.writeShellScript "openlist-db-wal" ''
          [ -f ${dbFile} ] || exit 0
          ${pkgs.sqlite}/bin/sqlite3 ${dbFile} 'PRAGMA journal_mode=WAL;' >/dev/null
        '')
      ];
      ExecStart = "${pkgs.openlist}/bin/OpenList server --data ${hostProfile.services.openlistDataDir}";
      Restart = "always";
      User = hostProfile.user.userName;
      Group = hostProfile.user.group;

      # OpenList listens on the LAN and runs as the login user, who has
      # passwordless sudo, so a compromised web process would be one `sudo`
      # away from root and could read every key under $HOME. All it needs is
      # its data directory (config, database, temp and log live there; the
      # storages are cloud drives). ProtectHome also hides /run/user, whose
      # user bus would let it start a process outside this sandbox.
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      ProtectHome = "tmpfs";
      BindPaths = [ hostProfile.services.openlistDataDir ];
      PrivateTmp = true;
    };
  };

  # Jellyfin media server reading ~/Mounts/OpenList.
  # Libraries point at the rclone mount of OpenList (~/Mounts/OpenList), a
  # FUSE mount owned by the user without allow_other, so Jellyfin has to run
  # as that user to see it. The port is opened for the phone in
  # networking.nix, on the Wi-Fi interface only.
  #
  # Scanning over the mount pulls real data from Quark, so real-time
  # monitoring, chapter images and trickplay are turned off in the dashboard
  # (runtime state in /var/lib/jellyfin, see README).
  services.jellyfin = {
    enable = true;
    user = hostProfile.user.userName;
    inherit (hostProfile.user) group;
    openFirewall = false;
  };

  # The module already forbids privilege escalation. Jellyfin listens on the
  # Wi-Fi and the tailnet as the login user, so also keep it away from the
  # rest of that account: home is read-only (it only reads the library mount
  # there), /run/user is hidden because the user bus would let it start a
  # process outside this sandbox, and the credential stores are hidden. The
  # last part is a denylist; anything else under $HOME stays readable.
  systemd.services.jellyfin.serviceConfig = {
    ProtectHome = "read-only";
    InaccessiblePaths = [
      "-/run/user"
    ]
    ++ map (path: "-${hostProfile.user.homeDirectory}/${path}") [
      ".ssh"
      ".gnupg"
      ".config/age"
      ".config/rclone"
      ".config/openlist"
    ];
  };

  # User-side rclone FUSE mounts (OpenList WebDAV + Google Drive).
  home-manager.users.${hostProfile.user.userName} = {
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
        # A plain unmount fails with EBUSY while anything (Jellyfin, a player)
        # holds a file open, leaving a dead mount that makes ExecStartPre's mkdir
        # fail with "Transport endpoint is not connected". Detach lazily instead.
        ExecStop = "-/run/wrappers/bin/fusermount3 -uz %h/Mounts/OpenList";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install.WantedBy = [ "default.target" ];
    };

    # Full-scope remote for browsing the whole Drive. Backups use the separate
    # drive.file remote `gdrive` (modules/core/backup.nix) and never see this one.
    systemd.user.services.gdrive-mount = {
      Unit = {
        Description = "Mount Google Drive with rclone";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        ConditionPathExists = "%h/.config/rclone/rclone.conf";
      };

      Service = {
        Type = "notify";
        Environment = [
          "PATH=/run/wrappers/bin:${pkgs.fuse3}/bin:${pkgs.coreutils}/bin"
        ];
        # The mount point is a dot directory because GLib lists every user mount
        # under $HOME as a volume, and gvfs-udisks2-volume-monitor reads its root
        # while starting. Nemo waits up to 25 s for that monitor on launch, so a
        # Drive request stuck on a bad proxy node used to stall every file manager
        # window. Hidden paths are skipped; x-gvfs-hide does not work because
        # fusermount3 drops x-* options before they reach the mount table.
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Mounts/.GoogleDrive %h/.cache/rclone/gdrive";
        # Drive pushes change notifications (--poll-interval), so directory
        # listings can be cached for a long time without going stale.
        # The restic repository is hidden so a file manager cannot delete backups.
        ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive-mount: %h/Mounts/.GoogleDrive --config %h/.config/rclone/rclone.conf --cache-dir %h/.cache/rclone/gdrive --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --dir-cache-time 1000h --poll-interval 1m --exclude /restic/** --umask 022 --log-level INFO";
        ExecStop = "-/run/wrappers/bin/fusermount3 -u %h/Mounts/.GoogleDrive";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
