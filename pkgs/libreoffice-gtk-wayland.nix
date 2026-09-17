{
  libreoffice,
  symlinkJoin,
  makeWrapper,
}:

symlinkJoin {
  name = "libreoffice-gtk-wayland-${libreoffice.version}";
  paths = [ libreoffice ];
  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    for program in libreoffice sbase scalc sdraw simpress smath soffice swriter; do
      rm "$out/bin/$program"
      makeWrapper "${libreoffice}/bin/$program" "$out/bin/$program" \
        --set GDK_BACKEND wayland \
        --set SAL_USE_VCLPLUGIN gtk3
    done
  '';

  meta = libreoffice.meta;
}
