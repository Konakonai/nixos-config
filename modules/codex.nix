{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  codexCli = pkgs.callPackage ../pkgs/codex.nix { };

  codexDesktopFlake = (import "${inputs.codex-desktop-linux}/flake.nix").outputs {
    self = {
      rev = inputs.codex-desktop-linux.rev or "";
      lastModified = inputs.codex-desktop-linux.lastModified or 1;
    };
    nixpkgs = inputs.nixpkgs-unstable;
    flake-utils = inputs.flake-utils;
  };

  codexDesktopBase =
    codexDesktopFlake.packages.${system}.codex-desktop-computer-use-ui;

  codexDesktop = pkgs.symlinkJoin {
    name = "${codexDesktopBase.name}-codex-cli-path";
    paths = [ codexDesktopBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      if [ -e "$out/bin/codex-desktop" ]; then
        rm -f "$out/bin/codex-desktop"
        makeWrapper "${codexDesktopBase}/bin/codex-desktop" "$out/bin/codex-desktop" \
          --set-default CODEX_CLI_PATH "${codexCli}/bin/codex"
      fi

      desktopFile="$out/share/applications/codex-desktop.desktop"
      if [ -e "$desktopFile" ]; then
        target="$(readlink -f "$desktopFile")"
        rm -f "$desktopFile"
        substitute "$target" "$desktopFile" \
          --replace-fail "${codexDesktopBase}/bin/codex-desktop" "$out/bin/codex-desktop"
      fi
    '';
    meta = codexDesktopBase.meta or { };
  };
in
{
  home.packages = [
    codexDesktop
  ];

  home.sessionVariables.CODEX_CLI_PATH = "${codexCli}/bin/codex";

  xdg.desktopEntries.codex-desktop = {
    name = "Codex Desktop";
    comment = "Run Codex Desktop on Linux";
    exec = "${codexDesktop}/bin/codex-desktop %u";
    icon = "codex-desktop";
    terminal = false;
    type = "Application";
    categories = [ "Development" ];
    mimeType = [
      "x-scheme-handler/codex"
      "x-scheme-handler/codex-browser-sidebar"
    ];
    settings = {
      StartupNotify = "true";
      StartupWMClass = "codex-desktop";
      X-GNOME-WMClass = "codex-desktop";
    };
    actions.new-window = {
      name = "New Window";
      exec = "${codexDesktop}/bin/codex-desktop --new-instance";
    };
  };
}
