{
  pkgs,
  inputs,
  lib ? pkgs.lib,
}:

let
  fileRollerWayland = pkgs.callPackage ./file-roller-wayland.nix { };
in
{
  antigravity = pkgs.callPackage ./antigravity.nix { };
  brave-origin = pkgs.callPackage ./brave-origin.nix { };
  cc-switch = pkgs.callPackage ./cc-switch.nix { };
  celluloid-gl = pkgs.celluloid.overrideAttrs (previous: {
    preFixup = (previous.preFixup or "") + ''
      gappsWrapperArgs+=(--set GSK_RENDERER gl)
    '';
  });
  codex = pkgs.callPackage ./codex.nix { };
  codex-desktop = pkgs.callPackage ./codex-desktop.nix { inherit inputs; };
  file-roller-wayland = fileRollerWayland;
  grok = pkgs.callPackage ./grok.nix { };
  grok-bot = pkgs.callPackage ./grok-bot.nix { };
  jetbrains-maple-mono = pkgs.callPackage ./jetbrains-maple-mono.nix { };
  localsend-no-csd = pkgs.symlinkJoin {
    name = "${pkgs.localsend.name}-no-csd";
    paths = [ pkgs.localsend ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # niri does not draw server-side decorations, while KWin does. Keep the
    # Flutter CSD workaround scoped to niri so Plasma can provide its title bar.
    postBuild = ''
      rm "$out/bin/localsend_app"
      makeWrapper ${lib.getExe pkgs.localsend} "$out/bin/localsend_app" \
        --run 'case "''${XDG_CURRENT_DESKTOP:-}:''${XDG_SESSION_DESKTOP:-}" in *niri*) export GTK_CSD=0 ;; esac'
    '';
    meta = pkgs.localsend.meta;
  };
  mactahoe-kde = pkgs.callPackage ./mactahoe-kde.nix { };
  # nemo-fileroller embeds File Roller's absolute path at build time, so the
  # extension must be rebuilt to make Nemo use the app-local GTK workaround.
  nemo-with-extensions-wayland = pkgs.nemo-with-extensions.override {
    nemo-fileroller = pkgs.nemo-fileroller.override {
      file-roller = fileRollerWayland;
    };
  };
  libreoffice-gtk-wayland = pkgs.callPackage ./libreoffice-gtk-wayland.nix { };
  touhou-grub-theme = pkgs.callPackage ./touhou-grub-theme.nix { };
  touhou-plymouth-theme = pkgs.callPackage ./touhou-plymouth-theme.nix { };
  wiiu-downloader = pkgs.callPackage ./wiiu-downloader.nix { };
}
