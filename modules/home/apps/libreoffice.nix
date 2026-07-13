{ lib, pkgs, ... }:

let
  libreofficeWayland = pkgs.symlinkJoin {
    name = "libreoffice-wayland-${pkgs.libreoffice.version}";
    paths = [ pkgs.libreoffice ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      for program in libreoffice sbase scalc sdraw simpress smath soffice swriter; do
        rm "$out/bin/$program"
        makeWrapper "${pkgs.libreoffice}/bin/$program" "$out/bin/$program" \
          --set GDK_BACKEND wayland \
          --set SAL_USE_VCLPLUGIN gtk3
      done
    '';

    meta = pkgs.libreoffice.meta;
  };

  seedTabbedMode = app: ''
    if ! grep -Fq 'oor:path="/org.openoffice.Office.UI.ToolbarMode/Applications/${app}"' "$registry"; then
      ${pkgs.perl}/bin/perl -0pi -e 's|</oor:items>|<item oor:path="/org.openoffice.Office.UI.ToolbarMode/Applications/${app}"><prop oor:name="Active" oor:op="fuse"><value>notebookbar.ui</value></prop></item>\n</oor:items>|' "$registry"
    fi
  '';
in
{
  home.packages = [ libreofficeWayland ];

  # Seed the Office-like tabbed interface once, while leaving later UI changes
  # under LibreOffice's ownership.
  home.activation.seedLibreOfficeTabbedUi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    registry="$HOME/.config/libreoffice/4/user/registrymodifications.xcu"
    mkdir -p "$(dirname "$registry")"

    if [ ! -e "$registry" ]; then
      printf '%s\n' \
        '<?xml version="1.0" encoding="UTF-8"?>' \
        '<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' \
        '</oor:items>' \
        > "$registry"
    fi

    ${lib.concatMapStrings seedTabbedMode [ "Writer" "Calc" "Impress" "Draw" ]}
  '';
}
