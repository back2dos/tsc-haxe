#!/bin/sh
# Builds the Go reference dumpers against the pinned upstream without changing it:
# each tools/dump/<name>/main.go is overlaid as upstream/tsc/cmd/tsdump-<name>/main.go.
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$root/.ref"
for dir in "$root"/tools/dump/*/; do
	name=$(basename "$dir")
	overlay="$root/.ref/overlay-$name.json"
	printf '{"Replace":{"%s":"%s"}}' "$root/upstream/tsc/cmd/tsdump-$name/main.go" "$dir/main.go" > "$overlay"
	(cd "$root/upstream/tsc" && GOTOOLCHAIN=go1.26.9 go build -overlay "$overlay" -o "$root/.ref/tsdump-$name" "./cmd/tsdump-$name")
	echo "built .ref/tsdump-$name"
done
