{
  file-roller,
  gtk4,
}:

let
  gtk4WithoutWaylandSessionForget = gtk4.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../patches/gtk4-wayland-disable-window-session-forget.patch
    ];
  });
in
file-roller.overrideAttrs (oldAttrs: {
  # GTK 4.22.4 can race Wayland session removal against File Roller's dialog
  # destruction. Keep the native-Wayland workaround app-local by loading the
  # patched GTK only for File Roller.
  preFixup = (oldAttrs.preFixup or "") + ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${gtk4WithoutWaylandSessionForget}/lib")
  '';
})
