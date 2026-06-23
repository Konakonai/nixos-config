{ lib, ... }:

let
  fcitxEnv = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
  };

  withFcitx = command:
    lib.concatStringsSep " " (
      [ "env" ]
      ++ lib.mapAttrsToList (name: value: "${name}=${value}") fcitxEnv
      ++ [ command ]
    );
in
{
  _module.args = {
    inherit fcitxEnv withFcitx;
  };

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="Noto Sans CJK SC 10"
    Theme=Nord-Light
  '';
}
