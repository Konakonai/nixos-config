# Concatenate Mihomo fragments and publish atomically.
# Do not run mihomo -t here: cold boot has no geodata/network, and a failed
# check would take down the daemon via Requires=mihomo-config.service.
set -euo pipefail

before=${1:?}
proxies=${2:?}
after=${3:?}
dest=${4:?}

if [ ! -r "$proxies" ]; then
  echo "Missing decrypted Mihomo proxy secret: $proxies" >&2
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
mv "$tmp" "$dest"
trap - EXIT
