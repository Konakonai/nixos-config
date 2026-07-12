{ lib, lilyaGlass, pkgs, ... }:

let
  gtkThemeName = "adw-gtk3";
  gtkThemePackage = pkgs.adw-gtk3;
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
    copy_theme_dir "${cursorThemePackage}/share/icons/${cursorThemeName}" "$HOME/.local/share/flatpak-icons/${cursorThemeName}"
    copy_theme_dir "${iconThemePackage}/share/icons/${iconThemeName}" "$HOME/.local/share/icons/${iconThemeName}"

    # Noctalia resolves the first scalable SVG before considering fixed-size
    # status icons. Install Colloid's native Pinyin icon beside every
    # input-keyboard candidate so both states follow the same lookup path.
    ${pkgs.findutils}/bin/find \
      "$HOME/.local/share/icons/${iconThemeName}" \
      -type f -name input-keyboard.svg -print0 \
      | while IFS= read -r -d "" keyboard_icon; do
          icon_dir="$(${pkgs.coreutils}/bin/dirname "$keyboard_icon")"
          install -m 0644 \
            "${iconThemePackage}/share/icons/${iconThemeName}/status/22/fcitx-pinyin.svg" \
            "$icon_dir/fcitx-rime.svg"
        done

    # Flatpak filesystem and environment overrides are declared in modules/flatpak.nix.
  '';
}
