#!/bin/sh
# Regenerates the utilities golden test (test/ts/ast/utilities.golden.txt):
# 1. tools/gen/ast/goref/utilref/gen reads upstream utilities.go + precedence.go and writes the
#    function tables tools/gen/ast/goref/utilref/funcs.go and test/ts/ast/UtilitiesGoldenTable.hx;
# 2. tools/gen/ast/goref/utilref/{main,funcs}.go are built against the pinned upstream without
#    changing it (overlaid as upstream/tsc/cmd/utilref/) and print the golden file.
# The overlay JSON goes to a temporary directory.
set -e
root=$(cd "$(dirname "$0")/../../../.." && pwd)
cd "$root"
GOTOOLCHAIN=go1.26.9 go run ./tools/gen/ast/goref/utilref/gen/main.go
tmp=$(mktemp -d)
printf '{"Replace":{"%s":"%s","%s":"%s"}}' \
	"$root/upstream/tsc/cmd/utilref/main.go" "$root/tools/gen/ast/goref/utilref/main.go" \
	"$root/upstream/tsc/cmd/utilref/funcs.go" "$root/tools/gen/ast/goref/utilref/funcs.go" > "$tmp/overlay.json"
(cd "$root/upstream/tsc" && GOTOOLCHAIN=go1.26.9 go build -overlay "$tmp/overlay.json" -o "$tmp/utilref" ./cmd/utilref)
"$tmp/utilref" > "$root/test/ts/ast/utilities.golden.txt"
rm -rf "$tmp"
echo "wrote test/ts/ast/utilities.golden.txt"
