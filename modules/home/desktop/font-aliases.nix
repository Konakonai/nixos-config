{ lib, ... }:

let
  fontMappings = [
    { from = "微软雅黑"; to = "Noto Sans CJK SC"; }
    { from = "Microsoft YaHei"; to = "Noto Sans CJK SC"; }
    { from = "黑体"; to = "Noto Sans CJK SC"; }
    { from = "SimHei"; to = "Noto Sans CJK SC"; }
    { from = "华文细黑"; to = "Noto Sans CJK SC"; }
    { from = "STXihei"; to = "Noto Sans CJK SC"; }
    { from = "Arial"; to = "Noto Sans CJK SC"; }
    { from = "Calibri"; to = "Noto Sans CJK SC"; }
    { from = "Helvetica"; to = "Noto Sans CJK SC"; }
    { from = "Motiva"; to = "Noto Sans CJK SC"; }
    { from = "Motiva Sans"; to = "Noto Sans CJK SC"; }
    { from = "Motiva Sans Light"; to = "Noto Sans CJK SC"; }
    { from = "Motiva Sans Medium"; to = "Noto Sans CJK SC"; }
    { from = "Motiva Sans Bold"; to = "Noto Sans CJK SC"; }

    { from = "宋体"; to = "Noto Serif CJK SC"; }
    { from = "SimSun"; to = "Noto Serif CJK SC"; }
    { from = "新宋体"; to = "Noto Serif CJK SC"; }
    { from = "NSimSun"; to = "Noto Serif CJK SC"; }
    { from = "仿宋"; to = "Noto Serif CJK SC"; }
    { from = "FangSong"; to = "Noto Serif CJK SC"; }
    { from = "楷体"; to = "Noto Serif CJK SC"; }
    { from = "KaiTi"; to = "Noto Serif CJK SC"; }
    { from = "Times New Roman"; to = "Noto Serif CJK SC"; }
  ];

  fontConfigXml = lib.concatStringsSep "\n" (map (m: ''
      <match target="pattern">
        <test qual="any" name="family"><string>${m.from}</string></test>
        <edit name="family" mode="assign" binding="same"><string>${m.to}</string></edit>
      </match>
  '') fontMappings);

  defaultFontConfigXml = ''
    <alias>
      <family>sans-serif</family>
      <prefer>
        <family>Noto Sans CJK SC</family>
        <family>Noto Sans</family>
      </prefer>
    </alias>

    <alias>
      <family>serif</family>
      <prefer>
        <family>Noto Serif CJK SC</family>
        <family>Noto Serif</family>
      </prefer>
    </alias>

    <alias>
      <family>monospace</family>
      <prefer>
        <family>JetBrains Maple Mono</family>
        <family>Maple Mono Normal NF</family>
        <family>Noto Sans Mono CJK SC</family>
      </prefer>
    </alias>
  '';

  steamFontConfigXml = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
      <include ignore_missing="yes">conf.d</include>
    </fontconfig>
  '';

  steamFontConfigStamp = builtins.hashString "sha256" ''
    ${steamFontConfigXml}
    ${defaultFontConfigXml}
    ${fontConfigXml}
  '';
in
{
  xdg.configFile."fontconfig/fonts.conf".text = steamFontConfigXml;

  xdg.configFile."fontconfig/conf.d/99-simsun-alias.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      ${defaultFontConfigXml}
      ${fontConfigXml}
    </fontconfig>
  '';

  home.activation.refreshSteamFontCache =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
