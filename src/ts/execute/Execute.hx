package ts.execute;

// Port of internal/execute/tsc.go (package execute).
// PORT: watcher.go (watch mode) is not ported; see the PORT notes.
class Execute {
	static function startTracingIfNeeded(sys:System, config:ParsedCommandLine, testing:Null<CommandLineTesting>):Null<Tracing> {
		final traceDir = config.CompilerOptions().GenerateTrace;
		if (traceDir == "") {
			return null;
		}
		var configFilePath = "";
		if (config.ConfigFile != null && config.ConfigFile.SourceFile != null) {
			configFilePath = config.ConfigFile.SourceFile.FileName();
		}
		final r = Tracing.StartTracing(sys.FS(), traceDir, configFilePath, testing != null);
		final tr = r.value, err = r.err;
		if (err != null) {
			Fmt.Fprintf(sys.Writer(), "Warning: Failed to start tracing: %v\n", [err.Error()]);
		}
		return tr;
	}

	static function stopTracing(sys:System, tr:Null<Tracing>):Void {
		if (tr == null) {
			return;
		}
		final err = tr.StopTracing();
		if (err != null) {
			Fmt.Fprintf(sys.Writer(), "Warning: Failed to stop tracing: %v\n", [err.Error()]);
		}
	}

	public static function CommandLine(ctx:Context, sys:System, commandLineArgs:Null<Array<std.String>>, testing:Null<CommandLineTesting>):CommandLineResult {
		if (Core.len(commandLineArgs) > 0) {
			switch (Strings.ToLower(commandLineArgs[0])) {
				case "-b", "--b", "-build", "--build":
					return tscBuildCompilation(ctx, sys, Tsoptions.ParseBuildCommandLine(commandLineArgs, sys), testing);
				// case "-f":
				// 	return fmtMain(sys, commandLineArgs[1], commandLineArgs[1])
				default:
			}
		}

		return tscCompilation(ctx, sys, Tsoptions.ParseCommandLine(commandLineArgs, sys), testing);
	}

	// PORT: skipped, needs internal/format (fmtMain is only referenced from a commented-out case).

	static function tscBuildCompilation(ctx:Context, sys:System, buildCommand:ParsedBuildCommandLine, testing:Null<CommandLineTesting>):CommandLineResult {
		final locale = buildCommand.Locale();
		final reportDiagnostic = Tsc.CreateDiagnosticReporter(sys, sys.Writer(), locale, buildCommand.CompilerOptions);

		if (Core.len(buildCommand.Errors) > 0) {
			for (err in buildCommand.Errors) {
				reportDiagnostic(err);
			}
			return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
		}

		// PORT: skipped, pprof (PprofDir) — no CPU/memory profiler on JS/hxcpp.

		if (buildCommand.CompilerOptions.Help.IsTrue()) {
			Tsc.PrintVersion(sys, locale);
			Tsc.PrintBuildHelp(sys, locale, Tsoptions.BuildOpts);
			return new CommandLineResult(ExitStatusSuccess);
		}

		final options = new ts.execute.build.Orchestrator.Options();
		options.Sys = sys;
		options.Command = buildCommand;
		options.Testing = testing;
		final orchestrator = Build.NewOrchestrator(options);
		return orchestrator.Start(ctx);
	}

	static function tscCompilation(ctx:Context, sys:System, commandLine:ParsedCommandLine, testing:Null<CommandLineTesting>):CommandLineResult {
		var configFileName = "";
		final locale = commandLine.Locale();
		var reportDiagnostic = Tsc.CreateDiagnosticReporter(sys, sys.Writer(), locale, commandLine.CompilerOptions());

		if (Core.len(commandLine.Errors) > 0) {
			for (e in commandLine.Errors) {
				reportDiagnostic(e);
			}
			return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
		}

		// PORT: skipped, pprof (PprofDir) — no CPU/memory profiler on JS/hxcpp.

		if (commandLine.CompilerOptions().Init.IsTrue()) {
			Tsc.WriteConfigFile(sys, locale, reportDiagnostic, (commandLine.Raw : OrderedMap<std.String, Dynamic>));
			return new CommandLineResult(ExitStatusSuccess);
		}

		if (commandLine.CompilerOptions().Version.IsTrue()) {
			Tsc.PrintVersion(sys, locale);
			return new CommandLineResult(ExitStatusSuccess);
		}

		if (commandLine.CompilerOptions().Help.IsTrue() || commandLine.CompilerOptions().All.IsTrue()) {
			Tsc.PrintHelp(sys, locale, commandLine);
			return new CommandLineResult(ExitStatusSuccess);
		}

		if (commandLine.CompilerOptions().Watch.IsTrue() && commandLine.CompilerOptions().ListFilesOnly.IsTrue()) {
			reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.Options_0_and_1_cannot_be_combined, "watch", "listFilesOnly"));
			return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
		}

		if (commandLine.CompilerOptions().Project != "") {
			if (Core.len(commandLine.FileNames()) != 0) {
				reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.Option_project_cannot_be_mixed_with_source_files_on_a_command_line));
				return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
			}

			final fileOrDirectory = Tspath.NormalizePath(commandLine.CompilerOptions().Project);
			if (sys.FS().DirectoryExists(fileOrDirectory)) {
				configFileName = Tspath.CombinePaths(fileOrDirectory, "tsconfig.json");
				if (!sys.FS().FileExists(configFileName)) {
					reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.Cannot_find_a_tsconfig_json_file_at_the_current_directory_Colon_0, configFileName));
					return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
				}
			} else {
				configFileName = fileOrDirectory;
				if (!sys.FS().FileExists(configFileName)) {
					reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.The_specified_path_does_not_exist_Colon_0, fileOrDirectory));
					return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
				}
			}
		} else if (!commandLine.CompilerOptions().IgnoreConfig.IsTrue() || Core.len(commandLine.FileNames()) == 0) {
			final searchPath = Tspath.NormalizePath(sys.GetCurrentDirectory());
			configFileName = findConfigFile(searchPath, sys.FS().FileExists, "tsconfig.json");
			if (Core.len(commandLine.FileNames()) != 0) {
				if (configFileName != "") {
					// Error to not specify config file
					reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.X_tsconfig_json_is_present_but_will_not_be_loaded_if_files_are_specified_on_commandline_Use_ignoreConfig_to_skip_this_error));
					return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
				}
			} else if (configFileName == "") {
				if (commandLine.CompilerOptions().ShowConfig.IsTrue()) {
					reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.Cannot_find_a_tsconfig_json_file_at_the_current_directory_Colon_0,
						Tspath.NormalizePath(sys.GetCurrentDirectory())));
				} else {
					Tsc.PrintVersion(sys, locale);
					Tsc.PrintHelp(sys, locale, commandLine);
				}
				return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsSkipped);
			}
		}

		// !!! convert to options with absolute paths is usually done here, but for ease of implementation, it's done in `tsoptions.ParseCommandLine()`
		final compilerOptionsFromCommandLine = commandLine.CompilerOptions();
		var configForCompilation = commandLine;
		final extendedConfigCache = new ExtendedConfigCache();
		final compileTimes = new CompileTimes();
		var commandLineRaw:Null<OrderedMap<std.String, Dynamic>> = null;
		if (configFileName != "") {
			final configStart = sys.Now();
			if (Std.isOfType(commandLine.Raw, OrderedMap)) {
				final raw:OrderedMap<std.String, Dynamic> = commandLine.Raw;
				// Wrap command line options in a "compilerOptions" key to match tsconfig.json structure
				final wrapped = new OrderedMap<std.String, Dynamic>();
				wrapped.Set("compilerOptions", raw);
				commandLineRaw = wrapped;
			}
			final r = Tsoptions.GetParsedCommandLineOfConfigFile(configFileName, compilerOptionsFromCommandLine, commandLineRaw, sys, extendedConfigCache);
			final configParseResult = r.a, errors = r.b;
			compileTimes.ConfigTime = sys.Now().Sub(configStart);
			if (Core.len(errors) != 0) {
				// these are unrecoverable errors--exit to report them as diagnostics
				for (e in errors) {
					reportDiagnostic(e);
				}
				return new CommandLineResult(ExitStatusDiagnosticsPresent_OutputsGenerated);
			}
			configForCompilation = configParseResult;
			// Updater to reflect pretty
			reportDiagnostic = Tsc.CreateDiagnosticReporter(sys, sys.Writer(), locale, commandLine.CompilerOptions());
		}

		final reportErrorSummary = Tsc.CreateReportErrorSummary(sys, locale, configForCompilation.CompilerOptions());
		if (compilerOptionsFromCommandLine.ShowConfig.IsTrue()) {
			showConfig(sys, configForCompilation, configFileName);
			return new CommandLineResult(ExitStatusSuccess);
		}
		if (configForCompilation.CompilerOptions().Watch.IsTrue()) {
			// PORT: skipped, watch mode (createWatcher / watcher.start, watcher.go).
			sys.Writer().Write("tsc --watch (watch mode) is not ported yet.\n");
			return new CommandLineResult(ExitStatusNotImplemented);
		} else if (configForCompilation.CompilerOptions().IsIncremental()) {
			return performIncrementalCompilation(sys, configForCompilation, reportDiagnostic, reportErrorSummary, extendedConfigCache, compileTimes, testing);
		}
		return performCompilation(sys, configForCompilation, reportDiagnostic, reportErrorSummary, extendedConfigCache, compileTimes, testing);
	}

	static function findConfigFile(searchPath:std.String, fileExists:(std.String) -> Bool, configName:std.String):std.String {
		final r = Tspath.ForEachAncestorDirectory(searchPath, function(ancestor:std.String):ValueOk<std.String> {
			final fullConfigName = Tspath.CombinePaths(ancestor, configName);
			if (fileExists(fullConfigName)) {
				return new ValueOk(fullConfigName, true);
			}
			return new ValueOk(fullConfigName, false);
		});
		if (!r.ok) {
			return "";
		}
		return r.value;
	}

	static function getTraceFromSys(sys:System, locale:Locale, testing:Null<CommandLineTesting>):TraceFunc {
		return Tsc.GetTraceWithWriterFromSys(sys.Writer(), locale, testing);
	}

	static function performIncrementalCompilation(sys:System, config:ParsedCommandLine, reportDiagnostic:DiagnosticReporter,
			reportErrorSummary:DiagnosticsReporter, extendedConfigCache:ts.tsoptions.Tsconfigparsing.ExtendedConfigCache, compileTimes:CompileTimes,
			testing:Null<CommandLineTesting>):CommandLineResult {
		final host = Compiler.NewCachedFSCompilerHost(sys.GetCurrentDirectory(), sys.FS(), sys.DefaultLibraryPath(), extendedConfigCache,
			getTraceFromSys(sys, config.Locale(), testing));
		final buildInfoReadStart = sys.Now();
		final oldProgram = Incremental.ReadBuildInfoProgram(config, Incremental.NewBuildInfoReader(host), host);
		compileTimes.BuildInfoReadTime = sys.Now().Sub(buildInfoReadStart);

		final tr = startTracingIfNeeded(sys, config, testing);

		final parseStart = sys.Now();
		final programOptions = new ProgramOptions();
		programOptions.Config = config;
		programOptions.Host = host;
		programOptions.Tracing = tr;
		final program = Compiler.NewProgram(programOptions);
		compileTimes.ParseTime = sys.Now().Sub(parseStart);
		final changesComputeStart = sys.Now();
		final incrementalProgram = Incremental.NewProgram(program, oldProgram, Incremental.CreateHost(host), testing != null);
		compileTimes.ChangesComputeTime = sys.Now().Sub(changesComputeStart);
		final emitInput = new EmitInput();
		emitInput.Sys = sys;
		emitInput.ProgramLike = incrementalProgram;
		emitInput.Program = incrementalProgram.GetProgram();
		emitInput.Config = config;
		emitInput.ReportDiagnostic = reportDiagnostic;
		emitInput.ReportErrorSummary = reportErrorSummary;
		emitInput.Writer = sys.Writer();
		emitInput.CompileTimes = compileTimes;
		emitInput.Testing = testing;
		emitInput.Tracing = tr;
		final result = Tsc.EmitAndReportStatistics(emitInput).a;

		stopTracing(sys, tr);

		if (testing != null) {
			testing.OnProgram(incrementalProgram);
		}
		return new CommandLineResult(result.Status);
	}

	static function performCompilation(sys:System, config:ParsedCommandLine, reportDiagnostic:DiagnosticReporter, reportErrorSummary:DiagnosticsReporter,
			extendedConfigCache:ts.tsoptions.Tsconfigparsing.ExtendedConfigCache, compileTimes:CompileTimes, testing:Null<CommandLineTesting>):CommandLineResult {
		final host = Compiler.NewCachedFSCompilerHost(sys.GetCurrentDirectory(), sys.FS(), sys.DefaultLibraryPath(), extendedConfigCache,
			getTraceFromSys(sys, config.Locale(), testing));

		final tr = startTracingIfNeeded(sys, config, testing);

		final parseStart = sys.Now();
		final programOptions = new ProgramOptions();
		programOptions.Config = config;
		programOptions.Host = host;
		programOptions.Tracing = tr;
		final program = Compiler.NewProgram(programOptions);
		compileTimes.ParseTime = sys.Now().Sub(parseStart);
		final emitInput = new EmitInput();
		emitInput.Sys = sys;
		emitInput.ProgramLike = program;
		emitInput.Program = program;
		emitInput.Config = config;
		emitInput.ReportDiagnostic = reportDiagnostic;
		emitInput.ReportErrorSummary = reportErrorSummary;
		emitInput.Writer = sys.Writer();
		emitInput.CompileTimes = compileTimes;
		emitInput.Testing = testing;
		emitInput.Tracing = tr;
		final result = Tsc.EmitAndReportStatistics(emitInput).a;

		stopTracing(sys, tr);

		return new CommandLineResult(result.Status);
	}

	static function showConfig(sys:System, config:ParsedCommandLine, configFileName:std.String):Void {
		final tsConfig = Tsoptions.ConvertToTSConfig(config, configFileName);
		// PORT: json.MarshalIndentWrite(w, v, "", "    ") → MarshalIndentOrdered + Write (no trailing newline).
		sys.Writer().Write(Json.MarshalIndentOrdered(tsConfig, "", "    "));
	}
}
