#!/bin/sh
# Builds tools/gen/ast/goref/main.go against the pinned upstream without changing it (overlaid
# as upstream/tsc/cmd/astref/main.go) and writes the golden file of the AST behaviour test.
# The overlay JSON goes to a temporary directory.
set -e
root=$(cd "$(dirname "$0")/../../.." && pwd)
tmp=$(mktemp -d)
printf '{"Replace":{"%s":"%s"}}' "$root/upstream/tsc/cmd/astref/main.go" "$root/tools/gen/ast/goref/main.go" > "$tmp/overlay.json"
(cd "$root/upstream/tsc" && GOTOOLCHAIN=go1.26.9 go build -overlay "$tmp/overlay.json" -o "$tmp/astref" ./cmd/astref)
"$tmp/astref" > "$root/test/ts/ast/factory.golden.txt"
rm -rf "$tmp"
echo "wrote test/ts/ast/factory.golden.txt"
