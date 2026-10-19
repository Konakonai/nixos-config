let
  userName = "lilya";
  homeDirectory = "/home/${userName}";
  ageIdentityFile = "${homeDirectory}/.config/age/mihomo.txt";
in
{
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
      # Narrowest eDP link that still carries 3200x2000@60 at 18 bpp
      # (HBR2 x2 = 8.64 Gbps of payload); see display/edp-link.nix.
      link = {
        drmDevice = "0000:00:02.0";
        connector = "eDP-1";
        rate = 540000;
        lanes = 2;
      };
      # Match the physical layout: the laptop panel sits on the left.
      position = {
        x = -1829;
        y = 149;
      };
    };

    external = {
      make = "Philips Consumer Electronics Company";
      model = "PHL 27E2F7901";
      serial = "UHB2341003696";
      scale = 1.5;
      position = {
        x = 0;
        y = 0;
      };
    };
  };

  graphics.nvidia = {
    intelBusId = "PCI:0:2:0";
    pci = {
      bus = 1;
      device = 0;
      function = 0;
    };
  };

  # Built-in USB devices that may runtime-suspend. External input devices
  # stay awake through the HID rule in modules/system/power/device-rules.nix.
  usb.internalDevices = [
    {
      # Integrated Camera
      vendor = "04f2";
      product = "b7b5";
    }
    {
      # Goodix fingerprint reader (no driver bound)
      vendor = "27c6";
      product = "659a";
    }
    {
      # Intel AX201 Bluetooth
      vendor = "8087";
      product = "0026";
    }
  ];

  kernel.blacklistedModules = [
    # This Legion/GameZone-specific WMI path probes on the ThinkBook but cannot
    # provide a platform profile. ideapad_laptop owns the working profile API.
    "lenovo_wmi_gamezone"
  ];

  services = {
    openlistDataDir = "${homeDirectory}/.config/openlist";
  };

  virtualization.externalWindows = {
    domainName = "external-windows-11";
    uuid = "f03897ba-9c7c-4500-b12d-5e3c95eb0c2b";
    diskById = "/dev/disk/by-id/usb-_aigo_U397_071C3711211EA213-0:0";
    diskSerial = "071C3711211EA213";
    memoryGiB = 16;
    vcpus = 8;
  };

  secrets.identityFile = ageIdentityFile;
}
