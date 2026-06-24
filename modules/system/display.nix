{ pkgs, inputs, config, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
in
{
  programs.niri = {
    enable = true;
    package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  };

  services.xserver = {
    enable = true;
    excludePackages = [ pkgs.xterm ];
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  services.greetd.enable = true;

  programs.regreet = {
    enable = true;
    theme = {
      package = pkgs.nordic;
      name = "Nordic-Polar";
    };
    iconTheme = {
      package = pkgs.colloid-icon-theme;
      name = "Colloid-Light";
    };
    cursorTheme = {
      package = pkgs.nordzy-cursor-theme;
      name = "Nordzy-cursors";
    };
    font = {
      package = pkgs.maple-mono."Normal-NF";
      name = "Maple Mono Normal NF";
      size = 12;
    };
    settings = {
      background = {
        path = "/etc/regreet-wallpaper.jpg";
        fit = "Cover";
      };
    };
  };

  environment.etc."regreet-wallpaper.jpg".source = ../../assets/sddm-wallpaper.jpg;

  security.sudo.extraConfig = "Defaults pwfeedback";

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  services.gvfs.enable = true;
  services.flatpak.enable = true;
  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  environment.systemPackages = [ ];
}
