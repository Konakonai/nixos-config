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
    timerConfig = {
      OnCalendar = "daily";
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
  systemd.services = {
    restic-backups-seoul.serviceConfig.ProtectHome = "read-only";
    restic-backups-gdrive = {
      path = [ pkgs.rclone ];
      serviceConfig.ProtectHome = "read-only";
    };
  };
}
