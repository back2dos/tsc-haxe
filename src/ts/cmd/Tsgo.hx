package ts.cmd;

// Port of cmd/tsgo/main.go (program entry). sys.go is in Sys_.hx.
// PORT: lsp.go, api.go (--lsp / --api servers) and the isprocessalive_* / enablevtprocessing_*
// helpers they use are not ported.
class Tsgo {
	static function main() {
		final status = runMain();
		ts.checker.InferMemo.finish(); // PORT: perf — (from tsrs) TSHX_INFER_MEMO_STATS
		#if symtab_stats
		ts.ast.Symbol.SymbolTableStats.dump();
		#end
		Sys.exit(status);
	}

	static function runMain():Int {
		Core.ApplyDebugStackLimit();
		final args = Sys.args();
		#if (target.name == "hxmc" && !hxmc.wasm_gc)
		// PORT: perf — a one-shot compile keeps ~everything it allocates until it exits, so its first major
		// collection copies a live set (t3code-server: 510 MB live of 471 MB at go.GcInit's 512 MB limit, 929
		// of 942 at 1024), and below 4 GB it is cheaper not to run one at all: t3code-server 5.41 s at 512 MB,
		// 5.54 s at 1024, 5.30 s at 4096 (old space 2.8 GB, no major collection); ts6-solution -b 1.66 s /
		// 1114 MB peak at 512, 1.55 s / 752 MB at 4096. A quarter of the physical memory when that is more: a
		// major collection of a heap that is ~all live copies it whole (peak ~2x the limit; vscode at 4096: 3794
		// of 4049 MB live, 0.91 s, peak 8.4 GB). Not in watch mode (a long run that leaves garbage).
		if (args.indexOf("--watch") < 0 && args.indexOf("-w") < 0) {
			#if (hxmc.target == "wasm32-wasi")
			// wasm32: 3 GB (the most hxmc.rt.wasm.Gc takes: a compaction still fits in 4 GB), not RT_OLD_MB's 32 MB
			// default, whose growing limits made major collections of a heap that is ~all live (xstate: 3 of
			// them, 0.43 s, 392 of 407 MB live; t3code-server: 5, 3.0 s, live 1592 MB at the last; before
			// compaction, copying ones near 4 GB took t3code-server 716 s). Below 3 GB promoted there is
			// none: xstate 3.42 s -> 3.0 s at the same 503 MB of linear memory; t3code-server 24.8 s -> 21.8 s.
			hxmc.rt.wasm.Gc.setOldLimit(3072);
			#else
			final quarterMb = (hxmc.rt.Os.physicalBytes() >> 22).toInt();
			hxmc.rt.Gc.setOldLimit(quarterMb > 4096 ? quarterMb : 4096);
			#end
		}
		#end
		if (args.length > 0) {
			switch (args[0]) {
				case "--lsp", "--api":
					// PORT: skipped, runLSP / runAPI (language server and API server are out of scope).
					Sys.stderr().writeString(args[0] + " is not ported yet.\n");
					return (ExitStatusNotImplemented : Int);
				default:
			}
		}
		// PORT: signal.NotifyContext(SIGINT, SIGTERM) → context.Background() (no cancellation;
		// the default signal behaviour terminates the process).
		final ctx = Context.Background();
		final result = Execute.CommandLine(ctx, Sys_.newSystem(), args, null);
		return (result.Status : Int);
	}
}
