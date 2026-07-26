let
  userName = "lilya";
  homeDirectory = "/home/${userName}";
  ageIdentityFile = "${homeDirectory}/.config/age/mihomo.txt";
in
{
  name = "lilya-thinkbook";
  hardwareConfiguration = ../../hardware-configuration.nix;

  user = {
    inherit userName homeDirectory;
    group = "users";
    nixosConfigPath = "${homeDirectory}/nixos-config";
  };

  display = {
    loginWallpaper = ../../assets/login-wallpaper.jpg;

    internal = {
      make = "California Institute of Technology";
      model = "0x1626";
      serial = "0x00006002";
      scale = 1.75;
      # Match the physical layout: the laptop panel sits on the left.
      position = { x = -1829; y = 149; };
      loginPosition = { x = 0; y = 0; };
    };

    external = {
      make = "Philips Consumer Electronics Company";
      model = "PHL 27E2F7901";
      serial = "UHB2341003696";
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
  };

  power = {
    batteryConservationPath = "/sys/class/power_supply/BAT0/extensions/ideapad_laptop/conservation_mode";
  };

  services = {
    openlistDataDir = "${homeDirectory}/.config/openlist";
  };

  secrets.identityFile = ageIdentityFile;

  mcp.braveSearch.envFile = "${homeDirectory}/.config/antigravity/brave-search.env";

  zen.profilePath = "i41yvfec.Default Profile";
}
