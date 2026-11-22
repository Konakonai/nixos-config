set -euo pipefail

repo_dir="${1:?usage: update-pins.sh <nixos-config-path>}"
cd "$repo_dir"

nix flake update
nix-update --flake wiiu-downloader
nix-update --flake genryumin
nix-update --flake gemini-api
nix-update --flake google-colab-cli
nix-update --flake opencli

# Antigravity embeds a build ID in the URL, which nix-update cannot derive
# from the version: rewrite it first, then let nix-update set the version
# and refetch the hash.
bump_with_id() { # <attr> <id binding> <version> <id>
  # Empty when the endpoint changed shape; command substitutions in
  # arguments do not trip errexit, so check here.
  if [ -z "$3" ] || [ -z "$4" ]; then
    echo "$1: unexpected updater response" >&2
    return 1
  fi
  if [ "$3" = "$(nix eval --raw ".#$1.version")" ]; then
    echo "$1: $3 is current"
    return
  fi
  sed -i -E "s|^(  $2 = \")[^\"]*\"|\1$4\"|" "pkgs/$1.nix"
  nix-update --flake "$1" --version "$3"
}

release=$(
  curl -fsSL --connect-timeout 10 --max-time 30 \
    https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases |
    jq -e 'max_by(.version | split(".") | map(tonumber))'
)
bump_with_id antigravity buildId \
  "$(jq -er .version <<<"$release")" \
  "$(jq -er .execution_id <<<"$release")"

flatpak update --user --noninteractive
echo
echo "Bump by hand: jetbrains-maple-mono"
git status --short
