# Included by pkgs/codex-update.nix, which supplies repo and runtime tools.
set -euo pipefail

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/codex-update"
mkdir -p "$log_dir"
exec 9>"$log_dir/update.lock"
flock -n 9 || exit 0
exec >>"$log_dir/update.log" 2>&1

notify() {
  if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    notify-send "Codex update" "$1" >/dev/null 2>&1 || true
  fi
}

candidate=""
scratch=""
cleanup() {
  result=$?
  trap - EXIT
  if [ -n "$candidate" ]; then
    git -C "$repo" worktree remove --force "$candidate" || true
  fi
  if [ -n "$scratch" ]; then
    rm -rf -- "$scratch"
  fi
  if [ "$result" -ne 0 ]; then
    notify "Update failed. See $log_dir/update.log."
  fi
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

echo "== $(date --iso-8601=seconds) =="
cd "$repo"
branch=$(git symbolic-ref --quiet HEAD) || {
  echo "detached HEAD; skipping"
  exit 0
}
if [ -n "$(git status --porcelain)" ]; then
  echo "working tree is not clean; skipping"
  exit 0
fi
base=$(git rev-parse HEAD)

input_name=codex-desktop-linux
cli_package=pkgs/codex.nix
cli_asset=codex-package-x86_64-unknown-linux-musl.tar.zst
locked_revision() {
  jq -er --arg input "$input_name" '.nodes[.nodes.root.inputs[$input]].locked.rev' "$1"
}
current_desktop_rev=$(locked_revision flake.lock)
latest_desktop_rev=$(git ls-remote https://github.com/ilysenko/codex-desktop-linux.git refs/heads/main | awk '{print $1}')
[[ "$latest_desktop_rev" =~ ^[0-9a-f]{40}$ ]] || {
  echo "invalid desktop revision"
  exit 1
}

cli_release=$(gh api repos/openai/codex/releases/latest)
latest_cli_tag=$(jq -er .tag_name <<<"$cli_release")
[[ "$latest_cli_tag" =~ ^rust-v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || {
  echo "unexpected CLI tag: $latest_cli_tag"
  exit 1
}
latest_cli_version=${BASH_REMATCH[1]}
current_cli_version=$(sed -nE 's/^[[:space:]]*version = "([^"]+)";/\1/p' "$cli_package")
[[ "$current_cli_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
if [ "$(printf '%s\n' "$current_cli_version" "$latest_cli_version" | sort -V | tail -n 1)" != "$latest_cli_version" ]; then
  echo "refusing to downgrade CLI from $current_cli_version to $latest_cli_version"
  exit 1
fi

desktop_changed=false
cli_changed=false
[ "$current_desktop_rev" = "$latest_desktop_rev" ] || desktop_changed=true
[ "$current_cli_version" = "$latest_cli_version" ] || cli_changed=true
if ! $desktop_changed && ! $cli_changed; then
  echo "already up to date"
  exit 0
fi

scratch=$(mktemp -d)
candidate="$scratch/worktree"
git worktree add --detach "$candidate" "$base"
cd "$candidate"

if $desktop_changed; then
  # Pin the revision inspected above, even if upstream moves during the build.
  nix flake update "$input_name" --override-input "$input_name" "github:ilysenko/codex-desktop-linux/$latest_desktop_rev"
  [ "$(locked_revision flake.lock)" = "$latest_desktop_rev" ]
  # Retain the declared tracking URL; only the locked source should be pinned.
  original=$(git show "$base:flake.lock" | jq -c --arg input "$input_name" '.nodes[.nodes.root.inputs[$input]].original')
  jq --arg input "$input_name" --argjson original "$original" \
    '.nodes[.nodes.root.inputs[$input]].original = $original' flake.lock > "$scratch/flake.lock"
  mv "$scratch/flake.lock" flake.lock
fi

if $cli_changed; then
  cli_asset_url=$(jq -er --arg asset "$cli_asset" '.assets[] | select(.name == $asset) | .browser_download_url' <<<"$cli_release")
  latest_cli_digest="sha256:$(curl -fL --retry 3 --connect-timeout 15 --max-time 600 "$cli_asset_url" | sha256sum | awk '{print $1}')"
  [[ "$latest_cli_digest" =~ ^sha256:[0-9a-f]{64}$ ]]
  sed -i -E \
    -e "s/^[[:space:]]*version = \"[^\"]+\";/  version = \"$latest_cli_version\";/" \
    -e "s/^[[:space:]]*sha256 = \"sha256:[0-9a-f]{64}\";/    sha256 = \"$latest_cli_digest\";/" \
    "$cli_package"
  [ "$(grep -cF "version = \"$latest_cli_version\";" "$cli_package")" -eq 1 ]
  [ "$(grep -cF "sha256 = \"$latest_cli_digest\";" "$cli_package")" -eq 1 ]
fi

nix flake check --no-build
# Desktop embeds the CLI path, so validate both together, without building the OS.
nix build .#nixosConfigurations.nixos.pkgs.lilya.codex-desktop --no-link
cli_out=$(nix build .#nixosConfigurations.nixos.pkgs.lilya.codex --no-link --print-out-paths)
[ "$("$cli_out/bin/codex" --version)" = "codex-cli $latest_cli_version" ]
[ -x "$cli_out/bin/codex-code-mode-host" ]
[ -d "$cli_out/codex-resources" ]
git diff --check
git add flake.lock "$cli_package"
git -c commit.gpgsign=false commit -m "Update Codex Desktop and CLI"
updated=$(git rev-parse HEAD)

cd "$repo"
if [ "$(git symbolic-ref --quiet HEAD || true)" != "$branch" ] ||
   [ "$(git rev-parse HEAD)" != "$base" ] ||
   [ -n "$(git status --porcelain)" ]; then
  echo "checkout changed during build; leaving the user's checkout untouched"
  notify "Build passed; checkout changed, so integration was skipped. The next run will retry."
  exit 0
fi
git merge --ff-only "$updated"
echo "committed Codex update: $updated"
notify "Updated and committed. Run rebuild to apply."
