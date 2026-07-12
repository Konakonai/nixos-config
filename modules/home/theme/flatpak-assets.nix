{ lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "adw-gtk3";
  gtkThemePackage = pkgs.adw-gtk3;
  cursorThemePackage = pkgs.rose-pine-cursor;
  cursorThemeName = lilyaGlass.cursorThemeName;
  iconThemePackage = pkgs.colloid-icon-theme;
  iconThemeName = lilyaGlass.iconThemeName;
  papirusIconSource = pkgs.papirus-icon-theme.src;
  papirusRimeIcons = pkgs.runCommand "papirus-fcitx-rime-icons" { } ''
    for size in 16 22 24; do
      mkdir -p "$out/$size"
      cp \
        ${papirusIconSource}/Papirus/"$size"x"$size"/actions/fcitx-rime.svg \
        "$out/$size/fcitx-rime.svg"
    done
  '';
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

    for size in 16 22 24; do
      install -m 0644 \
        "${papirusRimeIcons}/$size/fcitx-rime.svg" \
        "$HOME/.local/share/icons/${iconThemeName}/status/$size/fcitx-rime.svg"
    done

    # Flatpak filesystem and environment overrides are declared in modules/flatpak.nix.
  '';
}
