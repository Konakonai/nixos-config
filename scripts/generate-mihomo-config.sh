# Concatenate Mihomo fragments, validate, then publish atomically.
# On validation failure the previous destination is left untouched.
set -euo pipefail

before=${1:?}
proxies=${2:?}
after=${3:?}
dest=${4:?}

if [ ! -r "$proxies" ]; then
  echo "Missing decrypted Mihomo proxy secret: $proxies" >&2
  exit 1
fi

if ! command -v mihomo >/dev/null; then
  echo "mihomo is required to validate the generated configuration" >&2
  exit 1
fi

dir=$(dirname "$dest")
install -d -m 700 "$dir"

tmp=$(mktemp "$dir/$(basename "$dest").tmp.XXXXXX")
cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

cat "$before" "$proxies" "$after" > "$tmp"
chmod 600 "$tmp"

# Discard validator output: it may echo credentials from the assembled file.
if ! mihomo -t -f "$tmp" >/dev/null 2>&1; then
  echo "Generated Mihomo configuration failed validation; keeping the last usable file." >&2
  exit 1
fi

mv "$tmp" "$dest"
trap - EXIT
