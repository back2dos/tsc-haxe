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
	public var errors:Slice<Diagnostic> = null;
	public var statistics:Statistics = new Statistics();
	public var filesToDelete:Slice<RootedFilePath> = null;

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
				Core.Map(this.filesToDelete, function(f:RootedFilePath):std.String {
					return "\r\n * " + f.AsString();
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
	var currentDirectory:RootedDirectoryPath = cast "";
	var caseSensitivity:CaseSensitivity = CaseInsensitive;
	var host:Host = null;

	// order generation result
	var tasks:SyncMap<PathKey, BuildTask> = null;
	var order:Slice<BuildTask> = null;
	var errors:Slice<Diagnostic> = null;

	var errorSummaryReporter:DiagnosticsReporter = null;
	var watchStatusReporter:DiagnosticReporter = null;

	// PORT: skipped, watch mode (fswatch event-based watching: `wm *watchmanager.WatchManager`).

	public function new() {}

	function relativeFileName(fileName:RootedFilePath):std.String {
		return this.relativePath(fileName.AsPath());
	}

	function relativePath(path:RootedPath):std.String {
		final relative = this.caseSensitivity.RelativePathFromPath(this.currentDirectory, path);
		if (relative != null) {
			return relative.AsString();
		}
		return path.AsString();
	}

	public function Order():Slice<RootedFilePath> {
		return Core.Map(this.order, function(task:BuildTask):RootedFilePath {
			return task.config;
		});
	}

	public function Upstream(configName:std.String):Slice<std.String> {
		final path = this.caseSensitivity.PathKey(Tspath.ToRootedPath(configName, this.currentDirectory));
		final task = this.getTask(path);
		return Core.Map(task.upStream, function(t:UpstreamTask):std.String {
			return t.task.config.AsString();
		});
	}

	public function Downstream(configName:std.String):Slice<std.String> {
		final path = this.caseSensitivity.PathKey(Tspath.ToRootedPath(configName, this.currentDirectory));
		final task = this.getTask(path);
		return Core.Map(task.downStream, function(t:BuildTask):std.String {
			return t.config.AsString();
		});
	}

	function getTask(path:PathKey):BuildTask {
		final r = this.tasks.Load(path);
		if (!r.ok) {
			throw "No build task found for " + path.AsString();
		}
		return r.value;
	}

	function createBuildTasks(oldTasks:Null<SyncMap<PathKey, BuildTask>>, configs:Slice<RootedFilePath>, wg:WorkGroup):Void {
		for (config in configs) {
			wg.Queue(function() {
				final path = this.caseSensitivity.PathKey(config.AsPath());
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
					task.path = path;
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
	function setupBuildTask(configName:RootedFilePath, downStream:Null<BuildTask>, inCircularContext:Bool, completed:Set<PathKey>,
			analyzing:Set<PathKey>, circularityStack:Array<std.String>):Null<BuildTask> {
		final path = this.caseSensitivity.PathKey(configName.AsPath());
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
			circularityStack.push(configName.AsString());
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
			final prev = Core.LastOrNil(this.order, null);
			if (prev != null) {
				task.prevReporter = prev;
			}
			// PORT: task.done = make(chan struct{}) dropped.
			if (this.order == null)
				this.order = [];
			this.order.push(task);
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
		this.tasks = new SyncMap<PathKey, BuildTask>();
		this.order = null;
		this.errors = null;
		this.GenerateGraph(tasks);
	}

	public function GenerateGraph(oldTasks:Null<SyncMap<PathKey, BuildTask>>):Void {
		final projects = this.opts.Command.ResolvedProjectPaths();
		// Parse all config files in parallel
		final wg = Core.NewWorkGroup(this.opts.Command.CompilerOptions.SingleThreaded.IsTrue());
		this.createBuildTasks(oldTasks, projects, wg);
		wg.RunAndWait();

		// Generate the graph
		final completed = new Set<PathKey>();
		final analyzing = new Set<PathKey>();
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
				Core.Map(this.order, function(task:BuildTask):std.String {
					return "\r\n    * " + this.relativeFileName(task.config);
				}).join("")));
		}
		final buildResult = new OrchestratorResult();
		if (Core.len(this.errors) == 0) {
			buildResult.statistics.Projects = Core.len(this.Order());
			this.rangeTask(function(path:PathKey, task:BuildTask) {
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

	function rangeTask(f:(path:PathKey, task:BuildTask) -> Void):Void {
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
				final task = this.order[index];
				f(task.path, task);
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

	function buildOrCleanProject(task:BuildTask, path:PathKey, buildResult:OrchestratorResult):Void {
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
