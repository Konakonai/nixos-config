{ lib, pkgs, ... }:

let
  seedTabbedMode = app: ''
    if ! grep -Fq 'oor:path="/org.openoffice.Office.UI.ToolbarMode/Applications/${app}"' "$registry"; then
      tmp="$(${pkgs.coreutils}/bin/mktemp "$registry.XXXXXX")"
      ${pkgs.coreutils}/bin/cp "$registry" "$tmp"
      ${pkgs.perl}/bin/perl -0pi -e 's|</oor:items>|<item oor:path="/org.openoffice.Office.UI.ToolbarMode/Applications/${app}"><prop oor:name="Active" oor:op="fuse"><value>notebookbar.ui</value></prop></item>\n</oor:items>|' "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$registry"
    fi
  '';
in
{
  home.packages = [ pkgs.libreoffice ];

  # Seed the Office-like tabbed interface once, while leaving later UI changes
  # under LibreOffice's ownership. Edit a temp copy, then replace the registry
  # so a crashed perl -i cannot leave a truncated file.
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

    ${lib.concatMapStrings seedTabbedMode [
      "Writer"
      "Calc"
      "Impress"
      "Draw"
    ]}
  '';
}
