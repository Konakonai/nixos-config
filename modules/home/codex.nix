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
    nixpkgs = inputs.nixpkgs;
    flake-utils = inputs.flake-utils;
  };

  codexDesktopBase =
    codexDesktopFlake.packages.${system}.codex-desktop.override {
      linuxFeatureIds = [
        "computer-use-linux"
        "frameless-titlebar"
      ];
    };

  # Codex's bundled document runtime is an unpatched Linux binary. Keep its
  # non-Electron libraries visible when it launches LibreOffice on NixOS.
  documentRuntimeLibs = with pkgs; [
    curl
    fontconfig
    freetype
    lcms2
    pixman
  ];

  codexDesktop = pkgs.symlinkJoin {
    name = "${codexDesktopBase.name}-codex-cli-path";
    paths = [ codexDesktopBase ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      if [ -e "$out/bin/codex-desktop" ]; then
        rm -f "$out/bin/codex-desktop"
        makeWrapper "${codexDesktopBase}/bin/codex-desktop" "$out/bin/codex-desktop" \
          --set-default CODEX_CLI_PATH "${codexCli}/bin/codex" \
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath documentRuntimeLibs}"
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

  codexUpdate = pkgs.writeShellApplication {
    name = "codex-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gh
      pkgs.gnugrep
      pkgs.gnused
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
      cli_package=pkgs/codex.nix
      cli_repo=openai/codex
      cli_asset=codex-x86_64-unknown-linux-musl-bundle.tar.zst
      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/codex-update"
      log_file="$log_dir/update.log"

      mkdir -p "$log_dir"
      exec >>"$log_file" 2>&1

      notify() {
        if [ -n "''${DISPLAY:-}" ] || [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          notify-send "Codex update" "$1" >/dev/null 2>&1 || true
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

      current_desktop_rev="$(jq -r --arg input "$input_name" '.nodes[$input].locked.rev // ""' flake.lock)"
      latest_desktop_rev="$(git ls-remote "$upstream_url" "$upstream_ref" | awk '{ print $1 }')"

      if ! [[ "$latest_desktop_rev" =~ ^[0-9a-f]{40}$ ]]; then
        echo "could not resolve a valid desktop upstream revision"
        notify "Failed: could not resolve the desktop revision."
        exit 1
      fi

      cli_release="$(gh api "repos/$cli_repo/releases/latest")"
      latest_cli_tag="$(jq -r '.tag_name // ""' <<<"$cli_release")"
      if ! [[ "$latest_cli_tag" =~ ^rust-v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        echo "unexpected Codex CLI release tag: $latest_cli_tag"
        notify "Failed: the CLI release tag was unexpected."
        exit 1
      fi
      latest_cli_version="''${BASH_REMATCH[1]}"
      latest_cli_digest="$(
        jq -r --arg asset "$cli_asset" \
          '.assets[] | select(.name == $asset) | .digest // ""' \
          <<<"$cli_release"
      )"
      if ! [[ "$latest_cli_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        echo "missing or invalid digest for $cli_asset"
        notify "Failed: the CLI bundle digest was unavailable."
        exit 1
      fi

      current_cli_version="$(
        sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$cli_package"
      )"
      current_cli_digest="$(
        sed -nE 's/^[[:space:]]*sha256 = "(sha256:[0-9a-f]{64})";/\1/p' "$cli_package"
      )"

      if ! [[ "$current_cli_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        ! [[ "$current_cli_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
        echo "could not parse the current Codex CLI pin"
        notify "Failed: the current CLI pin was not recognized."
        exit 1
      fi
      if [ "$current_cli_version" != "$latest_cli_version" ] &&
        [ "$(
          printf '%s\n' "$current_cli_version" "$latest_cli_version" |
            sort -V |
            tail -n 1
        )" != "$latest_cli_version" ]; then
        echo "refusing to downgrade CLI from $current_cli_version to $latest_cli_version"
        notify "Failed: the latest release would downgrade the CLI."
        exit 1
      fi

      desktop_changed=false
      cli_changed=false
      if [ "$current_desktop_rev" != "$latest_desktop_rev" ]; then
        desktop_changed=true
      fi
      if [ "$current_cli_version" != "$latest_cli_version" ] ||
        [ "$current_cli_digest" != "$latest_cli_digest" ]; then
        cli_changed=true
      fi

      echo "desktop current: $current_desktop_rev"
      echo "desktop latest:  $latest_desktop_rev"
      echo "CLI current:     $current_cli_version"
      echo "CLI latest:      $latest_cli_version"

      if ! $desktop_changed && ! $cli_changed; then
        echo "already up to date"
        exit 0
      fi

      backup_dir="$(mktemp -d)"
      cp flake.lock "$backup_dir/flake.lock"
      cp "$cli_package" "$backup_dir/codex.nix"

      restore_sources() {
        trap - EXIT INT TERM
        cp "$backup_dir/flake.lock" flake.lock
        cp "$backup_dir/codex.nix" "$cli_package"
        rm -rf "$backup_dir"
      }
      trap restore_sources EXIT INT TERM

      if $desktop_changed; then
        if ! nix flake update "$input_name"; then
          echo "flake update failed"
          restore_sources
          notify "Failed while updating flake.lock."
          exit 1
        fi

        updated_desktop_rev="$(
          jq -r --arg input "$input_name" '.nodes[$input].locked.rev // ""' flake.lock
        )"
        if [ "$updated_desktop_rev" != "$latest_desktop_rev" ]; then
          echo "updated lock resolved $updated_desktop_rev, expected $latest_desktop_rev"
          restore_sources
          notify "Failed: flake.lock resolved an unexpected revision."
          exit 1
        fi
      fi

      if $cli_changed; then
        sed -i -E \
          "s/^[[:space:]]*version = \"[^\"]+\";/  version = \"$latest_cli_version\";/" \
          "$cli_package"
        sed -i -E \
          "s/^[[:space:]]*sha256 = \"sha256:[0-9a-f]{64}\";/    sha256 = \"$latest_cli_digest\";/" \
          "$cli_package"

        if [ "$(grep -cF "version = \"$latest_cli_version\";" "$cli_package")" -ne 1 ] ||
          [ "$(grep -cF "sha256 = \"$latest_cli_digest\";" "$cli_package")" -ne 1 ]; then
          echo "the updated CLI pin was not written exactly once"
          restore_sources
          notify "Failed while editing the CLI package pin."
          exit 1
        fi

        if ! cli_out="$(
          nix build \
            .#nixosConfigurations.nixos.pkgs.lilya.codex \
            --no-link \
            --print-out-paths
        )"; then
          echo "CLI package build failed"
          restore_sources
          notify "Failed: the updated CLI package did not build."
          exit 1
        fi

        if [ "$("$cli_out/bin/codex" --version)" != "codex-cli $latest_cli_version" ] ||
          [ ! -x "$cli_out/bin/codex-code-mode-host" ] ||
          [ ! -d "$cli_out/codex-resources" ]; then
          echo "the built CLI bundle is incomplete or reports the wrong version"
          restore_sources
          notify "Failed: the built CLI bundle was incomplete."
          exit 1
        fi
      fi

      if ! nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link; then
        echo "toplevel build failed; restoring sources"
        restore_sources
        notify "Failed: updated Codex package did not build."
        exit 1
      fi

      rm -rf "$backup_dir"
      trap - EXIT INT TERM
      git add flake.lock "$cli_package"
      if $desktop_changed && $cli_changed; then
        commit_message="Update Codex Desktop and CLI"
      elif $desktop_changed; then
        commit_message="Update Codex Desktop Linux"
      else
        commit_message="Update Codex CLI to $latest_cli_version"
      fi

      if git -c commit.gpgsign=false commit -m "$commit_message" >/dev/null; then
        echo "committed Codex update"
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
    codexUpdate
  ];

  home.sessionVariables.CODEX_CLI_PATH = "${codexCli}/bin/codex";

  systemd.user.services.codex-update = {
    Unit = {
      Description = "Update Codex Desktop Linux and Codex CLI";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe codexUpdate}";
    };
  };

  systemd.user.timers.codex-update = {
    Unit.Description = "Update Codex Desktop Linux and Codex CLI on a schedule";

    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "45m";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
