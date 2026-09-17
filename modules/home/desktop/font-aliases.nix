{ lib, lilyaTheme, ... }:

let
  fontMappings = [
    {
      from = "黑体";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "SimHei";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "华文细黑";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "STXihei";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "华文中宋";
      to = lilyaTheme.fonts.serif;
    }
    {
      from = "STZhongsong";
      to = lilyaTheme.fonts.serif;
    }

    {
      from = "仿宋";
      to = lilyaTheme.fonts.serif;
    }
    {
      from = "FangSong";
      to = lilyaTheme.fonts.serif;
    }
    {
      from = "楷体";
      to = lilyaTheme.fonts.serif;
    }
    {
      from = "KaiTi";
      to = lilyaTheme.fonts.serif;
    }
  ];

  steamMappings = [
    {
      from = "Helvetica";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "Motiva";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "Motiva Sans";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "Motiva Sans Light";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "Motiva Sans Medium";
      to = lilyaTheme.fonts.sans;
    }
    {
      from = "Motiva Sans Bold";
      to = lilyaTheme.fonts.sans;
    }
  ];
  steamOverrides = lib.concatMapStrings (m: ''
    <match target="pattern">
      <test qual="any" name="family"><string>${m.from}</string></test>
      <edit name="family" mode="assign" binding="same"><string>${m.to}</string></edit>
    </match>
  '') steamMappings;

  fontConfigXml = lib.concatStringsSep "\n" (
    map (m: ''
      <alias binding="same">
        <family>${m.from}</family>
        <accept><family>${m.to}</family></accept>
      </alias>
    '') fontMappings
  );

  steamFontConfigXml = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      ${steamOverrides}
    </fontconfig>
  '';

  steamFontConfigStamp = builtins.hashString "sha256" ''
    ${steamFontConfigXml}
    ${fontConfigXml}
  '';
in
{
  xdg.configFile."fontconfig/steam.conf".text = steamFontConfigXml;

  xdg.configFile."fontconfig/conf.d/99-simsun-alias.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${fontConfigXml}
    </fontconfig>
  '';

  home.activation.refreshSteamFontCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    stamp_dir="$HOME/.local/state/nixos-config"
    stamp_file="$stamp_dir/steam-fontconfig-stamp"
    stamp=${lib.escapeShellArg steamFontConfigStamp}

    if [ "$(cat "$stamp_file" 2>/dev/null || true)" != "$stamp" ]; then
      rm -rf "$HOME/.local/share/Steam/fontconfig" \
        "$HOME/.local/share/Steam/ubuntu12_32/fontconfig" \
        "$HOME/.local/share/Steam/ubuntu12_64/fontconfig"
      mkdir -p "$stamp_dir"
      printf '%s' "$stamp" > "$stamp_file"
    fi
  '';
}
