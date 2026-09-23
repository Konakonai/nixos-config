{ pkgs, ... }:

{
  # Full-scope remote for browsing the whole Drive. Backups use the separate
  # drive.file remote `gdrive` (modules/system/backup.nix) and never see this one.
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
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Mounts/GoogleDrive %h/.cache/rclone/gdrive";
      # Drive pushes change notifications (--poll-interval), so directory
      # listings can be cached for a long time without going stale.
      # The restic repository is hidden so a file manager cannot delete backups.
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive-mount: %h/Mounts/GoogleDrive --config %h/.config/rclone/rclone.conf --cache-dir %h/.cache/rclone/gdrive --vfs-cache-mode full --vfs-cache-max-size 10G --vfs-cache-max-age 24h --dir-cache-time 1000h --poll-interval 1m --exclude /restic/** --umask 022 --log-level INFO";
      ExecStop = "-/run/wrappers/bin/fusermount3 -u %h/Mounts/GoogleDrive";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
