{ pkgs, ... }:

let
  fcitx5Package = pkgs.qt6Packages.fcitx5-with-addons.override {
    addons = with pkgs; [
      fcitx5-gtk
      kdePackages.fcitx5-qt
      kdePackages.fcitx5-configtool
      fcitx5-nord

      (fcitx5-rime.override {
        rimeDataPkgs = with pkgs; [
          rime-data
          rime-ice
        ];
      })
    ];
  };

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
    inherit fcitx5Package fcitxCompatEnv;
  };

  home.packages = [ fcitx5Package ];

  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx 5 input method";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${fcitx5Package}/bin/fcitx5 --replace";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."fcitx5/conf/classicui.conf".text = ''
    Font="Noto Sans CJK SC 10"
    Theme=Nord-Light
  '';
}
