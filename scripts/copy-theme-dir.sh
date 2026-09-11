# Copy a Nix-provided theme/icon directory into a writable user path.
# Never delete the destination before the replacement is ready.
set -euo pipefail

src=${1:?}
dst=${2:?}

if [ -L "$dst" ]; then
  exit 0
fi

if [ ! -d "$src" ]; then
  exit 0
fi

marker="$dst/.nix-source"
if [ -f "$marker" ] && [ "$(<"$marker")" = "$src" ]; then
  exit 0
fi

parent=$(dirname "$dst")
mkdir -p "$parent"

staging=$(mktemp -d "$dst.staging.XXXXXX")
backup=""
cleanup() {
  result=$?
  if [ -n "$backup" ] && [ ! -e "$dst" ] && [ -e "$backup" ]; then
    mv "$backup" "$dst"
  fi
  rm -rf -- "$staging"
  exit "$result"
}
trap cleanup EXIT

cp -aL "$src" "$staging/content"
chmod -R u+w "$staging/content"
printf '%s\n' "$src" > "$staging/content/.nix-source"

if [ -e "$dst" ]; then
  backup=$(mktemp -d "$dst.previous.XXXXXX")
  rmdir "$backup"
  mv "$dst" "$backup"
fi

mv "$staging/content" "$dst"
if [ -n "$backup" ]; then
  rm -rf -- "$backup"
  backup=""
fi
