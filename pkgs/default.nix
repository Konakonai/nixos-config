{ pkgs, lib ? pkgs.lib }:

let
  braveOrigin = pkgs.callPackage ./brave-origin.nix { };
in
{
  antigravity = pkgs.callPackage ./antigravity.nix { };
  brave-origin = braveOrigin;
  brave-netflix-opera = pkgs.callPackage ./brave-netflix-opera.nix {
    inherit braveOrigin;
  };
  cc-switch = pkgs.symlinkJoin {
    name = "${pkgs.cc-switch.name}-session-backend";
    paths = [ pkgs.cc-switch ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm "$out/bin/cc-switch"
      makeWrapper ${lib.getExe pkgs.cc-switch} "$out/bin/cc-switch" \
        --run 'case "''${XDG_CURRENT_DESKTOP:-}" in *KDE*) export CC_SWITCH_GDK_BACKEND=wayland ;; esac'
    '';
    meta = pkgs.cc-switch.meta;
  };
  classin = pkgs.callPackage ./classin.nix { };
  codex = pkgs.callPackage ./codex.nix { };
  eden = pkgs.callPackage ./eden.nix { };
  file-roller-wayland = pkgs.callPackage ./file-roller-wayland.nix { };
  jetbrains-maple-mono = pkgs.callPackage ./jetbrains-maple-mono.nix { };
  localsend-no-csd = pkgs.symlinkJoin {
    name = "${pkgs.localsend.name}-no-csd";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # niri does not provide server-side decorations, and LocalSend's Flutter
    # runner otherwise adds a redundant GTK header bar on every Wayland session.
    postBuild = ''
      rm "$out/bin/localsend_app"
      makeWrapper ${lib.getExe pkgs.localsend} "$out/bin/localsend_app" \
        --set GTK_CSD 0
    '';
    meta = pkgs.localsend.meta;
  };
  mactahoe-kde = pkgs.callPackage ./mactahoe-kde.nix { };
  plasma-overdose-gtk-theme = pkgs.callPackage ./plasma-overdose-gtk-theme.nix { };
  plasma-overdose-theme = pkgs.callPackage ./plasma-overdose-theme.nix { };
  qoder = pkgs.callPackage ./qoder.nix { };
  splayer = pkgs.callPackage ./splayer.nix { };
  touhou-grub-theme = pkgs.callPackage ./touhou-grub-theme.nix { };
  touhou-plymouth-theme = pkgs.callPackage ./touhou-plymouth-theme.nix { };
  wiiu-downloader = pkgs.callPackage ./wiiu-downloader.nix { };

  mcp-server-brave-search = args:
    pkgs.callPackage ./mcp-server-brave-search.nix args;

  wechat = args:
    pkgs.callPackage ./wechat.nix args;
}
