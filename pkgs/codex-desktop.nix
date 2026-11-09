{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  codexCli = pkgs.lilya.codex;

  codexDesktopFlake = (import "${inputs.codex-desktop-linux}/flake.nix").outputs {
    self = {
      rev = inputs.codex-desktop-linux.rev or "";
      lastModified = inputs.codex-desktop-linux.lastModified or 1;
    };
    nixpkgs = inputs.nixpkgs;
    flake-utils = inputs.flake-utils;
  };

  codexDesktopUnpatched = codexDesktopFlake.packages.${system}.codex-desktop.override {
    linuxFeatureIds = [
      "computer-use-linux"
      # Replace the upstream Parcel Git watcher with a watcher whose
      # disposal is joined before the Electron process exits.
      "directory-only-working-tree-watch"
      "frameless-titlebar"
    ];
  };
  # Node 24.22 / 26 fs.cpSync keeps the source's directory modes, so the
  # watchbound feature copies store files as 0555 and its own rmSync of the
  # staging root fails with EACCES. Node 22 still copies them writable.
  # Drop once codex-desktop-linux restores write permission after copying.
  codexDesktopBase = codexDesktopUnpatched.overrideAttrs (previous: {
    nativeBuildInputs = map (
      input: if input == pkgs.nodejs then pkgs.nodejs_22 else input
    ) previous.nativeBuildInputs;
  });

  codexDesktop = pkgs.symlinkJoin {
    name = "${codexDesktopBase.name}-codex-cli-path";
    paths = [ codexDesktopBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      if [ -e "$out/bin/codex-desktop" ]; then
        rm -f "$out/bin/codex-desktop"
        makeWrapper "${codexDesktopBase}/bin/codex-desktop" "$out/bin/codex-desktop" \
          --set CODEX_CLI_PATH "${codexCli}/bin/codex"
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
codexDesktop
