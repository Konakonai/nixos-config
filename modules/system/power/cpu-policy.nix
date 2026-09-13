{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);
  command = "${python}/bin/python3 ${../../../scripts/power-saver-cpu.py}";
in
{
  systemd.services.power-saver-cpu = {
    description = "Apply the Intel CPU policy on battery in power-saver mode";
    wantedBy = [ "multi-user.target" ];
    wants = [ "upower.service" "power-profiles-daemon.service" ];
    after = [ "upower.service" "power-profiles-daemon.service" ];
    unitConfig.ConditionPathExists = "/sys/devices/system/cpu/intel_pstate/no_turbo";
    serviceConfig = {
      ExecStart = command;
      ExecStopPost = "${command} --restore";
      Restart = "on-failure";
      RestartSec = "5s";
      RuntimeDirectory = "power-saver-cpu";
      RuntimeDirectoryMode = "0700";
      UMask = "0077";
    };
  };
}
