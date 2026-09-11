# Patch Noctalia's standalone KDE color scheme from the generated qt6ct palette.
# Plasma's kdeglobals is owned by System Settings and is not written here.
set -eu

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
qt_scheme="$config_home/qt6ct/colors/darkly-noctalia.conf"

role_color() {
  local role="$1"
  gawk -F= -v role="$role" '
    /^active_colors=/ {
      split($2, colors, ",")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", colors[role])
      print colors[role]
      exit
    }
  ' "$qt_scheme"
}

hex_to_rgb() {
  local hex="${1#\#}"
  if [ "${#hex}" -ne 6 ]; then
    printf '229,205,204'
    return
  fi
  printf '%d,%d,%d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

[ -f "$qt_scheme" ] || exit 0

selection_bg="$(hex_to_rgb "$(role_color 13)")"
selection_fg="$(hex_to_rgb "$(role_color 14)")"

patch_colors() {
  local file="$1"
  [ -f "$file" ] || return 0

  kwriteconfig6 --file "$file" --group "Colors:View" --key "DecorationFocus" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:View" --key "DecorationHover" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "BackgroundAlternate" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "BackgroundNormal" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "DecorationFocus" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "DecorationHover" "$selection_bg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "ForegroundActive" "$selection_fg"
  kwriteconfig6 --file "$file" --group "Colors:Selection" --key "ForegroundNormal" "$selection_fg"
}

patch_colors "$data_home/color-schemes/noctalia.colors"
