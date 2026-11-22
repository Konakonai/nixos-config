set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/sway-sandbox"
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
    export WLR_RENDERER="${SWAY_SANDBOX_RENDERER:-pixman}"
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
    SWAYSOCK="${SANDBOX_SWAYSOCK:-}" swaymsg exit >/dev/null 2>&1 || true
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

subcmd="${1:-}"
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
