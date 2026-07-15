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
  cc-switch-cli = pkgs.callPackage ./cc-switch-cli/default.nix { };
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
  mindustry = pkgs.callPackage ./mindustry.nix { };
  splayer = pkgs.callPackage ./splayer.nix { };
  touhou-grub-theme = pkgs.callPackage ./touhou-grub-theme.nix { };
  touhou-plymouth-theme = pkgs.callPackage ./touhou-plymouth-theme.nix { };
  wiiu-downloader = pkgs.callPackage ./wiiu-downloader.nix { };

  mcp-server-brave-search = args:
    pkgs.callPackage ./mcp-server-brave-search.nix args;

  wechat = args:
    pkgs.callPackage ./wechat.nix args;
}
