{ pkgs, inputs, config, lib, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  kmsconConfig = pkgs.writeTextDir "kmscon.conf" config.services.kmscon.extraConfig;
  tuigreetKmscon = pkgs.writeShellScript "tuigreet-kmscon" ''
    exec ${lib.getExe pkgs.kmscon} \
      --configdir ${kmsconConfig} \
      --vt tty1 \
      --seats=seat0 \
      --no-switchvt \
      --no-reset-env \
      --login \
      -- ${lib.getExe pkgs.tuigreet} \
        --time \
        --remember \
        --remember-user-session \
        --asterisks \
        --theme 'border=blue;text=cyan;prompt=green;time=yellow;action=blue;button=red' \
        --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions:${config.services.displayManager.sessionData.desktops}/share/xsessions
  '';
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

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      default_session = {
        command = "${tuigreetKmscon}";
        user = "greeter";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter - -"
  ];

  console = {
    earlySetup = true;
    packages = with pkgs; [ terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
    colors = [
      "2e3440" "bf616a" "a3be8c" "ebcb8b"
      "81a1c1" "b48ead" "88c0d0" "e5e9f0"
      "4c566a" "bf616a" "a3be8c" "ebcb8b"
      "81a1c1" "b48ead" "8fbcbb" "eceff4"
    ];
  };

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
