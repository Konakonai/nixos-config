{ pkgs, ... }:

let
  touhouPlymouthTheme = pkgs.lilya.touhou-plymouth-theme;
in
{
  boot = {
    consoleLogLevel = 0;

    plymouth = {
      enable = true;
      theme = "touhou_logo";
      themePackages = [ touhouPlymouthTheme ];
    };

    kernelParams = [
      "quiet"
      "udev.log_level=3"
      "rd.systemd.show_status=false"
      "systemd.show_status=false"
      # NVIDIA loads in stage 2. Draw the splash on the firmware framebuffer
      # immediately instead of preserving GRUB's last frame for eight seconds.
      "plymouth.use-simpledrm"
      # Keep fbcon on fallback VTs so tty1 remains clean for Plymouth and SDDM.
      "fbcon=vc:2-6"
      "vt.global_cursor_default=0"
    ];
  };
}
