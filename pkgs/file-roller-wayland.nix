{
  file-roller,
  gtk4,
}:

let
  gtk4WithWindowForgetFix = gtk4.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ../patches/gtk4-wayland-window-forget-null-check.patch
    ];
  });
in
file-roller.overrideAttrs (oldAttrs: {
  # GTK 4.22.4 can dereference a missing Wayland surface while File Roller
  # destroys its batch-operation dialog. Keep the workaround app-local by
  # loading the patched GTK only for File Roller.
  preFixup = (oldAttrs.preFixup or "") + ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${gtk4WithWindowForgetFix}/lib")
  '';
})
