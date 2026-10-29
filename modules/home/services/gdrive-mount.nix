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
}
