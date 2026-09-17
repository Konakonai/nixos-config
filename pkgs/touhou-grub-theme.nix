{
  stdenvNoCC,
  fetchzip,
  imagemagick,
  lib,
}:

stdenvNoCC.mkDerivation {
  pname = "grub-theme-touhou-project";
  version = "2023-04-19";

  src = fetchzip {
    url = "https://github.com/13atm01/GRUB-Theme/releases/download/Tproject-v1.0/Touhou_Project.tar.gz";
    hash = "sha256-GcB4Drad77Ndd9LnNA+ZHzjnE4Rm+IwP9FDKLQodxTo=";
    stripRoot = false;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ imagemagick ];

  installPhase = ''
    mkdir -p "$out"
    cp -r "$src/Touhou Project/Touhou-project/." "$out/"
    test -f "$out/theme.txt"

    substituteInPlace "$out/theme.txt" \
      --replace-fail 'message-font: "Terminus Regular Bold 14"' 'message-font: "DejaVu Sans Regular 24"' \
      --replace-fail '    left = 18%' '    left = 16%' \
      --replace-fail '    top = 22%' '    top = 20%' \
      --replace-fail '    width = 60%' '    width = 62%' \
      --replace-fail '    height = 60%' '    height = 62%' \
      --replace-fail '    item_font = "Terminus Regular Bold 14"' '    item_font = "DejaVu Sans Regular 24"' \
      --replace-fail '    icon_width = 32' '    icon_width = 48' \
      --replace-fail '    icon_height= 32' '    icon_height= 48' \
      --replace-fail '    item_icon_space = 20' '    item_icon_space = 28' \
      --replace-fail '    item_height = 36' '    item_height = 58' \
      --replace-fail '    item_padding = 5' '    item_padding = 8' \
      --replace-fail '    item_spacing = 10' '    item_spacing = 14' \
      --replace-fail '    height = 4%' '    height = 3%'

    magick "$out/select_w.png" -filter Lanczos -resize x58 PNG32:"$out/select_w.resized.png"
    mv "$out/select_w.resized.png" "$out/select_w.png"
    magick "$out/select_c.png" -filter Lanczos -resize x58 PNG32:"$out/select_c.resized.png"
    mv "$out/select_c.resized.png" "$out/select_c.png"
  '';

  meta = {
    description = "Touhou Project GRUB theme from 13atm01/GRUB-Theme";
    homepage = "https://github.com/13atm01/GRUB-Theme";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.all;
  };
}
