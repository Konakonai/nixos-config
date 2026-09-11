# Concatenate Mihomo fragments, validate, then publish atomically.
# On validation failure the previous destination is left untouched.
# Validation must not block a rebuild on GitHub geodata downloads or the
# live TUN/listener: use a scratch -d dir, seed local geodata if present,
# and time out. If a usable file already exists, keep it and exit 0 so
# systemd does not take down the running daemon.
set -euo pipefail

before=${1:?}
proxies=${2:?}
after=${3:?}
dest=${4:?}
validate_timeout=${MIHOMO_VALIDATE_TIMEOUT:-15}

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
scratch=$(mktemp -d "$dir/validate.XXXXXX")
marker="$dir/last-validation"
cleanup() {
  rm -f "$tmp"
  rm -rf "$scratch"
}
trap cleanup EXIT

record_validation() {
  result=$1
  kept=$2
  {
    printf 'time=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'result=%s\n' "$result"
    printf 'kept_previous=%s\n' "$kept"
  } > "$marker"
  chmod 600 "$marker"
}

cat "$before" "$proxies" "$after" > "$tmp"
chmod 600 "$tmp"

# Root can read the live DynamicUser state dir; lilya leftover files in
# ~/.config/mihomo are not used (the service does not run as the user).
if [ -r /var/lib/mihomo ]; then
  find /var/lib/mihomo -maxdepth 1 \( \
    -name 'geoip*' -o -name 'geosite*' -o -name '*.mmdb' -o -name '*.metadb' \
  \) -exec cp -a {} "$scratch/" \; || true
fi

# Discard validator output: it may echo credentials from the assembled file.
if ! timeout --signal=TERM --kill-after=2s "$validate_timeout" \
  mihomo -t -f "$tmp" -d "$scratch" >/dev/null 2>&1
then
  echo "Generated Mihomo configuration failed validation; keeping the last usable file." >&2
  if [ -s "$dest" ]; then
    record_validation failed yes
    exit 0
  fi
  record_validation failed no
  exit 1
fi

mv "$tmp" "$dest"
record_validation ok no
trap - EXIT
rm -rf "$scratch"
