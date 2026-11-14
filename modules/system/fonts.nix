{ lilyaTheme, pkgs, ... }:

let
  jetbrainsMapleMono = pkgs.lilya.jetbrains-maple-mono;
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
}
