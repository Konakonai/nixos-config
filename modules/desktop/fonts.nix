{
  hostProfile,
  lib,
  lilyaTheme,
  pkgs,
  ...
}:

let
  jetbrainsMapleMono = pkgs.lilya.jetbrains-maple-mono;

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
  fonts = {
    fontDir.enable = true;

    # The default set (enabled by Plasma) brings back the variable CJK fonts;
    # its other members are listed below instead.
    enableDefaultPackages = false;

    packages = with pkgs; [
      jetbrainsMapleMono
      maple-mono."Normal-NF"

      # Rest of the NixOS default font set.
      dejavu_fonts
      freefont_ttf
      gyre-fonts
      liberation_ttf
      unifont

      noto-fonts
      # Static, not the variable CJK fonts: Gecko (Zen, Thunderbird) gets the
      # advance widths of the variable font's non-Regular weights wrong, so
      # bold Latin falling back to CJK SC renders crammed and overlapping.
      noto-fonts-cjk-sans-static
      noto-fonts-cjk-serif-static
      noto-fonts-color-emoji
      # Many web pages and emails list Inter first and tune letter-spacing for it.
      inter

      # 霞鹜文楷：GB 字形、TC（繁体字形，阅读器用）、屏幕阅读版。
      lxgw-wenkai
      lxgw-wenkai-tc
      lxgw-wenkai-screen
      # Foliate 英文正文。
      literata
      # Foliate 里书籍指定的宋体、明体（标题、引文）。
      pkgs.lilya.genryumin

      # Keep Office documents close to their original Word pagination.
      corefonts
      vista-fonts
      vista-fonts-chs
    ];

    fontconfig.defaultFonts = {
      monospace = [
        lilyaTheme.fonts.mono
        "Maple Mono Normal NF"
        "Noto Sans Mono CJK SC"
      ];

      sansSerif = [
        lilyaTheme.fonts.sans
        "Noto Sans"
      ];

      serif = [
        lilyaTheme.fonts.serif
        "Noto Serif"
      ];

      emoji = [
        "Noto Color Emoji"
      ];
    };
  };

  home-manager.users.${hostProfile.user.userName} =
    { lib, ... }:
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
    };
}
