{ pkgs, ... }:

let
  libreofficeGtk4Unwrapped = pkgs.libreoffice.unwrapped.overrideAttrs (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ pkgs.gtk4 ];
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [ "--enable-gtk4" ];
  });

  libreofficeGtk4 = pkgs.libreoffice.override {
    unwrapped = libreofficeGtk4Unwrapped;
  };
in
pkgs.symlinkJoin {
  name = "libreoffice-gtk4-wayland-${libreofficeGtk4.version}";
  paths = [ libreofficeGtk4 ];
  nativeBuildInputs = [ pkgs.makeWrapper ];

  postBuild = ''
    for program in libreoffice sbase scalc sdraw simpress smath soffice swriter; do
      rm "$out/bin/$program"
      makeWrapper "${libreofficeGtk4}/bin/$program" "$out/bin/$program" \
        --set GDK_BACKEND wayland \
        --set SAL_USE_VCLPLUGIN gtk4
    done
  '';

  meta = libreofficeGtk4.meta // {
    description = "LibreOffice with the experimental GTK4 frontend";
  };

  passthru = {
    unwrapped = libreofficeGtk4Unwrapped;
    wrapped = libreofficeGtk4;
  };
}
