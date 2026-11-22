{
  config,
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  home = hostProfile.user.homeDirectory;
  openlistDir = hostProfile.services.openlistDataDir;
  noctaliaDir = "${home}/.local/state/noctalia";

  # The module only runs `unlock` before `forget --prune`, after the backup, so
  # a lock left by an interrupted prune made every later backup fail first and
  # never reach it (both repos stuck 2026-10-20 to 11-04). `unlock` without
  # --remove-all only drops stale locks, so a live run is left alone.
  unlockStale = extraOptions: ''
    ${lib.getExe pkgs.restic}${lib.concatMapStrings (o: " -o ${o}") extraOptions} unlock
  '';

  # Only irreplaceable state that lives outside Git (README「不在 Git 里的状态」
  # plus SSH/GPG keys). Everything else is declared here or disposable.
  common = {
    passwordFile = config.age.secrets.restic-password.path;
    initialize = true;
    paths = [
      (dirOf hostProfile.secrets.identityFile)
      "${home}/.ssh"
      "${home}/.gnupg"
      noctaliaDir
      openlistDir
      "${home}/.config/rclone"
      "/var/lib/libvirt/qemu/nvram"
      "/var/lib/libvirt/swtpm"
    ];
    exclude = [
      "${noctaliaDir}/clipboard"
      "${noctaliaDir}/plugin-cache"
      "${noctaliaDir}/screen_recorder"
      "${openlistDir}/log"
      "${openlistDir}/temp"
    ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    # Campus network is down 23:30-07:00 on weekdays, which the old midnight
    # schedule hit. Evening keeps a few hours of retries before the cutoff.
    timerConfig = {
      OnCalendar = "*-*-* 19:00:00";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
in

{
  age.secrets = {
    restic-password.file = ../../secrets/restic-password.age;
    # The server address stays encrypted so the public repo does not name it.
    restic-seoul-repository.file = ../../secrets/restic-seoul-repository.age;
    restic-seoul-ssh-key.file = ../../secrets/restic-seoul-ssh-key.age;
  };

  # Pinned under an alias because the real host name is only in the secret above.
  programs.ssh.knownHosts.restic-seoul.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoca/CVtUY/eyHO741yi/G/ORbX96WpoT8TV/rpjkdb";

  services.restic.backups = {
    # SFTP-only account chrooted to /srv/restic on the server.
    seoul = common // rec {
      backupPrepareCommand = unlockStale extraOptions;
      repositoryFile = config.age.secrets.restic-seoul-repository.path;
      extraOptions = [
        "sftp.args='-i ${config.age.secrets.restic-seoul-ssh-key.path} -o IdentitiesOnly=yes -o HostKeyAlias=restic-seoul -o BatchMode=yes'"
      ];
    };

    # The gdrive remote is authorised interactively by the user (drive.file scope).
    gdrive = common // {
      backupPrepareCommand = unlockStale [ ];
      repository = "rclone:gdrive:restic/thinkbook";
      rcloneConfigFile = "${home}/.config/rclone/rclone.conf";
    };
  };

  # Backups only read /home. Read-only also stops rclone, running as root, from
  # replacing the user-owned rclone.conf when it refreshes the OAuth token.
  #
  # Both repos go through the mihomo proxy, whose upstream node times out now
  # and then. Retry hourly instead of losing the day: 1 run + 3 retries fits
  # between 19:00 and the 23:30 campus cutoff.
  systemd.services =
    let
      serviceOverrides = {
        unitConfig = {
          StartLimitIntervalSec = "6h";
          StartLimitBurst = 4;
        };
        serviceConfig = {
          ProtectHome = "read-only";
          Restart = "on-failure";
          RestartSec = "1h";
        };
      };
    in
    {
      restic-backups-seoul = serviceOverrides;
      restic-backups-gdrive = serviceOverrides // {
        path = [ pkgs.rclone ];
      };
    };
}
