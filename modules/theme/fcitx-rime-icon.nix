{ ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  iconThemeName = lilyaGlass.iconThemeName;
in
{
  xdg.dataFile."icons/${iconThemeName}/status/22/fcitx-rime.svg".source = ../../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${iconThemeName}/status/24/fcitx-rime.svg".source = ../../assets/fcitx-rime.svg;
  xdg.dataFile."icons/${iconThemeName}/status/16/fcitx-rime.svg".source = ../../assets/fcitx-rime.svg;
  xdg.dataFile."icons/hicolor/scalable/apps/fcitx-rime.svg".source = ../../assets/fcitx-rime.svg;
}
