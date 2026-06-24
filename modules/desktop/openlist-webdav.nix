{ pkgs, ... }:

{
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
      ExecStart = "${pkgs.rclone}/bin/rclone mount openlist: %h/Mounts/OpenList --config %h/.config/rclone/rclone.conf --cache-dir %h/.cache/rclone/openlist --vfs-cache-mode full --vfs-cache-max-size 8G --vfs-cache-max-age 24h --vfs-cache-poll-interval 1m --dir-cache-time 5m --poll-interval 0 --umask 022 --log-level INFO";
      ExecStop = "-/run/wrappers/bin/fusermount3 -u %h/Mounts/OpenList";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
