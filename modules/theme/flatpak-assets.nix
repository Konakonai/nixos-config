{ lib, pkgs, ... }:

let
  lilyaGlass = import ../glass-settings.nix;
  gtkThemeName = "rose-pine-dawn";
  gtkThemePackage = pkgs.rose-pine-gtk-theme;
  cursorThemePackage = pkgs.rose-pine-cursor;
  cursorThemeName = lilyaGlass.cursorThemeName;
  iconThemePackage = pkgs.colloid-icon-theme;
  iconThemeName = lilyaGlass.iconThemeName;
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
    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/icons/${cursorThemeName}"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"

    RIME_ICON="${../../assets/fcitx-rime.svg}"
    for d in "$HOME/.local/share/icons/${iconThemeName}"; do
      for s in 16 22 24; do
        if [ -d "$d/status/$s" ]; then
          cp -f "$RIME_ICON" "$d/status/$s/fcitx-rime.svg"
        fi
      done
    done

    # Flatpak filesystem and environment overrides are declared in modules/flatpak.nix.
  '';
}
