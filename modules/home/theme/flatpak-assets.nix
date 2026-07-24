{ lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "Plasma-Overdose-GTK";
  gtkThemePackage = pkgs.lilya.plasma-overdose-gtk-theme;
  cursorThemePackage = pkgs.lilya.plasma-overdose-theme;
  cursorThemeName = lilyaGlass.cursorThemeName;
  iconThemePackage = pkgs.tela-icon-theme;
  iconThemeName = lilyaGlass.iconThemeName;
  fallbackIconThemePackage = pkgs.adwaita-icon-theme;
in
{
  home.activation.flatpakThemeIntegration = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    copy_theme_dir() {
      local src="$1"
      local dst="$2"
      if [ -d "$src" ]; then
        if [ -e "$dst" ]; then
          chmod -R u+w "$dst" 2>/dev/null || true
        fi
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -aL "$src" "$dst"
        chmod -R u+w "$dst"
      fi
    }

    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}" "$HOME/.local/share/themes/${gtkThemeName}"
    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/flatpak-icons/${cursorThemeName}"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"
    copy_theme_dir "${fallbackIconThemePackage}/share/icons/Adwaita" "$HOME/.local/share/icons/Adwaita"

    # Flatpak filesystem and environment overrides are declared in modules/flatpak.nix.
  '';
}
