{ pkgs, ... }:

let
  pkg = pkgs.lilya.computer-use-linux;
  packageDir = "${pkg}/share/computer-use-linux";
  skillsDir = "${packageDir}/skills/computer-use-linux";

  wlrootsBridge = pkgs.lilya.wlroots-bridge;

  # Isolated headless Sway session helper so agents can drive GUI apps via
  # wlroots-bridge without stealing the host Niri pointer or window focus.
  swaySandbox = pkgs.writeShellApplication {
    name = "sway-sandbox";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.sway
      pkgs.util-linux
      wlrootsBridge
    ];
    text = ''
      set -euo pipefail

      STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/sway-sandbox"
      ENV_FILE="$STATE_DIR/env"
      PID_FILE="$STATE_DIR/sway.pid"
      LOG_FILE="$STATE_DIR/sway.log"
      CONF_FILE="$STATE_DIR/sway.conf"

      usage() {
        cat <<'EOF'
      Usage: sway-sandbox <command> [args...]

      Commands:
        start [--resolution WxH]   Start an isolated headless Sway compositor (default: 1920x1080)
        stop                       Stop the sandbox Sway compositor and clean up state
        status                     Show sandbox status and socket paths
        run <cmd...>               Run a GUI command inside the sandbox Sway session
        bridge <args...>           Run wlroots-bridge targeted at the sandbox Sway session
      EOF
      }

      is_running() {
        [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
      }

      load_env() {
        if ! is_running || [ ! -f "$ENV_FILE" ]; then
          echo "sway-sandbox is not running (run: sway-sandbox start)" >&2
          exit 1
        fi
        # shellcheck disable=SC1090
        source "$ENV_FILE"
      }

      cmd_start() {
        local resolution="1920x1080"
        while [ $# -gt 0 ]; do
          case "$1" in
            --resolution)
              resolution="$2"
              shift 2
              ;;
            *)
              echo "Unknown option: $1" >&2
              usage >&2
              exit 2
              ;;
          esac
        done

        if is_running; then
          cmd_status
          return 0
        fi

        rm -rf "$STATE_DIR"
        mkdir -p "$STATE_DIR/runtime"
        chmod 700 "$STATE_DIR" "$STATE_DIR/runtime"

        cat >"$CONF_FILE" <<EOF
      xwayland disable
      output HEADLESS-1 resolution $resolution position 0 0
      EOF

        (
          unset WAYLAND_DISPLAY
          export XDG_RUNTIME_DIR="$STATE_DIR/runtime"
          export WLR_BACKENDS=headless
          export WLR_LIBINPUT_NO_DEVICES=1
          export WLR_RENDERER="''${SWAY_SANDBOX_RENDERER:-pixman}"
          export SWAYSOCK="$STATE_DIR/runtime/sway-ipc.sock"
          exec setsid sway -c "$CONF_FILE" </dev/null
        ) >"$LOG_FILE" 2>&1 &
        local pid=$!
        echo "$pid" >"$PID_FILE"

        local sock=""
        for _ in $(seq 1 50); do
          if ! kill -0 "$pid" 2>/dev/null; then
            echo "sway failed to start; log:" >&2
            cat "$LOG_FILE" >&2 || true
            rm -rf "$STATE_DIR"
            exit 1
          fi
          sock="$(find "$STATE_DIR/runtime" -maxdepth 1 -name 'wayland-*' -type s | head -n 1 || true)"
          if [ -n "$sock" ] && [ -S "$STATE_DIR/runtime/sway-ipc.sock" ]; then
            break
          fi
          sleep 0.1
        done

        if [ -z "$sock" ]; then
          echo "Timed out waiting for sandbox Sway socket; log:" >&2
          cat "$LOG_FILE" >&2 || true
          kill "$pid" 2>/dev/null || true
          rm -rf "$STATE_DIR"
          exit 1
        fi

        local wayland_name
        wayland_name="$(basename "$sock")"
        cat >"$ENV_FILE" <<EOF
      export SANDBOX_RUNTIME_DIR="$STATE_DIR/runtime"
      export SANDBOX_WAYLAND_DISPLAY="$wayland_name"
      export SANDBOX_WAYLAND_SOCKET="$sock"
      export SANDBOX_SWAYSOCK="$STATE_DIR/runtime/sway-ipc.sock"
      EOF

        cmd_status
      }

      cmd_stop() {
        if [ -f "$ENV_FILE" ]; then
          # shellcheck disable=SC1090
          source "$ENV_FILE" || true
          SWAYSOCK="''${SANDBOX_SWAYSOCK:-}" swaymsg exit >/dev/null 2>&1 || true
        fi
        if is_running; then
          local pid
          pid="$(cat "$PID_FILE")"
          kill "$pid" 2>/dev/null || true
          for _ in $(seq 1 20); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
          done
          kill -9 "$pid" 2>/dev/null || true
        fi
        rm -rf "$STATE_DIR"
        echo "sway-sandbox stopped"
      }

      cmd_status() {
        if is_running && [ -f "$ENV_FILE" ]; then
          # shellcheck disable=SC1090
          source "$ENV_FILE"
          echo "running=true pid=$(cat "$PID_FILE") wayland_socket=$SANDBOX_WAYLAND_SOCKET swaysock=$SANDBOX_SWAYSOCK"
        else
          echo "running=false"
          return 1
        fi
      }

      cmd_run() {
        if [ $# -eq 0 ]; then
          echo "Usage: sway-sandbox run <cmd...>" >&2
          exit 2
        fi
        load_env
        XDG_RUNTIME_DIR="$SANDBOX_RUNTIME_DIR" \
        WAYLAND_DISPLAY="$SANDBOX_WAYLAND_DISPLAY" \
        SWAYSOCK="$SANDBOX_SWAYSOCK" \
        MOZ_ENABLE_WAYLAND=1 \
        QT_QPA_PLATFORM=wayland \
        ELECTRON_OZONE_PLATFORM_HINT=wayland \
          exec "$@"
      }

      cmd_bridge() {
        load_env
        XDG_RUNTIME_DIR="$SANDBOX_RUNTIME_DIR" \
        WAYLAND_DISPLAY="$SANDBOX_WAYLAND_DISPLAY" \
        SWAYSOCK="$SANDBOX_SWAYSOCK" \
          exec wlroots-bridge "$@"
      }

      subcmd="''${1:-}"
      shift || true
      case "$subcmd" in
        start) cmd_start "$@" ;;
        stop) cmd_stop ;;
        status) cmd_status ;;
        run) cmd_run "$@" ;;
        bridge) cmd_bridge "$@" ;;
        -h|--help|"") usage ;;
        *)
          echo "Unknown command: $subcmd" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
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
in
{
  home.packages = [
    pkg
    wlrootsBridge
    swaySandbox
  ];

  # Pi auto-discovers global packages from ~/.pi/agent/extensions/*/package.json
  # (with a `pi.extensions` field) and skills from ~/.pi/agent/skills/*/, so
  # both can stay declarative without touching Pi's mutable settings.json.
  home.file.".pi/agent/extensions/computer-use-linux".source = packageDir;
  home.file.".pi/agent/skills/computer-use-linux".source = skillsDir;

  # Antigravity auto-discovers plugins from ~/.gemini/config/plugins/<name>/
  # and enables them by default, keeping ~/.gemini/config/{config,mcp_config}.json
  # free for runtime UI/CLI edits.
  home.file.".gemini/config/plugins/computer-use-linux/plugin.json".text = builtins.toJSON {
    name = "computer-use-linux";
    displayName = "Computer Use Linux";
    inherit (pkg) version;
    description = "Native Linux desktop control over MCP: AT-SPI accessibility trees, screenshots, window targeting, and Wayland/X11 input.";
    homepage = "https://github.com/agent-sh/computer-use-linux";
    license = "MIT";
  };
  home.file.".gemini/config/plugins/computer-use-linux/mcp_config.json".text = builtins.toJSON {
    mcpServers.computer-use-linux = {
      command = "${pkg}/bin/computer-use-linux";
      args = [ "mcp" ];
    };
  };
  home.file.".gemini/config/plugins/computer-use-linux/skills/computer-use-linux" = {
    source = skillsDir;
    recursive = true;
  };

  home.file.".gemini/config/skills/wlroots-bridge/SKILL.md".text = wlrootsBridgeSkill;
  home.file.".pi/agent/skills/wlroots-bridge/SKILL.md".text = wlrootsBridgeSkill;
}
