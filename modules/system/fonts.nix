{ lilyaTheme, pkgs, ... }:

let
  jetbrainsMapleMono = pkgs.lilya.jetbrains-maple-mono;
in
{
  fonts = {
    fontDir.enable = true;

    packages = with pkgs; [
      jetbrainsMapleMono
      maple-mono."Normal-NF"

      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji

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
