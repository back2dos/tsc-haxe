package ts.cmd;

// Port of cmd/tsgo/main.go (program entry). sys.go is in Sys_.hx.
// PORT: lsp.go, api.go (--lsp / --api servers) and the isprocessalive_* / enablevtprocessing_*
// helpers they use are not ported.
class Tsgo {
	static function main() {
		final status = runMain();
		ts.checker.InferMemo.finish(); // PORT: perf — (from tsrs) TSHX_INFER_MEMO_STATS
		Sys.exit(status);
	}

	static function runMain():Int {
		Core.ApplyDebugStackLimit();
		final args = Sys.args();
		#if (target.name == "hxmc" && !hxmc.wasm_gc && hxmc.target != "wasm32-wasi")
		// PORT: perf — a one-shot compile keeps ~everything it allocates until it exits, so its first major
		// collection copies a live set (t3code-server: 510 MB live of 471 MB at go.GcInit's 512 MB limit, 929
		// of 942 at 1024), and below 4 GB it is cheaper not to run one at all: t3code-server 5.41 s at 512 MB,
		// 5.54 s at 1024, 5.30 s at 4096 (old space 2.8 GB, no major collection); ts6-solution -b 1.66 s /
		// 1114 MB peak at 512, 1.55 s / 752 MB at 4096. Not in watch mode (a long run that leaves garbage).
		if (args.indexOf("--watch") < 0 && args.indexOf("-w") < 0)
			hxmc.rt.Gc.setOldLimit(4096);
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
