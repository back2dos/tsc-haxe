package ts.execute.build;

// Package-level funcs of internal/execute/build.
@:allow(ts.execute.build)
class Build {
	// --- orchestrator.go ---

	public static function NewOrchestrator(opts:Options):Orchestrator {
		// PORT: skipped, watch mode (wm := watchmanager.NewWatchManager(...)).
		final orchestrator = new Orchestrator();
		orchestrator.opts = opts;
		orchestrator.comparePathsOptions = new ComparePathsOptions(opts.Sys.FS().UseCaseSensitiveFileNames(), opts.Sys.GetCurrentDirectory());
		orchestrator.tasks = new SyncMap<Path, BuildTask>();
		final host = new Host();
		host.orchestrator = orchestrator;
		host.host = Compiler.NewCachedFSCompilerHost(orchestrator.opts.Sys.GetCurrentDirectory(), orchestrator.opts.Sys.FS(),
			orchestrator.opts.Sys.DefaultLibraryPath(), null, null);
		host.mTimes = new SyncMap<Path, Time>(Time.Zero());
		orchestrator.host = host;
		if (opts.Command.CompilerOptions.Watch.IsTrue()) {
			orchestrator.watchStatusReporter = Tsc.CreateWatchStatusReporter(opts.Sys, opts.Command.Locale(), opts.Command.CompilerOptions, opts.Testing);
			// PORT: skipped, watch mode (wm.SetBackend(t.WatchBackend()) for CommandLineTestingWithWatchBackend).
		} else {
			orchestrator.errorSummaryReporter = Tsc.CreateReportErrorSummary(opts.Sys, opts.Command.Locale(), opts.Command.CompilerOptions);
		}
		return orchestrator;
	}
}
