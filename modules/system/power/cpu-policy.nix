{ pkgs, ... }:

let
  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);
  command = "${python}/bin/python3 ${../../../scripts/power-saver-cpu.py}";
in
{
  systemd.services.power-saver-cpu = {
    description = "Apply turbo and PCIe policy on battery in power-saver mode";
    # power-profiles-daemon orders itself after multi-user.target, so being
    # wanted by (and thus before) multi-user.target formed a cycle and systemd
    # dropped this unit at boot. Follow ppd onto graphical.target instead.
    wantedBy = [ "graphical.target" ];
    wants = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
    after = [
      "upower.service"
      "power-profiles-daemon.service"
    ];
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
