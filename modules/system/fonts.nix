{ lilyaGlass, pkgs, ... }:

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

      # Keep Office documents close to their original Word pagination.
      corefonts
      vista-fonts
      vista-fonts-chs

      source-han-sans
      source-han-serif
      sarasa-gothic
    ];

    fontconfig.defaultFonts = {
      monospace = [
        lilyaGlass.fonts.mono
        "Maple Mono Normal NF"
        "Noto Sans Mono CJK SC"
      ];

      sansSerif = [
        lilyaGlass.fonts.sans
        "Noto Sans"
      ];

      serif = [
        lilyaGlass.fonts.serif
        "Noto Serif"
      ];

      emoji = [
        "Noto Color Emoji"
      ];
    };
  };
}
