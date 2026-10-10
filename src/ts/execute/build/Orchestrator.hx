package ts.execute.build;

// Port of orchestrator.go (types and methods; NewOrchestrator is in Build.hx).
// PORT: skipped, watch mode: the watchmanager field `wm` and the methods Watch, updateWatch,
// resetCaches, checkTasksForEventChanges, packageJsonLookupChanged, computeDesiredWatches,
// addWatchDir, addPackageJsonWatchDirs and DoCycle (Orchestrator does not implement tsc.Watcher).

class Options {
	public var Sys:System = null;
	public var Command:ParsedBuildCommandLine = null;
	public var Testing:Null<CommandLineTesting> = null;

	public function new() {}
}

class OrchestratorResult {
	public var result:CommandLineResult = new CommandLineResult();
	public var errors:Null<Array<Diagnostic>> = null;
	public var statistics:Statistics = new Statistics();
	public var filesToDelete:Null<Array<std.String>> = null;

	public function new() {}

	public function report(o:Orchestrator):Void {
		if (o.opts.Command.CompilerOptions.Watch.IsTrue()) {
			o.watchStatusReporter(Ast.NewCompilerDiagnostic(Core.IfElse(Core.len(this.errors) == 1, Diagnostics.Found_1_error_Watching_for_file_changes,
				Diagnostics.Found_0_errors_Watching_for_file_changes), Core.len(this.errors)));
		} else {
			o.errorSummaryReporter(this.errors);
		}
		if (this.filesToDelete != null) {
			o.createBuilderStatusReporter(null)(Ast.NewCompilerDiagnostic(Diagnostics.A_non_dry_build_would_delete_the_following_files_Colon_0,
				Core.Map(this.filesToDelete, function(f:std.String):std.String {
					return "\r\n * " + f;
				}).join("")));
		}
		if (!o.opts.Command.CompilerOptions.Diagnostics.IsTrue() && !o.opts.Command.CompilerOptions.ExtendedDiagnostics.IsTrue()) {
			return;
		}
		this.statistics.SetTotalTime(o.opts.Sys.SinceStart());
		this.statistics.Report(o.opts.Sys.Writer(), o.opts.Testing);
	}
}

@:allow(ts.execute.build)
class Orchestrator {
	var opts:Options = null;
	var comparePathsOptions:ComparePathsOptions = new ComparePathsOptions();
	var host:Host = null;

	// order generation result
	var tasks:SyncMap<Path, BuildTask> = null;
	var order:Null<Array<std.String>> = null;
	var errors:Null<Array<Diagnostic>> = null;

	var errorSummaryReporter:DiagnosticsReporter = null;
	var watchStatusReporter:DiagnosticReporter = null;

	// PORT: skipped, watch mode (fswatch event-based watching: `wm *watchmanager.WatchManager`).

	public function new() {}

	function relativeFileName(fileName:std.String):std.String {
		return Tspath.ConvertToRelativePath(fileName, this.comparePathsOptions);
	}

	function toPath(fileName:std.String):Path {
		return Tspath.ToPath(fileName, this.comparePathsOptions.CurrentDirectory, this.comparePathsOptions.UseCaseSensitiveFileNames);
	}

	function resolveBuildInfoFileName(fileName:std.String, buildInfoDir:std.String):std.String {
		if (Incremental.IsBuildInfoFileNameDefaultLibrary(fileName)) {
			return Tspath.CombinePaths(this.host.DefaultLibraryPath(), fileName);
		}
		return Tspath.GetNormalizedAbsolutePath(fileName, buildInfoDir);
	}

	public function Order():Null<Array<std.String>> {
		return this.order;
	}

	public function Upstream(configName:std.String):Null<Array<std.String>> {
		final path = this.toPath(configName);
		final task = this.getTask(path);
		return Core.Map(task.upStream, function(t:UpstreamTask):std.String {
			return t.task.config;
		});
	}

	public function Downstream(configName:std.String):Null<Array<std.String>> {
		final path = this.toPath(configName);
		final task = this.getTask(path);
		return Core.Map(task.downStream, function(t:BuildTask):std.String {
			return t.config;
		});
	}

	function getTask(path:Path):BuildTask {
		final r = this.tasks.Load(path);
		if (!r.ok) {
			throw "No build task found for " + path;
		}
		return r.value;
	}

	function createBuildTasks(oldTasks:Null<SyncMap<Path, BuildTask>>, configs:Null<Array<std.String>>, wg:WorkGroup):Void {
		for (config in configs) {
			wg.Queue(function() {
				final path = this.toPath(config);
				var task:Null<BuildTask> = null;
				var buildInfo:Null<BuildInfoEntry> = null;
				if (oldTasks != null) {
					final existing = oldTasks.Load(path);
					if (existing.ok) {
						if (!existing.value.dirty) {
							// Reuse existing task if config is same
							task = existing.value;
						} else {
							buildInfo = existing.value.buildInfoEntry;
						}
					}
				}
				if (task == null) {
					task = new BuildTask();
					task.config = config;
					task.isInitialCycle = oldTasks == null;
					task.pending = true;
					task.buildInfoEntry = buildInfo;
				}
				if (this.tasks.LoadOrStore(path, task).ok) {
					return;
				}
				task.resolved = this.host.GetResolvedProjectReference(config, path);
				task.upStream = null;
				if (task.resolved != null) {
					this.createBuildTasks(oldTasks, task.resolved.ResolvedProjectReferencePaths(), wg);
				}
			});
		}
	}

	// PORT: Go passes the slice `circularityStack` by value and appends to it; here one shared array is
	// pushed and popped around the recursion, which gives the same contents at every use.
	function setupBuildTask(configName:std.String, downStream:Null<BuildTask>, inCircularContext:Bool, completed:Set<Path>, analyzing:Set<Path>,
			circularityStack:Array<std.String>):Null<BuildTask> {
		final path = this.toPath(configName);
		final task = this.getTask(path);
		if (!completed.Has(path)) {
			if (analyzing.Has(path)) {
				if (!inCircularContext) {
					if (this.errors == null)
						this.errors = [];
					this.errors.push(Ast.NewCompilerDiagnostic(Diagnostics.Project_references_may_not_form_a_circular_graph_Cycle_detected_Colon_0,
						circularityStack.join("\n")));
				}
				return null;
			}
			analyzing.Add(path);
			circularityStack.push(configName);
			if (task.resolved != null) {
				final paths = task.resolved.ResolvedProjectReferencePaths();
				for (index in 0...Core.len(paths)) {
					final subReference = paths[index];
					final upstream = this.setupBuildTask(subReference, task, inCircularContext || task.resolved.ProjectReferences()[index].Circular, completed,
						analyzing, circularityStack);
					if (upstream != null) {
						if (task.upStream == null)
							task.upStream = [];
						task.upStream.push(new UpstreamTask(upstream, index));
					}
				}
			}
			circularityStack.pop();
			completed.Add(path);
			// PORT: task.reportDone = make(chan struct{}) dropped (single-threaded, see Buildtask.hx).
			final prev = Core.LastOrNil(this.order, "");
			if (prev != "") {
				task.prevReporter = this.getTask(this.toPath(prev));
			}
			// PORT: task.done = make(chan struct{}) dropped.
			if (this.order == null)
				this.order = [];
			this.order.push(configName);
		}
		if (this.opts.Command.CompilerOptions.Watch.IsTrue() && downStream != null) {
			if (task.downStream == null)
				task.downStream = [];
			task.downStream.push(downStream);
		}
		return task;
	}

	public function GenerateGraphReusingOldTasks():Void {
		final tasks = this.tasks;
		this.tasks = new SyncMap<Path, BuildTask>();
		this.order = null;
		this.errors = null;
		this.GenerateGraph(tasks);
	}

	public function GenerateGraph(oldTasks:Null<SyncMap<Path, BuildTask>>):Void {
		final projects = this.opts.Command.ResolvedProjectPaths();
		// Parse all config files in parallel
		final wg = Core.NewWorkGroup(this.opts.Command.CompilerOptions.SingleThreaded.IsTrue());
		this.createBuildTasks(oldTasks, projects, wg);
		wg.RunAndWait();

		// Generate the graph
		final completed = new Set<Path>();
		final analyzing = new Set<Path>();
		final circularityStack:Array<std.String> = [];
		for (project in projects) {
			this.setupBuildTask(project, null, false, completed, analyzing, circularityStack);
		}
	}

	public function Start(ctx:Context):CommandLineResult {
		if (this.opts.Command.CompilerOptions.Watch.IsTrue()) {
			this.watchStatusReporter(Ast.NewCompilerDiagnostic(Diagnostics.Starting_compilation_in_watch_mode));
		}
		this.GenerateGraph(null);
		final result = this.buildOrClean();
		if (this.opts.Command.CompilerOptions.Watch.IsTrue()) {
			// PORT: skipped, watch mode (o.Watch(ctx); result.Watcher = o).
			this.opts.Sys.Writer().Write("tsc -b --watch (watch mode) is not ported yet.\n");
			result.Status = ExitStatusNotImplemented;
		}
		return result;
	}

	function buildOrClean():CommandLineResult {
		if (!this.opts.Command.BuildOptions.Clean.IsTrue() && this.opts.Command.BuildOptions.Verbose.IsTrue()) {
			this.createBuilderStatusReporter(null)(Ast.NewCompilerDiagnostic(Diagnostics.Projects_in_this_build_Colon_0,
				Core.Map(this.Order(), function(p:std.String):std.String {
					return "\r\n    * " + this.relativeFileName(p);
				}).join("")));
		}
		final buildResult = new OrchestratorResult();
		if (Core.len(this.errors) == 0) {
			buildResult.statistics.Projects = Core.len(this.Order());
			this.rangeTask(function(path:Path, task:BuildTask) {
				this.buildOrCleanProject(task, path, buildResult);
			});
		} else {
			// Circularity errors prevent any project from being built
			buildResult.result.Status = ExitStatusProjectReferenceCycle_OutputsSkipped;
			final reportDiagnostic = this.createDiagnosticReporter(null);
			for (err in this.errors) {
				reportDiagnostic(err);
			}
			buildResult.errors = this.errors;
		}
		buildResult.report(this);
		return buildResult.result;
	}

	function rangeTask(f:(path:Path, task:BuildTask) -> Void):Void {
		var numRoutines = 4;
		final builders = this.opts.Command.BuildOptions.Builders;
		if (this.opts.Command.CompilerOptions.SingleThreaded.IsTrue()) {
			numRoutines = 1;
		} else if (builders != null) {
			numRoutines = builders;
		}

		// PORT: atomic.Int64 → plain Int (single-threaded).
		var currentTaskIndex = 0;
		final runTask = function() {
			while (true) {
				final index = currentTaskIndex++;
				if (index >= Core.len(this.order)) {
					break;
				}
				final config = this.order[index];
				final path = this.toPath(config);
				final task = this.getTask(path);
				f(path, task);
			}
		};

		if (numRoutines == 1) {
			runTask();
		} else {
			final wg = Core.NewWorkGroup(false);
			for (_ in 0...numRoutines) {
				wg.Queue(runTask);
			}
			wg.RunAndWait();
		}
	}

	function buildOrCleanProject(task:BuildTask, path:Path, buildResult:OrchestratorResult):Void {
		task.result = new TaskResult();
		task.result.reportStatus = this.createBuilderStatusReporter(task);
		task.result.diagnosticReporter = this.createDiagnosticReporter(task);
		if (!this.opts.Command.BuildOptions.Clean.IsTrue()) {
			task.buildProject(this, path);
		} else {
			task.cleanProject(this, path);
		}
		task.report(this, path, buildResult);
	}

	function getWriter(task:Null<BuildTask>):Writer {
		if (task == null) {
			return this.opts.Sys.Writer();
		}
		return task.result.builderWriter;
	}

	function createBuilderStatusReporter(task:Null<BuildTask>):DiagnosticReporter {
		return Tsc.CreateBuilderStatusReporter(this.opts.Sys, this.getWriter(task), this.opts.Command.Locale(), this.opts.Command.CompilerOptions,
			this.opts.Testing);
	}

	function createDiagnosticReporter(task:Null<BuildTask>):DiagnosticReporter {
		return Tsc.CreateDiagnosticReporter(this.opts.Sys, this.getWriter(task), this.opts.Command.Locale(), this.opts.Command.CompilerOptions);
	}
}
