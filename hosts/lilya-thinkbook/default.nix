let
  userName = "lilya";
  homeDirectory = "/home/${userName}";
in
{
  name = "lilya-thinkbook";
  hardwareConfiguration = ../../hardware-configuration.nix;

  user = {
    inherit userName homeDirectory;
    group = "users";
    nixosConfigPath = "${homeDirectory}/nixos-config";
  };

  boot = {
    # Default boot path targets the external display. Use the
    # internal-display-fallback specialisation when no monitor is attached.
    disableInternalDisplayParam = "video=eDP-1:d";
    # Test profile: prefer the external panel during kernel/Plymouth takeover
    # without disabling the internal panel. If this fixes Plymouth sizing, it can
    # replace disableInternalDisplayParam as the default.
    externalDisplayPreferredParam = "video=DP-2:3840x2160@60D";
  };

  display = {
    loginWallpaper = ../../assets/sddm-wallpaper.jpg;

    internal = {
      connector = "eDP-1";
      scale = 1.75;
      position = { x = 2560; y = 149; };
      loginPosition = { x = 0; y = 0; };
    };

    external = {
      connector = "DP-2";
      make = "Philips Consumer Electronics Company";
      model = "PHL 27E2F7901";
      serial = "UHB2341003696";
      niriName = "Philips Consumer Electronics Company PHL 27E2F7901 UHB2341003696";
      scale = 1.5;
      position = { x = 0; y = 0; };
      loginPosition = { x = 0; y = 0; };
    };
  };

  graphics.nvidia = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    pciAddress = "0000:01:00.0";
    acAdapter = "ADP0";
    intelRenderNode = "/dev/dri/by-path/pci-0000:00:02.0-render";
    nvidiaRenderNode = "/dev/dri/by-path/pci-0000:01:00.0-render";
  };

  power = {
    batteryConservationPath = "/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode";
    keepAwakeUsbDevices = [
      { vendor = "1532"; product = "0099"; }
      { vendor = "320f"; product = "5088"; }
      { vendor = "2109"; product = "2822"; }
    ];
  };

  services = {
    openlistDataDir = "${homeDirectory}/.config/openlist";
    mihomo = {
      configDir = "${homeDirectory}/.config/mihomo";
      identityFile = "${homeDirectory}/.config/age/mihomo.txt";
    };
  };

  zen.profilePath = "i41yvfec.Default Profile";
}
