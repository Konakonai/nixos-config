{
  inputs,
  lib,
  lilyaTheme,
  ...
}:

let
  inherit (lilyaTheme) palette;
  hex = lib.removePrefix "#";
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # The module installs the patched Spotify itself; do not add pkgs.spotify.
  programs.spicetify = {
    enable = true;
    # Native Wayland with text-input-v3 so fcitx5 works in search, in both
    # niri and Plasma (NIXOS_OZONE_WL is only a hint the wrapper may ignore).
    wayland = true;

    # Spicetify's built-in theme with a color.ini generated from the shared
    # palette, so Spotify follows the rest of the desktop.
    customColorScheme = {
      text = hex palette.text;
      subtext = hex palette.subtext;
      main = hex palette.base;
      sidebar = hex palette.mantle;
      player = hex palette.mantle;
      card = hex palette.mantle;
      shadow = hex palette.crust;
      selected-row = hex palette.text;
      button = hex palette.accent;
      button-active = hex palette.lavender;
      button-disabled = hex palette.overlay;
      tab-active = hex palette.hover;
      notification = hex palette.accent;
      notification-error = hex palette.error;
      misc = hex palette.overlay;
    };
  };
}
