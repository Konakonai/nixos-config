{
  # Reading defaults for the full-width column niri gives Okular
  # (niri/core.nix): two pages side by side, each scaled to the column height,
  # so text is near paper size without scrolling or fit-width blow-up.
  # plasma-manager rewrites only these keys on activation; Okular still keeps
  # per-document zoom and view state in its own docdata.
  programs.okular = {
    enable = true;
    # Installed with the other desktop apps in apps/desktop.nix.
    package = null;
    general = {
      viewMode = "Facing";
      zoomMode = "fitPage";
      mouseMode = "TextSelect";
    };
  };

  # Paper PDFs carry wide white margins; trimming them enlarges the text in
  # the same space. Not exposed as a programs.okular option.
  programs.plasma.configFile.okularpartrc.PageView.TrimMargins = true;
}
