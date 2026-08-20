{ lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "adw-gtk3";
  gtkThemePackage = pkgs.adw-gtk3;
  cursorThemePackage = pkgs.adwaita-icon-theme;
  cursorThemeName = lilyaGlass.cursorThemeName;
  iconThemePackage = pkgs.colloid-icon-theme;
  iconThemeName = lilyaGlass.iconThemeName;
  fallbackIconThemePackage = pkgs.adwaita-icon-theme;
in
{
  home.activation.flatpakThemeIntegration = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    copy_theme_dir() {
      local src="$1"
      local dst="$2"
      local marker="$dst/.nix-source"
      if [ -L "$dst" ]; then
        return
      fi
      if [ -d "$src" ]; then
        if [ -f "$marker" ] && [ "$(< "$marker")" = "$src" ]; then
          return
        fi
        if [ -e "$dst" ]; then
          chmod -R u+w "$dst" 2>/dev/null || true
        fi
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -aL "$src" "$dst"
        chmod -R u+w "$dst"
        printf '%s\n' "$src" > "$marker"
      fi
    }

    copy_theme_dir "${gtkThemePackage}/share/themes/${gtkThemeName}" "$HOME/.local/share/themes/${gtkThemeName}"

    legacy_gtk_theme="$HOME/.local/share/themes/catppuccin-frappe-lavender-compact"
    if [ -e "$legacy_gtk_theme" ] && [ ! -L "$legacy_gtk_theme" ]; then
      chmod -R u+w "$legacy_gtk_theme" 2>/dev/null || true
      rm -rf "$legacy_gtk_theme"
    fi

    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/flatpak-icons/${cursorThemeName}"
    copy_theme_dir "${fallbackIconThemePackage}/share/icons/Adwaita" "$HOME/.local/share/flatpak-icons/Adwaita"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"
  '';
}
