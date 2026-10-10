package ts.cmd;

// Port of cmd/tsgo/main.go (program entry). sys.go is in Sys_.hx.
// PORT: lsp.go, api.go (--lsp / --api servers) and the isprocessalive_* / enablevtprocessing_*
// helpers they use are not ported.
class Tsgo {
	static function main() {
		Sys.exit(runMain());
	}

	static function runMain():Int {
		Core.ApplyDebugStackLimit();
		final args = Sys.args();
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
