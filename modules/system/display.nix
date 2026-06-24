{ pkgs, inputs, config, lib, ... }:

let
  lilyaGlass = import ../glass-settings.nix;

  niriBase = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  niriPatched = pkgs.runCommandLocal "${niriBase.name}-patched-session" {
    passthru = niriBase.passthru or { };
    meta = niriBase.meta or { };
    cargoBuildNoDefaultFeatures = niriBase.cargoBuildNoDefaultFeatures;
    cargoBuildFeatures = niriBase.cargoBuildFeatures;
  } ''
    cp -a ${niriBase} $out
    chmod -R u+w $out
    substituteInPlace $out/bin/niri-session \
      --replace-fail 'systemctl --user import-environment' 'systemctl --user import-environment $(env | cut -d= -f1)'
  '';
  niriSession = "${niriPatched}/bin/niri-session";

  gtkgreetCss = pkgs.writeText "gtkgreet.css" ''
    window {
      background-color: ${lilyaGlass.palette.base};
      color: ${lilyaGlass.palette.text};
      font-family: "${lilyaGlass.fonts.sans}";
      font-size: 15px;
    }

    box#body {
      background-color: rgba(236, 239, 244, 0.92);
      border: 1px solid ${lilyaGlass.palette.crust};
      border-radius: 14px;
      box-shadow: 0 18px 50px rgba(46, 52, 64, 0.18);
      padding: 36px;
      min-width: 360px;
    }

    button {
      border-radius: 10px;
      padding: 8px 14px;
    }

    entry {
      border-radius: 10px;
      padding: 8px 10px;
    }
  '';

  gtkgreetCommand = pkgs.writeShellScript "gtkgreet-command" ''
    ${lib.getExe pkgs.gtkgreet} -l -s ${gtkgreetCss} -c ${lib.escapeShellArg niriSession}
    ${lib.getExe' pkgs.sway "swaymsg"} exit
  '';

  gtkgreetSwayConfig = pkgs.writeText "gtkgreet-sway-config" ''
    font pango:${lilyaGlass.fonts.sans} 11
    seat seat0 xcursor_theme ${lilyaGlass.cursorThemeName} 48

    output * bg ${lilyaGlass.palette.base} solid_color
    output eDP-1 scale 1.75 pos 0 149
    output DP-5 scale 1.5 pos 1829 0

    exec ${gtkgreetCommand}
  '';

  gtkgreetSession = pkgs.writeShellScript "gtkgreet-session" ''
    export GTK_THEME=adw-gtk3
    export XCURSOR_THEME=${lib.escapeShellArg lilyaGlass.cursorThemeName}
    export XCURSOR_SIZE=48
    export XDG_DATA_DIRS=${pkgs.adw-gtk3}/share:${pkgs.colloid-icon-theme}/share:${pkgs.nordzy-cursor-theme}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}

    exec ${pkgs.dbus}/bin/dbus-run-session ${lib.getExe pkgs.sway} --unsupported-gpu --config ${gtkgreetSwayConfig}
  '';
in
{
  programs.niri = {
    enable = true;
    package = niriPatched;
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
    useTextGreeter = false;
    settings = {
      default_session = {
        command = "${gtkgreetSession}";
        user = "greeter";
      };
    };
  };

  services.accounts-daemon.enable = true;

  environment.etc."greetd/environments".text = ''
    ${niriSession}
  '';

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
