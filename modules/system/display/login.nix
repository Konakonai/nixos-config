{ pkgs, inputs, hostProfile, lib, lilyaGlass, ... }:

let
  loginWallpaper = hostProfile.display.loginWallpaper or null;

  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
  niriSession = "${niriPackage}/bin/niri-session";
  niriLogin = pkgs.writeShellScriptBin "Niri" ''
    unset GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME

    export NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    exec ${niriSession} "$@"
  '';
  plasmaLogin = pkgs.writeShellScriptBin "Plasma-HDR" ''
    unset GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME
    unset QT_STYLE_OVERRIDE QT_WAYLAND_DECORATION

    export QT_QPA_PLATFORMTHEME=kde

    exec ${lib.getExe' pkgs.kdePackages.plasma-workspace "startplasma-wayland"} "$@"
  '';

  mkWaylandSession =
    {
      id,
      name,
      comment,
      command,
      desktopNames,
    }:
    let
      desktopFile = pkgs.writeText "${id}.desktop" ''
        [Desktop Entry]
        Name=${name}
        Comment=${comment}
        Exec=${command}
        TryExec=${command}
        Type=Application
        DesktopNames=${desktopNames}
      '';
    in
    pkgs.runCommand "${id}-wayland-session"
      {
        passthru.providedSessions = [ id ];
      }
      ''
        mkdir -p "$out/share/wayland-sessions"
        ln -s ${desktopFile} "$out/share/wayland-sessions/${id}.desktop"
      '';

  niriLoginSession = mkWaylandSession {
    id = "niri";
    name = "Niri";
    comment = "Scrollable-tiling Wayland compositor";
    command = lib.getExe niriLogin;
    desktopNames = "niri";
  };
  plasmaLoginSession = mkWaylandSession {
    id = "plasma-hdr";
    name = "Plasma-HDR";
    comment = "KDE Plasma Wayland session with the KDE platform theme";
    command = lib.getExe plasmaLogin;
    desktopNames = "KDE";
  };

in
{
  programs.niri = {
    enable = true;
    package = niriPackage;
  };

  services.desktopManager.plasma6.enable = true;

  systemd.user.units."niri.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      UnsetEnvironment=GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME
    '';
  };

  services.greetd.enable = false;

  services.displayManager = {
    defaultSession = "plasma-hdr";
    sessionPackages = lib.mkForce [
      niriLoginSession
      plasmaLoginSession
    ];

    sddm = {
      enable = true;
      enableHidpi = true;
      theme = "${pkgs.lilya.mactahoe-kde}/share/sddm/themes/MacTahoe-Light";
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      settings.Theme = {
        CursorTheme = lilyaGlass.cursorThemeName;
        CursorSize = lilyaGlass.cursorSize;
        Font = lilyaGlass.fonts.sans;
      };
      settings.Users.RememberLastSession = false;
    };
  };
}
