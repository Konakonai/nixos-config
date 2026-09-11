# Invoked before Qoder starts; bundled plugins have a versioned completion stamp.
set -euo pipefail
source_dir=$1
cache=$2
mkdir -p "$(dirname "$cache")"
exec 9>"$cache.lock"
flock 9
if [ -f "$cache/.nix-source" ] && [ "$(cat "$cache/.nix-source")" = "$source_dir" ]; then
  exit 0
fi

staging=$(mktemp -d "$cache.staging.XXXXXX")
backup=""
cleanup() {
  result=$?
  if [ -n "$backup" ] && [ ! -e "$cache" ]; then
    mv "$backup" "$cache"
  fi
  rm -rf -- "$staging"
  exit "$result"
}
trap cleanup EXIT
cp -R "$source_dir/." "$staging/"
chmod -R u+w "$staging"
printf '%s\n' "$source_dir" > "$staging/.nix-source"
if [ -e "$cache" ]; then
  # Preserve the previous cache, including any local changes, for recovery.
  backup=$(mktemp -d "$cache.previous.XXXXXX")
  rmdir "$backup"
  mv "$cache" "$backup"
fi
mv "$staging" "$cache"
