package ts.execute.build;

// Port of buildtask.go.
// PORT: single-threaded port (PORTING.md §4): the channels `done` / `reportDone` and the mutexes are
// dropped. Tasks run one after the other in `Orchestrator.order` (a dependency order: every upstream
// project comes before its downstream projects), so the waits on upstream tasks and on the previous
// reporter are always satisfied when they happen.

enum abstract BuildKind(Int) from Int to Int {
	var buildKindNone = 0;
	var buildKindPseudo = 1;
	var buildKindProgram = 2;
}

class UpstreamTask {
	public var task:BuildTask = null;
	public var refIndex:Int = 0;

	public function new(task:BuildTask, refIndex:Int) {
		this.task = task;
		this.refIndex = refIndex;
	}
}

class BuildInfoEntry {
	public var buildInfo:Null<BuildInfo> = null;
	public var path:Path = "";
	public var mTime:Time = Time.Zero();
	// PORT: pointer — *time.Time → Null<Time>.
	public var dtsTime:Null<Time> = null;

	public function new() {}
}

class TaskResult {
	public var builder:Builder = new Builder();
	// PORT: `&t.result.builder` used as an io.Writer → one adapter per builder.
	public var builderWriter:BuilderWriter = null;
	public var reportStatus:DiagnosticReporter = null;
	public var diagnosticReporter:DiagnosticReporter = null;
	public var exitStatus:ExitStatus = ExitStatusSuccess;
	public var statistics:Null<Statistics> = null;
	public var program:Null<ts.execute.incremental.Program.Program> = null;
	public var buildKind:BuildKind = buildKindNone;
	public var filesToDelete:Null<Array<std.String>> = null;

	public function new() {
		this.builderWriter = new BuilderWriter(this.builder);
	}
}

@:allow(ts.execute.build)
class BuildTask {
	var config:std.String = "";
	var resolved:Null<ParsedCommandLine> = null;
	var upStream:Null<Array<UpstreamTask>> = null;
	var downStream:Null<Array<BuildTask>> = null; // Only set and used in watch mode
	var status:Null<UpToDateStatus> = null;

	// PORT: `done chan struct{}` dropped (see the file header).

	// task reporting
	var result:Null<TaskResult> = null;
	var prevReporter:Null<BuildTask> = null;
	// PORT: `reportDone chan struct{}` dropped (see the file header).

	var buildInfoEntry:Null<BuildInfoEntry> = null;
	var packageJsons:Null<Array<std.String>> = null;

	var errors:Null<Array<Diagnostic>> = null;
	var pending:Bool = false;
	var isInitialCycle:Bool = false;
	var dirty:Bool = false;

	public function new() {}

	function waitOnUpstream():Void {
		// PORT: `<-upstream.task.done` for each upstream task: upstream tasks already ran (see header).
	}

	function unblockDownstream():Void {
		this.pending = false;
		this.isInitialCycle = false;
		// PORT: close(t.done) dropped (see header).
	}

	function reportDiagnostic(err:Diagnostic):Void {
		if (this.errors == null)
			this.errors = [];
		this.errors.push(err);
		this.result.diagnosticReporter(err);
	}

	function report(orchestrator:Orchestrator, configPath:Path, buildResult:OrchestratorResult):Void {
		// PORT: `<-t.prevReporter.reportDone` dropped (see header).
		if (Core.len(this.errors) > 0) {
			if (buildResult.errors == null)
				buildResult.errors = [];
			for (e in this.errors)
				buildResult.errors.push(e);
		}
		orchestrator.opts.Sys.Writer().Write(this.result.builder.String());
		if ((this.result.exitStatus : Int) > (buildResult.result.Status : Int)) {
			buildResult.result.Status = this.result.exitStatus;
		}
		if (this.result.statistics != null) {
			buildResult.statistics.Aggregate(this.result.statistics);
		}
		// If we built the program, or updated timestamps, or had errors, we need to
		// delete files that are no longer needed
		switch (this.result.buildKind) {
			case buildKindProgram:
				if (orchestrator.opts.Testing != null) {
					orchestrator.opts.Testing.OnProgram(this.result.program);
				}
				buildResult.statistics.ProjectsBuilt++;
			case buildKindPseudo:
				buildResult.statistics.TimestampUpdates++;
			default:
		}
		// PORT: Go `append(nil, nothing...)` stays nil.
		if (Core.len(this.result.filesToDelete) > 0) {
			if (buildResult.filesToDelete == null)
				buildResult.filesToDelete = [];
			for (f in this.result.filesToDelete)
				buildResult.filesToDelete.push(f);
		}
		this.result = null;
		// PORT: close(t.reportDone) dropped (see header).
	}

	function buildProject(orchestrator:Orchestrator, path:Path):Void {
		// Wait on upstream tasks to complete
		this.waitOnUpstream();
		if (this.pending) {
			this.status = this.getUpToDateStatus(orchestrator, path);
			this.reportUpToDateStatus(orchestrator);
			if (!this.handleStatusThatDoesntRequireBuild(orchestrator)) {
				this.compileAndEmit(orchestrator, path);
				this.updateDownstream(orchestrator, path);
			} else {
				if (this.resolved != null) {
					for (diagnostic in this.resolved.GetConfigFileParsingDiagnostics()) {
						this.reportDiagnostic(diagnostic);
					}
				}
				if (Core.len(this.errors) > 0) {
					this.result.exitStatus = ExitStatusDiagnosticsPresent_OutputsSkipped;
				}
			}
		} else {
			if (Core.len(this.errors) > 0) {
				this.reportUpToDateStatus(orchestrator);
				for (err in this.errors) {
					// Should not add the diagnostics so just reporting
					this.result.diagnosticReporter(err);
				}
			}
		}
		this.unblockDownstream();
	}

	function updateDownstream(orchestrator:Orchestrator, path:Path):Void {
		if (this.isInitialCycle) {
			return;
		}
		if (orchestrator.opts.Command.BuildOptions.StopBuildOnErrors.IsTrue() && this.status.isError()) {
			return;
		}

		for (downStream in this.downStream) {
			if (downStream.status != null) {
				// PORT: Go `switch` with `break` / `fallthrough` → if/else chain.
				final kind = downStream.status.kind;
				var fallToPseudo = false;
				if (kind == upToDateStatusTypeUpToDate) {
					if (!this.result.program.HasChangedDtsFile()) {
						downStream.status = new UpToDateStatus(upToDateStatusTypeUpToDateWithUpstreamTypes, downStream.status.data);
					} else {
						fallToPseudo = true;
					}
				}
				if (fallToPseudo || kind == upToDateStatusTypeUpToDateWithUpstreamTypes || kind == upToDateStatusTypeUpToDateWithInputFileText) {
					if (this.result.program.HasChangedDtsFile()) {
						downStream.status = new UpToDateStatus(upToDateStatusTypeInputFileNewer,
							new InputOutputName(this.config, downStream.status.oldestOutputFileName()));
					}
				} else if (kind == upToDateStatusTypeUpstreamErrors) {
					final upstreamErrors = downStream.status.upstreamErrors();
					final refConfig = Core.ResolveConfigFileNameOfProjectReference(upstreamErrors.ref);
					if (orchestrator.toPath(refConfig) == path) {
						downStream.resetStatus();
					}
				}
			}
			downStream.pending = true;
		}
	}

	function compileAndEmit(orchestrator:Orchestrator, path:Path):Void {
		this.errors = null;
		if (orchestrator.opts.Command.BuildOptions.Verbose.IsTrue()) {
			this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Building_project_0, orchestrator.relativeFileName(this.config)));
		}

		// Real build
		final compileTimes = new CompileTimes();
		final configTime = orchestrator.host.configTimes.Load(path).value;
		compileTimes.ConfigTime = configTime;
		final buildInfoReadStart = orchestrator.opts.Sys.Now();
		var oldProgram:Null<ts.execute.incremental.Program.Program> = null;
		if (!orchestrator.opts.Command.BuildOptions.Force.IsTrue()) {
			oldProgram = Incremental.ReadBuildInfoProgram(this.resolved, orchestrator.host, orchestrator.host);
		}
		compileTimes.BuildInfoReadTime = orchestrator.opts.Sys.Now().Sub(buildInfoReadStart);
		final parseStart = orchestrator.opts.Sys.Now();
		final programOptions = new ProgramOptions();
		programOptions.Config = this.resolved;
		programOptions.Host = new CompilerHost_(orchestrator.host,
			Tsc.GetTraceWithWriterFromSys(this.result.builderWriter, orchestrator.opts.Command.Locale(), orchestrator.opts.Testing));
		final program = Compiler.NewProgram(programOptions);
		compileTimes.ParseTime = orchestrator.opts.Sys.Now().Sub(parseStart);
		final changesComputeStart = orchestrator.opts.Sys.Now();
		this.result.program = Incremental.NewProgram(program, oldProgram, orchestrator.host, orchestrator.opts.Testing != null);
		compileTimes.ChangesComputeTime = orchestrator.opts.Sys.Now().Sub(changesComputeStart);

		final emitInput = new EmitInput();
		emitInput.Sys = orchestrator.opts.Sys;
		emitInput.ProgramLike = this.result.program;
		emitInput.Program = program;
		emitInput.Config = this.resolved;
		emitInput.ReportDiagnostic = this.reportDiagnostic;
		emitInput.ReportErrorSummary = Tsc.QuietDiagnosticsReporter;
		emitInput.Writer = this.result.builderWriter;
		emitInput.WriteFile = function(fileName:std.String, text:std.String, data:WriteFileData):Null<Error> {
			return this.writeFile(orchestrator, fileName, text, data);
		};
		emitInput.CompileTimes = compileTimes;
		emitInput.Testing = orchestrator.opts.Testing;
		emitInput.TestingMTimesCache = orchestrator.host.mTimes;
		final r = Tsc.EmitAndReportStatistics(emitInput);
		final result = r.a, statistics = r.b;
		this.result.exitStatus = result.Status;
		this.result.statistics = statistics;
		this.packageJsons = this.result.program.PackageJsonLookupPaths();
		if ((!program.Options().NoEmitOnError.IsTrue() || Core.len(result.Diagnostics) == 0)
			&& (Core.len(result.EmitResult.EmittedFiles) > 0 || this.status.kind != upToDateStatusTypeOutOfDateBuildInfoWithErrors)) {
			// Update time stamps for rest of the outputs
			this.updateTimeStamps(orchestrator, result.EmitResult.EmittedFiles, Diagnostics.Updating_unchanged_output_timestamps_of_project_0);
		}
		this.result.buildKind = buildKindProgram;
		if (result.Status == ExitStatusDiagnosticsPresent_OutputsSkipped || result.Status == ExitStatusDiagnosticsPresent_OutputsGenerated) {
			this.status = new UpToDateStatus(upToDateStatusTypeBuildErrors);
		} else {
			var oldestOutputFileName:std.String;
			if (Core.len(result.EmitResult.EmittedFiles) > 0) {
				oldestOutputFileName = result.EmitResult.EmittedFiles[0];
			} else {
				oldestOutputFileName = Core.FirstOrNilSeq(this.resolved.GetOutputFileNames(), "");
			}
			this.status = new UpToDateStatus(upToDateStatusTypeUpToDate, oldestOutputFileName);
		}
	}

	function handleStatusThatDoesntRequireBuild(orchestrator:Orchestrator):Bool {
		switch (this.status.kind) {
			case upToDateStatusTypeUpToDate:
				if (orchestrator.opts.Command.BuildOptions.Dry.IsTrue()) {
					this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_up_to_date, this.config));
				}
				return true;
			case upToDateStatusTypeUpstreamErrors:
				final upstreamStatus = this.status.upstreamErrors();
				if (orchestrator.opts.Command.BuildOptions.Verbose.IsTrue()) {
					this.result.reportStatus(Ast.NewCompilerDiagnostic(Core.IfElse(upstreamStatus.refHasUpstreamErrors,
						Diagnostics.Skipping_build_of_project_0_because_its_dependency_1_was_not_built,
						Diagnostics.Skipping_build_of_project_0_because_its_dependency_1_has_errors),
						orchestrator.relativeFileName(this.config), orchestrator.relativeFileName(upstreamStatus.ref)));
				}
				return true;
			case upToDateStatusTypeSolution:
				return true;
			case upToDateStatusTypeConfigFileNotFound:
				this.reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.File_0_not_found, this.config));
				return true;
			default:
		}

		// update timestamps
		if (this.status.isPseudoBuild()) {
			if (orchestrator.opts.Command.BuildOptions.Dry.IsTrue()) {
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.A_non_dry_build_would_update_timestamps_for_output_of_project_0, this.config));
				this.status = new UpToDateStatus(upToDateStatusTypeUpToDate);
				return true;
			}

			this.updateTimeStamps(orchestrator, null, Diagnostics.Updating_output_timestamps_of_project_0);
			this.status = new UpToDateStatus(upToDateStatusTypeUpToDate, this.status.data);
			this.result.buildKind = buildKindPseudo;
			return true;
		}

		if (orchestrator.opts.Command.BuildOptions.Dry.IsTrue()) {
			this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.A_non_dry_build_would_build_project_0, this.config));
			this.status = new UpToDateStatus(upToDateStatusTypeUpToDate);
			return true;
		}
		return false;
	}

	function getUpToDateStatus(orchestrator:Orchestrator, configPath:Path):UpToDateStatus {
		if (this.status != null) {
			return this.status;
		}
		// Config file not found
		if (this.resolved == null) {
			return new UpToDateStatus(upToDateStatusTypeConfigFileNotFound);
		}

		// Solution - nothing to build
		if (Core.len(this.resolved.FileNames()) == 0 && this.resolved.ProjectReferences() != null) {
			return new UpToDateStatus(upToDateStatusTypeSolution);
		}

		for (upstream in this.upStream) {
			if (orchestrator.opts.Command.BuildOptions.StopBuildOnErrors.IsTrue() && upstream.task.status.isError()) {
				// Upstream project has errors, so we cannot build this project
				return new UpToDateStatus(upToDateStatusTypeUpstreamErrors,
					new UpstreamErrors(this.resolved.ProjectReferences()[upstream.refIndex].Path, upstream.task.status.kind == upToDateStatusTypeUpstreamErrors));
			}
		}

		if (orchestrator.opts.Command.BuildOptions.Force.IsTrue()) {
			return new UpToDateStatus(upToDateStatusTypeForceBuild);
		}

		// Check the build info
		final buildInfoPath = this.resolved.GetBuildInfoFileName();
		final getBuildInfoDirectory = Core.Memoize(function():std.String {
			return Tspath.GetDirectoryPath(Tspath.GetNormalizedAbsolutePath(buildInfoPath, orchestrator.comparePathsOptions.CurrentDirectory));
		});
		final bi = this.loadOrStoreBuildInfo(orchestrator, configPath, buildInfoPath);
		final buildInfo = bi.a, buildInfoTime = bi.b;
		if (buildInfo == null) {
			return new UpToDateStatus(upToDateStatusTypeOutputMissing, buildInfoPath);
		}

		// build info version
		if (!buildInfo.IsValidVersion()) {
			return new UpToDateStatus(upToDateStatusTypeTsVersionOutputOfDate, buildInfo.Version);
		}

		// Report errors if build info indicates errors
		if (buildInfo.Errors || // Errors that need to be reported irrespective of "--noCheck"
			(!this.resolved.CompilerOptions().NoCheck.IsTrue() && (buildInfo.SemanticErrors || buildInfo.CheckPending))) { // Errors without --noCheck
			return new UpToDateStatus(upToDateStatusTypeOutOfDateBuildInfoWithErrors, buildInfoPath);
		}

		if (this.resolved.CompilerOptions().IsIncremental()) {
			if (!buildInfo.IsIncremental()) {
				// Program options out of date
				return new UpToDateStatus(upToDateStatusTypeOutOfDateOptions, buildInfoPath);
			}

			// Errors need to be reported if build info has errors
			if ((this.resolved.CompilerOptions().GetEmitDeclarations() && buildInfo.EmitDiagnosticsPerFile != null) || // Always reported errors
				(!this.resolved.CompilerOptions().NoCheck.IsTrue() && // Semantic errors if not --noCheck
					(buildInfo.ChangeFileSet != null || buildInfo.SemanticDiagnosticsPerFile != null))) {
				return new UpToDateStatus(upToDateStatusTypeOutOfDateBuildInfoWithErrors, buildInfoPath);
			}

			// Pending emit files
			if (!this.resolved.CompilerOptions().NoEmit.IsTrue() && (buildInfo.ChangeFileSet != null || buildInfo.AffectedFilesPendingEmit != null)) {
				return new UpToDateStatus(upToDateStatusTypeOutOfDateBuildInfoWithPendingEmit, buildInfoPath);
			}

			// Some of the emit files like source map or dts etc are not yet done
			if (buildInfo.IsEmitPending(this.resolved, getBuildInfoDirectory())) {
				return new UpToDateStatus(upToDateStatusTypeOutOfDateOptions, buildInfoPath);
			}
		}
		var inputTextUnchanged = false;
		var oldestOutputFileAndTime = new FileAndTime(buildInfoPath, buildInfoTime);
		var newestInputFileAndTime = new FileAndTime();
		final seenRoots = new Set<Path>();
		final getBuildInfoRootInfoReader = Core.Memoize(function():BuildInfoRootInfoReader {
			return buildInfo.GetBuildInfoRootInfoReader(getBuildInfoDirectory(), orchestrator.comparePathsOptions);
		});
		for (inputFile in this.resolved.FileNames()) {
			final inputTime = orchestrator.host.GetMTime(inputFile);
			if (inputTime.IsZero()) {
				return new UpToDateStatus(upToDateStatusTypeInputFileMissing, inputFile);
			}
			final inputPath = orchestrator.toPath(inputFile);
			if (inputTime.After(oldestOutputFileAndTime.time)) {
				var version = "";
				var currentVersion = "";
				if (buildInfo.IsIncremental()) {
					final p = getBuildInfoRootInfoReader().GetBuildInfoFileInfo(inputPath);
					final buildInfoFileInfo = p.a, resolvedInputPath = p.b;
					// PORT: Go calls GetFileInfo on a possibly nil *BuildInfoFileInfo (nil receiver → nil).
					final fileInfo = buildInfoFileInfo == null ? null : buildInfoFileInfo.GetFileInfo();
					if (fileInfo != null && fileInfo.Version() != "") {
						version = fileInfo.Version();
						final text = orchestrator.host.FS().ReadFile(resolvedInputPath);
						if (text.ok) {
							currentVersion = Incremental.ComputeHash(text.value, orchestrator.opts.Testing != null);
							if (version == currentVersion) {
								inputTextUnchanged = true;
							}
						}
					}
				}

				if (version == "" || version != currentVersion) {
					return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(inputFile, buildInfoPath));
				}
			}
			if (inputTime.After(newestInputFileAndTime.time)) {
				newestInputFileAndTime = new FileAndTime(inputFile, inputTime);
			}
			seenRoots.Add(inputPath);
		}

		for (root in getBuildInfoRootInfoReader().Roots()) {
			if (!seenRoots.Has(root)) {
				// File was root file when project was built but its not any more
				return new UpToDateStatus(upToDateStatusTypeOutOfDateRoots, new InputOutputName(root, buildInfoPath));
			}
		}

		if (buildInfo.IsIncremental()) {
			final resolvedRoots = new Set<Path>();
			for (root in getBuildInfoRootInfoReader().Roots()) {
				final resolved = getBuildInfoRootInfoReader().GetBuildInfoFileInfo(root).b;
				if (resolved != "") {
					resolvedRoots.Add(resolved);
				}
			}
			for (index in 0...Core.len(buildInfo.FileInfos)) {
				final buildInfoFileInfo = buildInfo.FileInfos[index];
				final buildInfoFileName = buildInfo.FileNames[index];
				// Lib files bundled with the compiler can change only with the version of the compiler,
				// which is already verified with buildInfo.Version
				if (Incremental.IsBuildInfoFileNameDefaultLibrary(buildInfoFileName)) {
					continue;
				}
				final inputFile = Tspath.GetNormalizedAbsolutePath(buildInfoFileName, getBuildInfoDirectory());
				final inputPath = orchestrator.toPath(inputFile);
				// Root files are already checked
				if (seenRoots.Has(inputPath) || resolvedRoots.Has(inputPath)) {
					continue;
				}
				final inputTime = orchestrator.host.GetMTime(inputFile);
				if (inputTime.IsZero()) {
					// Input file that was part of the program is missing (eg: dependency was removed)
					return new UpToDateStatus(upToDateStatusTypeInputFileMissing, inputFile);
				}
				if (inputTime.After(oldestOutputFileAndTime.time)) {
					var currentVersion = "";
					final version = buildInfoFileInfo.GetFileInfo().Version();
					if (version != "") {
						final text = orchestrator.host.FS().ReadFile(inputFile);
						if (text.ok) {
							currentVersion = Incremental.ComputeHash(text.value, orchestrator.opts.Testing != null);
						}
					}
					if (version == "" || version != currentVersion) {
						return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(inputFile, buildInfoPath));
					}
					inputTextUnchanged = true;
				}
			}
		}

		if (!this.resolved.CompilerOptions().IsIncremental()) {
			// Check output file stamps
			for (outputFile in this.resolved.GetOutputFileNames()) {
				final outputTime = orchestrator.host.GetMTime(outputFile);
				if (outputTime.IsZero()) {
					// Output file missing
					return new UpToDateStatus(upToDateStatusTypeOutputMissing, outputFile);
				}

				if (outputTime.Before(newestInputFileAndTime.time)) {
					// Output file is older than input file
					return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(newestInputFileAndTime.file, outputFile));
				}

				if (outputTime.Before(oldestOutputFileAndTime.time)) {
					oldestOutputFileAndTime = new FileAndTime(outputFile, outputTime);
				}
			}
		}

		var refDtsUnchanged = false;
		for (upstream in this.upStream) {
			if (upstream.task.status.kind == upToDateStatusTypeSolution) {
				// Not dependent on the status or this upstream project
				// (eg: expected cycle was detected and hence skipped, or is solution)
				continue;
			}

			// If the upstream project's newest file is older than our oldest output,
			// we can't be out of date because of it
			// inputTime will not be present if we just built this project or updated timestamps
			// - in that case we do want to either build or update timestamps
			final refInputOutputFileAndTime = upstream.task.status.inputOutputFileAndTime();
			if (refInputOutputFileAndTime != null && !refInputOutputFileAndTime.input.time.IsZero()
				&& refInputOutputFileAndTime.input.time.Before(oldestOutputFileAndTime.time)) {
				continue;
			}

			// Check if tsbuildinfo path is shared, then we need to rebuild
			if (this.hasConflictingBuildInfo(orchestrator, upstream.task)) {
				// We have an output older than an upstream output - we are out of date
				return new UpToDateStatus(upToDateStatusTypeInputFileNewer,
					new InputOutputName(this.resolved.ProjectReferences()[upstream.refIndex].Path, oldestOutputFileAndTime.file));
			}

			// If the upstream project has only change .d.ts files, and we've built
			// *after* those files, then we're "pseudo up to date" and eligible for a fast rebuild
			final newestDtsChangeTime = upstream.task.getLatestChangedDtsMTime(orchestrator);
			if (!newestDtsChangeTime.IsZero() && newestDtsChangeTime.Before(oldestOutputFileAndTime.time)) {
				refDtsUnchanged = true;
				continue;
			}

			// We have an output older than an upstream output - we are out of date
			return new UpToDateStatus(upToDateStatusTypeInputFileNewer,
				new InputOutputName(this.resolved.ProjectReferences()[upstream.refIndex].Path, oldestOutputFileAndTime.file));
		}

		final checkInputFileTime = function(inputFile:std.String):Null<UpToDateStatus> {
			final inputTime = orchestrator.host.GetMTime(inputFile);
			if (inputTime.After(oldestOutputFileAndTime.time)) {
				// Output file is older than input file
				return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(inputFile, oldestOutputFileAndTime.file));
			}
			return null;
		};

		final configStatus = checkInputFileTime(this.config);
		if (configStatus != null) {
			return configStatus;
		}

		for (extendedConfig in this.resolved.ExtendedSourceFiles()) {
			final extendedConfigStatus = checkInputFileTime(extendedConfig);
			if (extendedConfigStatus != null) {
				return extendedConfigStatus;
			}
		}

		for (packageJson in buildInfo.GetPackageJsons(getBuildInfoDirectory())) {
			final packageJsonTime = orchestrator.host.GetMTime(packageJson);
			if (packageJsonTime.IsZero()) {
				return new UpToDateStatus(upToDateStatusTypeInputFileMissing, packageJson);
			}
			if (packageJsonTime.After(oldestOutputFileAndTime.time)) {
				return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(packageJson, oldestOutputFileAndTime.file));
			}
		}
		for (packageJson in buildInfo.GetMissingPackageJsons(getBuildInfoDirectory())) {
			if (!orchestrator.host.GetMTime(packageJson).IsZero()) {
				return new UpToDateStatus(upToDateStatusTypeInputFileNewer, new InputOutputName(packageJson, oldestOutputFileAndTime.file));
			}
		}
		this.packageJsons = [for (p in buildInfo.GetPackageJsons(getBuildInfoDirectory())) p];
		for (p in buildInfo.GetMissingPackageJsons(getBuildInfoDirectory()))
			this.packageJsons.push(p);

		return new UpToDateStatus(Core.IfElse(refDtsUnchanged, upToDateStatusTypeUpToDateWithUpstreamTypes,
			Core.IfElse(inputTextUnchanged, upToDateStatusTypeUpToDateWithInputFileText, upToDateStatusTypeUpToDate)),
			new InputOutputFileAndTime(newestInputFileAndTime, oldestOutputFileAndTime, buildInfoPath));
	}

	function reportUpToDateStatus(orchestrator:Orchestrator):Void {
		if (!orchestrator.opts.Command.BuildOptions.Verbose.IsTrue()) {
			return;
		}
		switch (this.status.kind) {
			case upToDateStatusTypeConfigFileNotFound:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_config_file_does_not_exist,
					orchestrator.relativeFileName(this.config)));
			case upToDateStatusTypeUpstreamErrors:
				final upstreamStatus = this.status.upstreamErrors();
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Core.IfElse(upstreamStatus.refHasUpstreamErrors,
					Diagnostics.Project_0_can_t_be_built_because_its_dependency_1_was_not_built,
					Diagnostics.Project_0_can_t_be_built_because_its_dependency_1_has_errors),
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName(upstreamStatus.ref)));
			case upToDateStatusTypeBuildErrors:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_it_has_errors,
					orchestrator.relativeFileName(this.config)));
			case upToDateStatusTypeUpToDate:
				// This is to ensure skipping verbose log for projects that were built,
				// and then some other package changed but this package doesnt need update
				final inputOutputFileAndTime = this.status.inputOutputFileAndTime();
				if (inputOutputFileAndTime != null) {
					this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_up_to_date_because_newest_input_1_is_older_than_output_2,
						orchestrator.relativeFileName(this.config), orchestrator.relativeFileName(inputOutputFileAndTime.input.file),
						orchestrator.relativeFileName(inputOutputFileAndTime.output.file)));
				}
			case upToDateStatusTypeUpToDateWithUpstreamTypes:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_up_to_date_with_d_ts_files_from_its_dependencies,
					orchestrator.relativeFileName(this.config)));
			case upToDateStatusTypeUpToDateWithInputFileText:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_up_to_date_but_needs_to_update_timestamps_of_output_files_that_are_older_than_input_files,
					orchestrator.relativeFileName(this.config)));
			case upToDateStatusTypeInputFileMissing:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_input_1_does_not_exist,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String))));
			case upToDateStatusTypeOutputMissing:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_output_file_1_does_not_exist,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String))));
			case upToDateStatusTypeInputFileNewer:
				final inputOutput = this.status.inputOutputName();
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_output_1_is_older_than_input_2,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName(inputOutput.output),
					orchestrator.relativeFileName(inputOutput.input)));
			case upToDateStatusTypeOutOfDateBuildInfoWithPendingEmit:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_buildinfo_file_1_indicates_that_some_of_the_changes_were_not_emitted,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String))));
			case upToDateStatusTypeOutOfDateBuildInfoWithErrors:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_buildinfo_file_1_indicates_that_program_needs_to_report_errors,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String))));
			case upToDateStatusTypeOutOfDateOptions:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_buildinfo_file_1_indicates_there_is_change_in_compilerOptions,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String))));
			case upToDateStatusTypeOutOfDateRoots:
				final inputOutput = this.status.inputOutputName();
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_buildinfo_file_1_indicates_that_file_2_was_root_file_of_compilation_but_not_any_more,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName(inputOutput.output),
					orchestrator.relativeFileName(inputOutput.input)));
			case upToDateStatusTypeTsVersionOutputOfDate:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_out_of_date_because_output_for_it_was_generated_with_version_1_that_differs_with_current_version_2,
					orchestrator.relativeFileName(this.config), orchestrator.relativeFileName((cast this.status.data : std.String)), Core.Version()));
			case upToDateStatusTypeForceBuild:
				this.result.reportStatus(Ast.NewCompilerDiagnostic(Diagnostics.Project_0_is_being_forcibly_rebuilt, orchestrator.relativeFileName(this.config)));
			case upToDateStatusTypeSolution:
				// Does not need to report status
			default:
				throw "Unknown up to date status kind: " + (this.status.kind : Int);
		}
	}

	function canUpdateJsDtsOutputTimestamps():Bool {
		return !this.resolved.CompilerOptions().NoEmit.IsTrue() && !this.resolved.CompilerOptions().IsIncremental();
	}

	function updateTimeStamps(orchestrator:Orchestrator, emittedFiles:Null<Array<std.String>>, verboseMessage:Message):Void {
		final emitted = emittedFiles == null ? Collections.NewSetFromItems() : Collections.NewSetFromItems(...emittedFiles);
		var verboseMessageReported = false;
		final buildInfoName = this.resolved.GetBuildInfoFileName();
		final now = orchestrator.opts.Sys.Now();
		final updateTimeStamp = function(file:std.String) {
			if (emitted.Has(file)) {
				return;
			}
			if (!verboseMessageReported && orchestrator.opts.Command.BuildOptions.Verbose.IsTrue()) {
				this.result.reportStatus(Ast.NewCompilerDiagnostic(verboseMessage, orchestrator.relativeFileName(this.config)));
				verboseMessageReported = true;
			}
			final err = orchestrator.host.SetMTime(file, now);
			if (err == null) {
				if (file == buildInfoName) {
					if (this.buildInfoEntry != null) {
						this.buildInfoEntry.mTime = now;
					}
				} else if (this.storeOutputTimeStamp(orchestrator)) {
					orchestrator.host.storeMTime(file, now);
				}
			}
		};

		if (this.canUpdateJsDtsOutputTimestamps()) {
			for (outputFile in this.resolved.GetOutputFileNames()) {
				updateTimeStamp(outputFile);
			}
		}
		updateTimeStamp(this.resolved.GetBuildInfoFileName());
	}

	function cleanProject(orchestrator:Orchestrator, path:Path):Void {
		if (this.resolved == null) {
			this.reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.File_0_not_found, this.config));
			this.result.exitStatus = ExitStatusDiagnosticsPresent_OutputsSkipped;
			return;
		}

		final inputPaths:Array<Path> = Core.Map(this.resolved.FileNames(), orchestrator.toPath);
		final inputs = inputPaths == null ? Collections.NewSetFromItems() : Collections.NewSetFromItems(...inputPaths);
		for (outputFile in this.resolved.GetOutputFileNames()) {
			this.cleanProjectOutput(orchestrator, outputFile, inputs);
		}
		this.cleanProjectOutput(orchestrator, this.resolved.GetBuildInfoFileName(), inputs);
	}

	function cleanProjectOutput(orchestrator:Orchestrator, outputFile:std.String, inputs:Set<Path>):Void {
		final outputPath = orchestrator.toPath(outputFile);
		// If output name is same as input file name, do not delete and ignore the error
		if (inputs.Has(outputPath)) {
			return;
		}
		if (orchestrator.host.FS().FileExists(outputFile)) {
			if (!orchestrator.opts.Command.BuildOptions.Dry.IsTrue()) {
				final err = orchestrator.host.FS().Remove(outputFile);
				if (err != null) {
					this.reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.Failed_to_delete_file_0, outputFile));
				}
			} else {
				if (this.result.filesToDelete == null)
					this.result.filesToDelete = [];
				this.result.filesToDelete.push(outputFile);
			}
		}
	}

	// PORT: skipped, watch mode (updateWatch: only called from Orchestrator.updateWatch).

	function resetStatus():Void {
		this.status = null;
		this.pending = true;
		this.errors = null;
	}

	// PORT: skipped, watch mode (resetConfig: only called from the watch cycle).

	// PORT: (*incremental.BuildInfo, time.Time) → Pair.
	function loadOrStoreBuildInfo(orchestrator:Orchestrator, configPath:Path, buildInfoFileName:std.String):Pair<Null<BuildInfo>, Time> {
		final path = orchestrator.toPath(buildInfoFileName);
		if (this.buildInfoEntry != null && this.buildInfoEntry.path == path) {
			return new Pair(this.buildInfoEntry.buildInfo, this.buildInfoEntry.mTime);
		}
		this.buildInfoEntry = new BuildInfoEntry();
		this.buildInfoEntry.buildInfo = Incremental.NewBuildInfoReader(orchestrator.host).ReadBuildInfo(this.resolved);
		this.buildInfoEntry.path = path;
		var mTime = Time.Zero();
		if (this.buildInfoEntry.buildInfo != null) {
			mTime = orchestrator.host.GetMTime(buildInfoFileName);
		}
		this.buildInfoEntry.mTime = mTime;
		return new Pair(this.buildInfoEntry.buildInfo, mTime);
	}

	function onBuildInfoEmit(orchestrator:Orchestrator, buildInfoFileName:std.String, buildInfo:BuildInfo, hasChangedDtsFile:Bool):Void {
		var dtsTime:Null<Time> = null;
		final mTime = orchestrator.opts.Sys.Now();
		if (hasChangedDtsFile) {
			dtsTime = mTime;
		} else if (this.buildInfoEntry != null) {
			dtsTime = this.buildInfoEntry.dtsTime;
		}
		final e = new BuildInfoEntry();
		e.buildInfo = buildInfo;
		e.path = orchestrator.toPath(buildInfoFileName);
		e.mTime = mTime;
		e.dtsTime = dtsTime;
		this.buildInfoEntry = e;
	}

	function hasConflictingBuildInfo(orchestrator:Orchestrator, upstream:BuildTask):Bool {
		if (this.buildInfoEntry != null && upstream.buildInfoEntry != null) {
			return this.buildInfoEntry.path == upstream.buildInfoEntry.path;
		}
		return false;
	}

	function getLatestChangedDtsMTime(orchestrator:Orchestrator):Time {
		if (this.buildInfoEntry.dtsTime != null) {
			return this.buildInfoEntry.dtsTime;
		}
		final dtsTime = orchestrator.host.GetMTime(Tspath.GetNormalizedAbsolutePath(this.buildInfoEntry.buildInfo.LatestChangedDtsFile,
			Tspath.GetDirectoryPath(this.buildInfoEntry.path)));
		this.buildInfoEntry.dtsTime = dtsTime;
		return dtsTime;
	}

	function storeOutputTimeStamp(orchestrator:Orchestrator):Bool {
		return orchestrator.opts.Command.CompilerOptions.Watch.IsTrue() && !this.resolved.CompilerOptions().IsIncremental();
	}

	function writeFile(orchestrator:Orchestrator, fileName:std.String, text:std.String, data:Null<WriteFileData>):Null<Error> {
		final err = orchestrator.host.FS().WriteFile(fileName, text);
		if (err == null) {
			if (data != null && data.BuildInfo != null) {
				this.onBuildInfoEmit(orchestrator, fileName, (cast data.BuildInfo : BuildInfo), this.result.program.HasChangedDtsFile());
			} else if (this.storeOutputTimeStamp(orchestrator)) {
				// Store time stamps
				orchestrator.host.storeMTime(fileName, orchestrator.opts.Sys.Now());
			}
		}
		return err;
	}
}
