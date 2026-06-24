{ pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;

  powerManagement.powertop.enable = true;

  systemd.services.powertop.serviceConfig.ExecStartPost = pkgs.writeShellScript "disable-usb-autosuspend" ''
    for dev in /sys/bus/usb/devices/*; do
      if [ -d "$dev" ]; then
        if grep -q "03" "$dev"/*/bInterfaceClass 2>/dev/null; then
          echo "on" > "$dev/power/control" 2>/dev/null || true
        fi
      fi
    done
  '';
}
