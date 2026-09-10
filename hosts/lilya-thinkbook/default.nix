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
    internal = {
      make = "California Institute of Technology";
      model = "0x1626";
      serial = "0x00006002";
      scale = 1.75;
      # Match the physical layout: the laptop panel sits on the left.
      position = { x = -1829; y = 149; };
    };

    external = {
      make = "Philips Consumer Electronics Company";
      model = "PHL 27E2F7901";
      serial = "UHB2341003696";
      scale = 1.5;
      position = { x = 0; y = 0; };
    };
  };

  graphics.nvidia = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  kernel.blacklistedModules = [
    # This Legion/GameZone-specific WMI path probes on the ThinkBook but cannot
    # provide a platform profile. ideapad_laptop owns the working profile API.
    "lenovo_wmi_gamezone"
  ];

  services = {
    openlistDataDir = "${homeDirectory}/.config/openlist";
  };

  virtualization.externalWindows = {
    enable = true;
    domainName = "external-windows-11";
    uuid = "f03897ba-9c7c-4500-b12d-5e3c95eb0c2b";
    diskById = "/dev/disk/by-id/usb-_aigo_U397_071C3711211EA213-0:0";
    diskSerial = "071C3711211EA213";
    memoryGiB = 16;
    vcpus = 8;
  };

  secrets.identityFile = ageIdentityFile;

  mcp.braveSearch.envFile = "${homeDirectory}/.config/antigravity/brave-search.env";

  zen.profilePath = "i41yvfec.Default Profile";
}
