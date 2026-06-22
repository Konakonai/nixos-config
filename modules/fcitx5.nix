{ config, pkgs, ... }:

{
  # Fcitx5 经典界面主题配置 (Nord Light)
  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="Noto Sans CJK SC 10"
    Theme=Nord-Light
  '';
}
