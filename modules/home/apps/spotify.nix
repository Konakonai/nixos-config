{ inputs, pkgs, ... }:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # The module installs the patched Spotify itself; do not add pkgs.spotify.
  programs.spicetify = {
    enable = true;
    # Native Wayland with text-input-v3 so fcitx5 works in search, in both
    # niri and Plasma (NIXOS_OZONE_WL is only a hint the wrapper may ignore).
    wayland = true;

    # Spotify hard-codes dark surfaces that a bare color.ini cannot reach;
    # Catppuccin ships CSS overrides for them, and Latte matches the desktop's
    # light palette. The accent (lavender) is picked in Spotify's settings.
    theme = spicePkgs.themes.catppuccin;
    colorScheme = "latte";
  };
}
