{ lilyaGlass, pkgs, ... }:

let
  fcitxCompatEnv = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };
in
{
  _module.args = {
    inherit fcitxCompatEnv;
  };

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="${lilyaGlass.fonts.sans} 10"
    Theme=catppuccin-frappe-lavender
  '';
}
