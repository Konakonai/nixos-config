{ lilyaGlass, ... }:

let
  iconThemeName = lilyaGlass.iconThemeName;
in
{
  # Colloid status icons are copied into the Flatpak-visible theme tree by
  # modules/home/theme/flatpak-assets.nix, so Home Manager only owns hicolor here.
  xdg.dataFile."icons/hicolor/scalable/apps/fcitx-rime.svg".source = ../../../assets/fcitx-rime.svg;
}
