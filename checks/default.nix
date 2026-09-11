{ pkgs, config, hostProfile }:

let
  home = config.home-manager.users.${hostProfile.user.userName};
  python = pkgs.python3.withPackages (ps: [ ps.tomlkit ps.pyyaml ]);
in
{
  configuration = pkgs.runCommand "configuration-regressions" {
    nativeBuildInputs = [ python pkgs.bash pkgs.coreutils pkgs.git pkgs.jq pkgs.util-linux ];
    NOCTALIA_SEED = home.xdg.dataFile."nixos-config/defaults/noctalia-config.toml".source;
    src = pkgs.lib.fileset.toSource {
      root = ../.;
      fileset = pkgs.lib.fileset.unions [ ../scripts ../modules/system/mihomo ];
    };
  } ''
    cp -R "$src" source
    chmod -R u+w source
    cd source
    python -B -m unittest discover -s scripts/tests -v
    touch "$out"
  '';

  portal = assert config.xdg.portal.config.niri."org.freedesktop.impl.portal.ScreenCast" == "gnome";
    assert config.xdg.portal.config.niri."org.freedesktop.impl.portal.FileChooser" == "gtk";
    pkgs.runCommand "portal-backend-contract" { } ''touch "$out"'';
}
