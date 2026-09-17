{ colloid-icon-theme }:

# Colloid ships `fcitx-rime` only at fixed sizes, and its 24px file is a
# different, square glyph. Tray hosts that prefer scalable icons (Noctalia)
# therefore show the square one, while `fcitx-rime-symbolic` — the rounded
# 16px design — is scalable. Expose that design under the plain name so the
# tray, fcitx5 and Plasma all resolve the same icon.
colloid-icon-theme.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    for theme in "$out"/share/icons/Colloid*; do
      symbolic="$theme/status/symbolic/fcitx-rime-symbolic.svg"
      [ -e "$symbolic" ] || continue
      [ -e "$theme/status/symbolic/fcitx-rime.svg" ] && continue
      ln -s fcitx-rime-symbolic.svg "$theme/status/symbolic/fcitx-rime.svg"
      gtk-update-icon-cache --force --quiet "$theme"
    done
  '';
})
