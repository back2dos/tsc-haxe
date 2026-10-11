PIN       := 1e4744d68260a7cb91b62b12edc3f6a2187faaf1
TS_PIN    := 4d4f005c8541e0255a9d8791205fdce326e462bc
GO        := GOTOOLCHAIN=go1.26.9 go
HAXE      := tools/haxe
# Toolchain paths (JAVA, DOTNET, PYTHON, ...) live in tools/env.sh; build/run per target: tools/targets.sh.
TARGETS   := ROOT=$(CURDIR); . tools/targets.sh

.PHONY: test test-js test-cpp test-jvm test-cs test-py upstream ref

test: test-js test-cpp

test-js:
	$(HAXE) test-js.hxml
	node bin/test.js

test-cpp:
	$(HAXE) test-cpp.hxml
	./bin/cpp/TestMain

# Unit tests on the other targets (bin/test-jvm.jar, bin/test-cs/, bin/test-py.py).
test-jvm test-cs test-py:
	$(TARGETS); t=$(@:test-%=%); hx_build $$t TestMain bin/test && $$(hx_cmd $$t TestMain bin/test)

# Reference checkout of the pinned upstream (ignored by git).
upstream:
	test -d upstream || git clone -q --depth 1 --branch v7.0.2 https://github.com/microsoft/TypeScript upstream
	test "$$(git -C upstream rev-parse HEAD)" = "$(PIN)"
	test -f upstream/tsc/_submodules/TypeScript/package.json || ( \
		cd upstream/tsc/_submodules/TypeScript && git init -q && \
		git remote add origin https://github.com/microsoft/TypeScript.git && \
		git fetch -q --depth 1 origin $(TS_PIN) && git checkout -q FETCH_HEAD )

# Reference tsgo binary built from the pin.
ref: upstream
	cd upstream/tsc && $(GO) build -o ../../.ref/tsgo ./cmd/tsgo

# Phase gates (need `make upstream` and the Go dumpers: tools/dump/build.sh).
.PHONY: gate-scanner
gate-scanner:
	tools/gate/scanner.sh

.PHONY: gate-parser
gate-parser:
	tools/gate/parser.sh

.PHONY: gate-binder gates
gate-binder:
	tools/gate/binder.sh

gates: gate-scanner gate-parser gate-binder gate-printer

.PHONY: gate-printer
gate-printer:
	tools/gate/printer.sh

# Phase 7/8 gates (behaviour: upstream reference baselines; run after the four syntax gates).
.PHONY: gate-checker gate-tsc cli-js cli-cpp cli-jvm cli-cs cli-py
gate-checker:
	tools/gate/checker.sh

gate-tsc:
	tools/gate/tsc.sh

# The tsc CLI: JS launcher tools/tsgo-js, native binary bin/tsgo-cpp/Tsgo; launchers tools/tsgo-jvm,
# tools/tsgo-cs, tools/tsgo-py for bin/tsgo-jvm.jar, bin/tsgo-cs/, bin/tsgo-py.py.
cli-js:
	$(HAXE) build-js.hxml

cli-cpp:
	$(HAXE) build-cpp.hxml

cli-jvm cli-cs cli-py:
	$(TARGETS); hx_build $(@:cli-%=%) ts.cmd.Tsgo bin/tsgo

# Test matrix (suites x targets) into docs/MATRIX.md; options: tools/matrix.sh --help.
.PHONY: matrix
matrix:
	tools/matrix.sh $(MATRIX_ARGS)

.PHONY: gate-realworld
gate-realworld:
	tools/gate/realworld.sh
