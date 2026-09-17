{
  hostProfile,
  lib,
  pkgs,
  ...
}:

let
  codexUpdate = pkgs.callPackage ../../pkgs/codex-update.nix {
    configPath = hostProfile.user.nixosConfigPath;
  };
in
{
  home.packages = [
    pkgs.lilya.codex-desktop
    codexUpdate
  ];

  systemd.user.services.codex-update = {
    Unit = {
      Description = "Update Codex Desktop Linux and Codex CLI";
      After = [ "network-online.target" ];
      ConditionACPower = true;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe codexUpdate}";
    };
  };

  systemd.user.timers.codex-update = {
    Unit.Description = "Update Codex Desktop Linux and Codex CLI on a schedule";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "45m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
