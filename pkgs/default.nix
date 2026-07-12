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
  electron-43-bin = pkgs.callPackage ./electron-43-bin.nix { };
  jetbrains-maple-mono = pkgs.callPackage ./jetbrains-maple-mono.nix { };
  mindustry = pkgs.callPackage ./mindustry.nix { };
  splayer = pkgs.callPackage ./splayer.nix { };

  mcp-server-brave-search = args:
    pkgs.callPackage ./mcp-server-brave-search.nix args;

  wechat = args:
    pkgs.callPackage ./wechat.nix args;
}
