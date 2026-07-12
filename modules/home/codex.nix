{ config, lib, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  codexCli = pkgs.lilya.codex;
  configPath = "${config.home.homeDirectory}/nixos-config";

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

  codexDesktopPatched = codexDesktopBase.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.nodejs ];
    postInstall = (old.postInstall or "") + ''
      # codex-desktop-linux enables Electron's window-controls overlay on
      # Linux. Disable it both at window creation and in later zoom/theme
      # updates so Codex keeps its draggable app title bar without the native
      # minimize/maximize/close block.
      asarPath="$out/opt/codex-desktop/resources/app.asar"
      asarWorkDir="$(mktemp -d)"
      asar extract "$asarPath" "$asarWorkDir/app"
      cp -aL "$asarPath.unpacked/." "$asarWorkDir/app/"

      mainBundle="$(find "$asarWorkDir/app/.vite/build" -maxdepth 1 -type f -name 'main-*.js' -print -quit)"
      if [ -z "$mainBundle" ]; then
        echo "Codex main-process bundle was not found" >&2
        exit 1
      fi

      node - "$mainBundle" <<'NODE'
      const fs = require("fs");
      const path = process.argv[2];
      const source = fs.readFileSync(path, "utf8");
      const windowOptionPattern = /titleBarOverlay:([A-Za-z_$][\w$]*)===`linux`\?codexLinuxTitleBarOverlay\(([^)]+)\):([^,]+),/g;
      const overlayUpdatePattern = /([A-Za-z_$][\w$]*)\.setTitleBarOverlay\(process\.platform===`linux`\?codexLinuxTitleBarOverlay\((.*?)\):([A-Za-z_$][\w$]*)\((.*?)\)\)/g;
      const windowOptionMatches = source.match(windowOptionPattern) ?? [];
      const overlayUpdateMatches = source.match(overlayUpdatePattern) ?? [];

      if (windowOptionMatches.length !== 1 || overlayUpdateMatches.length !== 2) {
        throw new Error(
          `Expected one Codex Linux window option and two overlay updates, found ` +
            `''${windowOptionMatches.length} and ''${overlayUpdateMatches.length}`,
        );
      }

      const patched = source
        .replace(
          windowOptionPattern,
          (_match, platform, _zoom, windowsOverlay) =>
            `titleBarOverlay:''${platform}===\`linux\`?!1:''${windowsOverlay},`,
        )
        .replace(
          overlayUpdatePattern,
          (_match, window, _linuxOptions, windowsHelper, windowsOptions) =>
            `process.platform!==\`linux\`&&''${window}.setTitleBarOverlay(` +
            `''${windowsHelper}(''${windowsOptions}))`,
        );

      fs.writeFileSync(
        path,
        patched,
      );
      NODE

      rm -f "$asarPath"
      rm -rf "$asarPath.unpacked"
      asar pack "$asarWorkDir/app" "$asarPath" --unpack "*.node"
      rm -rf "$asarWorkDir"
    '';
  });

  codexDesktop = pkgs.symlinkJoin {
    name = "${codexDesktopPatched.name}-codex-cli-path";
    paths = [ codexDesktopPatched ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      if [ -e "$out/bin/codex-desktop" ]; then
        rm -f "$out/bin/codex-desktop"
        makeWrapper "${codexDesktopPatched}/bin/codex-desktop" "$out/bin/codex-desktop" \
          --set-default CODEX_CLI_PATH "${codexCli}/bin/codex"
      fi

      desktopFile="$out/share/applications/codex-desktop.desktop"
      if [ -e "$desktopFile" ]; then
        target="$(readlink -f "$desktopFile")"
        rm -f "$desktopFile"
        substitute "$target" "$desktopFile" \
          --replace-fail "${codexDesktopPatched}/bin/codex-desktop" "$out/bin/codex-desktop"
        substituteInPlace "$desktopFile" \
          --replace-fail "Actions=new-window;CheckForUpdates;InstallReadyUpdate;" "Actions=new-window;"
        awk '
          /^\[Desktop Action (CheckForUpdates|InstallReadyUpdate)\]$/ { skip = 1; next }
          /^\[/ { skip = 0 }
          !skip
        ' "$desktopFile" > "$desktopFile.cleaned"
        mv "$desktopFile.cleaned" "$desktopFile"
      fi
    '';
    meta = codexDesktopBase.meta or { };
  };

  codexDesktopUpdate = pkgs.writeShellApplication {
    name = "codex-desktop-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gh
      pkgs.gnugrep
      pkgs.jq
      pkgs.libnotify
      pkgs.nix
    ];
    text = ''
      set -euo pipefail

      repo=${lib.escapeShellArg configPath}
      input_name=codex-desktop-linux
      upstream_ref=refs/heads/main
      upstream_url=https://github.com/ilysenko/codex-desktop-linux.git
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/codex-desktop-update"
      log_file="$log_dir/update.log"

      mkdir -p "$log_dir"
      exec >>"$log_file" 2>&1

      notify() {
        if [ -n "''${DISPLAY:-}" ] || [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          notify-send "Codex Desktop update" "$1" >/dev/null 2>&1 || true
        fi
      }

      echo "== $(date --iso-8601=seconds) =="
      cd "$repo"

      github_token="$(gh auth token 2>/dev/null || true)"
      if [ -n "$github_token" ]; then
        export NIX_CONFIG="''${NIX_CONFIG:-}
access-tokens = github.com=$github_token"
      else
        echo "gh auth token unavailable; nix may use anonymous GitHub API"
      fi

      if [ -n "$(git status --porcelain)" ]; then
        echo "working tree is not clean; skipping"
        notify "Skipped: nixos-config is not clean."
        exit 0
      fi

      current_rev="$(jq -r --arg input "$input_name" '.nodes[$input].locked.rev // ""' flake.lock)"
      latest_rev="$(git ls-remote "$upstream_url" "$upstream_ref" | awk '{ print $1 }')"

      if [ -z "$latest_rev" ]; then
        echo "could not resolve latest upstream revision"
        notify "Failed: could not resolve upstream revision."
        exit 1
      fi

      echo "current: $current_rev"
      echo "latest:  $latest_rev"

      if [ "$current_rev" = "$latest_rev" ]; then
        echo "already up to date"
        exit 0
      fi

      lock_backup="$(mktemp)"
      cp flake.lock "$lock_backup"

      restore_lock() {
        cp "$lock_backup" flake.lock
        rm -f "$lock_backup"
      }

      if ! nix flake update "$input_name"; then
        echo "flake update failed"
        restore_lock
        notify "Failed while updating flake.lock."
        exit 1
      fi

      updated_rev="$(jq -r --arg input "$input_name" '.nodes[$input].locked.rev // ""' flake.lock)"
      if [ "$updated_rev" != "$latest_rev" ]; then
        echo "updated lock resolved $updated_rev, expected $latest_rev"
        restore_lock
        notify "Failed: flake.lock resolved an unexpected revision."
        exit 1
      fi

      if ! nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link; then
        echo "build failed; restoring lock"
        restore_lock
        notify "Failed: updated Codex package did not build."
        exit 1
      fi

      rm -f "$lock_backup"
      git add flake.lock
      if git -c commit.gpgsign=false commit -m "Update Codex Desktop Linux" >/dev/null; then
        echo "committed Codex update to $updated_rev"
        notify "Updated and committed. Run rebuild to apply."
      else
        echo "git commit failed"
        notify "Updated and built, but git commit failed."
        exit 1
      fi
    '';
  };
in
{
  home.packages = [
    codexDesktop
    codexDesktopUpdate
  ];

  home.sessionVariables.CODEX_CLI_PATH = "${codexCli}/bin/codex";

  systemd.user.services.codex-desktop-update = {
    Unit = {
      Description = "Update the Codex Desktop Linux flake input";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe codexDesktopUpdate}";
    };
  };

  systemd.user.timers.codex-desktop-update = {
    Unit.Description = "Update Codex Desktop Linux on a schedule";

    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "45m";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
