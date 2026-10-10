#!/bin/sh
# Builds the skeleton generator against the pinned upstream (overlay, upstream/ is not modified)
# and runs it: tools/gen/skeleton/run.sh internal/checker [flags...]
set -e
root=$(cd "$(dirname "$0")/../../.." && pwd)
src="$root/tools/gen/skeleton"
mkdir -p "$root/bin/skeleton"
overlay="$root/bin/skeleton/overlay.json"
printf '{"Replace":{' > "$overlay"
sep=""
for f in "$src"/*.go; do
	printf '%s"%s":"%s"' "$sep" "$root/upstream/tsc/cmd/tsgen-skeleton/$(basename "$f")" "$f" >> "$overlay"
	sep=","
done
printf '}}' >> "$overlay"
(cd "$root/upstream/tsc" && GOTOOLCHAIN=go1.26.9 go build -overlay "$overlay" -o "$root/bin/skeleton/tsgen-skeleton" ./cmd/tsgen-skeleton)
cd "$root"
pkg="$1"
shift
exec "$root/bin/skeleton/tsgen-skeleton" -root "$root" -pkg "$pkg" "$@"
