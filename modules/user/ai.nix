{
  hostProfile,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs.lilya)
    antigravity
    codex-desktop
    computer-use-linux
    gemini-api
    google-colab-cli
    opencli
    wlroots-bridge
    ;

  # Display 2 for claude-desktop-extra's "Computer Use on a background
  # display": Claude clicks and types there through the bundled bridge without
  # touching the user's cursor or focus. Headless, so it needs no window on the
  # real desktop; pixman, so it never wakes the dGPU (which must stay asleep on
  # battery). Pick its wayland-N socket on the setup page (Settings -> Extra ->
  # Community Features); sway takes the lowest free number, so normally wayland-2.
  cuState = ''"$XDG_RUNTIME_DIR/claude-cu"'';
  claude-cu-desk = pkgs.writeShellApplication {
    name = "claude-cu-desk";
    runtimeInputs = [ pkgs.sway ];
    text = ''
      state=${cuState}
      mkdir -p "$state"
      if [ "''${1-}" = stop ]; then
        [ -r "$state/pid" ] && kill "$(cat "$state/pid")"
        exit 0
      fi

      config="$state/sway.conf"
      {
        echo "default_border none"
        echo "focus_follows_mouse no"
        echo "output HEADLESS-1 mode 1920x1200 scale 1.25 bg #303030 solid_color"
        # shellcheck disable=SC2016
        printf '%s\n' "exec sh -c 'printf \"WAYLAND_DISPLAY=%s\\nDISPLAY=%s\\n\" \"\$WAYLAND_DISPLAY\" \"\''${DISPLAY-}\" > $state/env.tmp && mv $state/env.tmp $state/env'"
      } > "$config"

      trap 'rm -f "$state/env" "$state/pid"' EXIT
      env -u WAYLAND_DISPLAY -u DISPLAY -u NIRI_SOCKET \
        WLR_BACKENDS=headless \
        WLR_RENDERER=pixman \
        WLR_LIBINPUT_NO_DEVICES=1 \
        sway -c "$config" &
      echo $! > "$state/pid"
      wait
    '';
  };

  # Start a program on display 2 from a shell (Claude's own open_application
  # already targets it).
  claude-cu-run = pkgs.writeShellApplication {
    name = "claude-cu-run";
    text = ''
      env=${cuState}/env
      if [ ! -r "$env" ]; then
        echo "claude-cu-run: claude-cu-desk is not running" >&2
        exit 1
      fi
      set -a
      # shellcheck disable=SC1090
      . "$env"
      set +a
      exec "$@"
    '';
  };

  claude-desktop =
    (inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop.override {
      # Upstream v2.2553.x is built against Electron 44; nixpkgs' default
      # `electron` alias lags behind, so pin the major the bundle expects.
      electron = pkgs.electron_44;
    }).overrideAttrs
      (oldAttrs: {
        postFixup = (oldAttrs.postFixup or "") + ''
          wrapProgram $out/bin/claude-desktop \
            --set CHROME_DEVEL_SANDBOX "$out/lib/claude-desktop/chrome-sandbox"

          # The bundled node-pty binding links libstdc++, but Electron itself
          # ships a static libc++, so nothing in the process provides it and
          # the pty-host worker dies with a misleading "Cannot find module
          # pty.node" (the built-in terminal shows "Failed to spawn shell").
          # Give the binding its own RPATH instead of leaking LD_LIBRARY_PATH
          # into every shell and MCP server the app spawns.
          pty=$out/lib/claude-desktop/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node
          chmod u+w "$pty"
          patchelf --add-rpath ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]} "$pty"
        '';
      });

  # Isolated headless Sway session helper so agents can drive GUI apps via
  # wlroots-bridge without stealing the host Niri pointer or window focus.
  swaySandbox = pkgs.writeShellApplication {
    name = "sway-sandbox";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.sway
      pkgs.util-linux
      wlroots-bridge
    ];
    text = builtins.readFile ../../scripts/sway-sandbox.sh;
  };

  wlrootsBridgeSkill = ''
    ---
    name: wlroots-bridge
    description: >-
      Control a wlroots Wayland compositor (such as an isolated headless Sway
      sandbox via sway-sandbox, or Sway/Hyprland/Niri) using the pure-Rust
      wlroots-bridge CLI over Wayland virtual-pointer, virtual-keyboard,
      screencopy, and foreign-toplevel protocols.
    ---

    # wlroots-bridge & sway-sandbox

    Use `sway-sandbox` + `wlroots-bridge` when you need an **isolated Wayland
    desktop sandbox** that does not hijack the user's host Niri cursor or window
    focus, or when you want stateless Wayland-native screenshot/input control.

    ## Isolated Headless Sway Workflow

    1. Start the sandbox (defaults to `1920x1080`):
       ```bash
       sway-sandbox start
       # or: sway-sandbox start --resolution 1280x800
       ```
    2. Launch a GUI app inside the sandbox in the background:
       ```bash
       sway-sandbox run <app> >/tmp/sandbox-app.log 2>&1 &
       ```
    3. Verify compositor protocols and capture screenshots / control input:
       ```bash
       sway-sandbox bridge doctor
       sway-sandbox bridge screens
       sway-sandbox bridge windows
       sway-sandbox bridge screenshot | jq -r .base64 | base64 -d > /tmp/sandbox.jpg
       sway-sandbox bridge pointer-click --x 640 --y 400 --button left --count 1
       sway-sandbox bridge pointer-scroll --x 640 --y 400 --dy 5
       sway-sandbox bridge type --text "hello"
       sway-sandbox bridge key-sequence --keys "ctrl+l"
       ```
    4. Stop the sandbox when finished:
       ```bash
       sway-sandbox stop
       ```

    ## Notes

    - `wlroots-bridge` outputs one JSON object/array on stdout per command.
    - `screenshot` and `zoom` return JSON with a `base64` JPEG field; decode it to a file and inspect with `read_file` instead of printing raw base64.
    - Check `wlroots-bridge --help` or `wlroots-bridge <subcommand> --help` for exact flags.
  '';

  cuPackageDir = "${computer-use-linux}/share/computer-use-linux";
  cuSkillsDir = "${cuPackageDir}/skills/computer-use-linux";

  frontendDesignSkill = "${inputs.demolab}/skills/gemini-frontend-design";

  opencliSkillsDir = "${opencli}/share/opencli/skills";
  opencliSkillNames = [
    "opencli-adapter-author"
    "opencli-autofix"
    "opencli-browser"
    "opencli-usage"
  ];
in
{
  # System-side support for Codex Desktop.
  programs.nix-ld.enable = true;
  # Codex runs with sandbox_mode = "danger-full-access", so its cached generic
  # Linux runtimes bypass the bwrap adapter that codex-desktop-linux uses to
  # inject libraries and load through the system nix-ld instead. The primary
  # runtime's headless LibreOffice needs these on top of the nix-ld defaults.
  programs.nix-ld.libraries = with pkgs; [
    fontconfig
    freetype
    lcms2
    nspr
    nss
  ];

  # Codex Linux Computer Use needs a keyboard backend. Niri exports no
  # org.gnome.Mutter.RemoteDesktop, so the RemoteDesktop portal always refuses
  # CreateSession and /dev/uinput alone only gives the backend a pointer.
  # The module exports YDOTOOL_SOCKET, which the backend reads.
  programs.ydotool.enable = true;
  users.users.${hostProfile.user.userName}.extraGroups = [ "ydotool" ];

  home-manager.users.${hostProfile.user.userName} = {
    home.packages = [
      antigravity
      claude-cu-desk
      claude-cu-run
      claude-desktop
      codex-desktop
      computer-use-linux
      gemini-api
      google-colab-cli
      opencli
      swaySandbox
      wlroots-bridge
      inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    xdg.desktopEntries.antigravity = {
      name = "Antigravity";
      exec = "${lib.getExe antigravity} %F";
      icon = "antigravity";
      type = "Application";
      categories = [ "Utility" ];
      terminal = false;
      mimeType = [ "x-scheme-handler/antigravity" ];
    };

    home.file = {
      # Claude Code auto-loads a plugin from any folder under ~/.claude/skills that
      # holds a .claude-plugin/plugin.json, in the CLI and in the desktop app's Code
      # tab alike. The folder is linked whole, not file by file (`recursive`): the
      # engine resolves each hook module's real path and refuses one that lands
      # outside the plugin folder, which per-file store links always do.
      ".claude/skills/token-band".source = "${inputs.lilya-tools}/claude-token-band";

      # Frontend design skill from google-gemini/demolab.
      ".claude/skills/gemini-frontend-design".source = frontendDesignSkill;
      ".gemini/config/skills/gemini-frontend-design" = {
        source = frontendDesignSkill;
        recursive = true;
      };

      # Colab operator skill
      ".gemini/config/skills/colab-operator" = {
        source = "${google-colab-cli}/share/google-colab-cli/skills/colab-operator";
        recursive = true;
      };
      ".pi/agent/skills/colab-operator".source =
        "${google-colab-cli}/share/google-colab-cli/skills/colab-operator";

      # Pi auto-discovers global packages from ~/.pi/agent/extensions/*/package.json
      # and skills from ~/.pi/agent/skills/*/, keeping settings.json mutable.
      ".pi/agent/extensions/computer-use-linux".source = cuPackageDir;
      ".pi/agent/skills/computer-use-linux".source = cuSkillsDir;
      ".pi/agent/skills/wlroots-bridge/SKILL.md".text = wlrootsBridgeSkill;

      # Antigravity auto-discovers plugins from ~/.gemini/config/plugins/<name>/.
      ".gemini/config/plugins/computer-use-linux/plugin.json".text = builtins.toJSON {
        name = "computer-use-linux";
        displayName = "Computer Use Linux";
        inherit (computer-use-linux) version;
        description = "Native Linux desktop control over MCP: AT-SPI accessibility trees, screenshots, window targeting, and Wayland/X11 input.";
        homepage = "https://github.com/agent-sh/computer-use-linux";
        license = "MIT";
      };
      ".gemini/config/plugins/computer-use-linux/mcp_config.json".text = builtins.toJSON {
        mcpServers.computer-use-linux = {
          command = "${computer-use-linux}/bin/computer-use-linux";
          args = [ "mcp" ];
        };
      };
      ".gemini/config/plugins/computer-use-linux/skills/computer-use-linux" = {
        source = cuSkillsDir;
        recursive = true;
      };
      ".gemini/config/skills/wlroots-bridge/SKILL.md".text = wlrootsBridgeSkill;

      ".gemini/config/plugins/opencli/plugin.json".text = builtins.toJSON {
        name = "opencli";
        displayName = "OpenCLI";
        inherit (opencli) version;
        description = "Drive logged-in Chromium/Brave profiles and deterministic site adapters with OpenCLI.";
        homepage = "https://opencli.info";
        repository = "https://github.com/jackwener/OpenCLI";
      };
      ".gemini/config/plugins/opencli/skills" = {
        source = opencliSkillsDir;
        recursive = true;
      };
    }
    // builtins.listToAttrs (
      map (name: {
        name = ".pi/agent/skills/${name}";
        value.source = "${opencliSkillsDir}/${name}";
      }) opencliSkillNames
    );
  };
}
