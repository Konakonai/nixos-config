{ lib, lilyaTheme, pkgs, ... }:

let
  gtkThemeName = lilyaTheme.theme.gtk;
  gtkThemePackage = pkgs.adw-gtk3;
  cursorThemePackage = pkgs.catppuccin-cursors.frappeLavender;
  cursorThemeName = lilyaTheme.cursorThemeName;
  iconThemePackage = pkgs.colloid-icon-theme;
  iconThemeName = lilyaTheme.iconThemeName;
  fallbackIconThemePackage = pkgs.adwaita-icon-theme;
in
{
  home.activation.flatpakThemeIntegration = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    copy_theme_dir() {
      ${pkgs.bash}/bin/bash ${../../../scripts/copy-theme-dir.sh} "$1" "$2"
    }

    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}" "$HOME/.local/share/themes/${gtkThemeName}"

    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/flatpak-icons/${cursorThemeName}"
    copy_theme_dir "${fallbackIconThemePackage}/share/icons/Adwaita" "$HOME/.local/share/flatpak-icons/Adwaita"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"

    rime_symbolic="${iconThemePackage}/share/icons/${iconThemeName}/status/symbolic/fcitx-rime-symbolic.svg"
    if [ -f "$rime_symbolic" ]; then
      install -m 0644 "$rime_symbolic" "$HOME/.local/share/icons/${iconThemeName}/status/symbolic/fcitx-rime.svg"
      install -m 0644 "$rime_symbolic" "$HOME/.local/share/icons/${iconThemeName}/apps/scalable/fcitx-rime.svg"
      install -m 0644 "$rime_symbolic" "$HOME/.local/share/icons/${iconThemeName}/status/24/fcitx-rime.svg"
    fi
  '';
}
