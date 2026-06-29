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
    # Prefer the external panel during kernel/Plymouth takeover without
    # disabling the internal panel. Force the digital connector only; let DRM
    # pick the monitor's EDID preferred mode instead of a CVT user mode that
    # NVIDIA may reject during early boot. Use the internal-display-fallback
    # specialisation when booting away from the dock.
    preferredDisplayParam = "video=DP-2:D";
  };

  display = {
    loginWallpaper = ../../assets/sddm-wallpaper.jpg;

    internal = {
      scale = 1.75;
      # Keep the external display at the global origin for XWayland/Steam games
      # while matching the physical layout: the laptop panel sits on the left.
      position = { x = -1829; y = 149; };
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
      identityFile = "${homeDirectory}/.config/age/mihomo.txt";
    };
  };

  mcp.braveSearch.envFile = "${homeDirectory}/.config/antigravity/brave-search.env";

  zen.profilePath = "i41yvfec.Default Profile";
}
