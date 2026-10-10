package ts.execute.tsc;

// Port of package internal/execute/tsc: package-level funcs of all files (types are in the module
// of their Go file: Compile.hx, Diagnostics_.hx, Emit.hx, Extendedconfigcache.hx, Help.hx, Statistics.hx).
@:allow(ts.execute)
class Tsc {
	// --- diagnostics.go ---

	static function getFormatOptsOfSys(sys:System, locale:Locale):FormattingOptions {
		final o = new FormattingOptions();
		o.NewLine = "\n";
		o.ComparePathsOptions = new ComparePathsOptions(sys.FS().UseCaseSensitiveFileNames(), sys.GetCurrentDirectory());
		o.Locale = locale;
		return o;
	}

	public static function QuietDiagnosticReporter(diagnostic:Diagnostic):Void {}

	public static function CreateDiagnosticReporter(sys:System, w:Writer, locale:Locale, options:CompilerOptions):DiagnosticReporter {
		if (options.Quiet.IsTrue()) {
			return QuietDiagnosticReporter;
		}
		final formatOpts = getFormatOptsOfSys(sys, locale);
		if (shouldBePretty(sys, options)) {
			return function(diagnostic:Diagnostic) {
				Diagnosticwriter.FormatDiagnosticWithColorAndContext(w, Diagnosticwriter.WrapASTDiagnostic(diagnostic), formatOpts);
				Fmt.Fprint(w, [formatOpts.NewLine]);
			};
		}
		return function(diagnostic:Diagnostic) {
			Diagnosticwriter.WriteFormatDiagnostic(w, Diagnosticwriter.WrapASTDiagnostic(diagnostic), formatOpts);
		};
	}

	static function defaultIsPretty(sys:System):Bool {
		if (sys.GetEnvironmentVariable("NO_COLOR") != "") {
			return false;
		}
		if (sys.GetEnvironmentVariable("FORCE_COLOR") != "") {
			return true;
		}
		return sys.WriteOutputIsTTY();
	}

	static function shouldBePretty(sys:System, options:Null<CompilerOptions>):Bool {
		if (options == null || options.Pretty.IsUnknown()) {
			return defaultIsPretty(sys);
		}
		return options.Pretty.IsTrue();
	}

	static function createColors(sys:System):Colors {
		if (!defaultIsPretty(sys)) {
			final c = new Colors();
			c.showColors = false;
			return c;
		}

		final os = sys.GetEnvironmentVariable("OS");
		final isWindows = Strings.ToLower(os).indexOf("windows") >= 0;
		final isWindowsTerminal = sys.GetEnvironmentVariable("WT_SESSION") != "";
		final isVSCode = sys.GetEnvironmentVariable("TERM_PROGRAM") == "vscode";
		final supportsRicherColors = sys.GetEnvironmentVariable("COLORTERM") == "truecolor" || sys.GetEnvironmentVariable("TERM") == "xterm-256color";

		final c = new Colors();
		c.showColors = true;
		c.isWindows = isWindows;
		c.isWindowsTerminal = isWindowsTerminal;
		c.isVSCode = isVSCode;
		c.supportsRicherColors = supportsRicherColors;
		return c;
	}

	public static function QuietDiagnosticsReporter(diagnostics:Null<Array<Diagnostic>>):Void {}

	public static function CreateReportErrorSummary(sys:System, locale:Locale, options:CompilerOptions):DiagnosticsReporter {
		if (shouldBePretty(sys, options)) {
			final formatOpts = getFormatOptsOfSys(sys, locale);
			return function(diagnostics:Null<Array<Diagnostic>>) {
				Diagnosticwriter.WriteErrorSummaryText(sys.Writer(), Diagnosticwriter.FromASTDiagnostics(diagnostics), formatOpts);
			};
		}
		return QuietDiagnosticsReporter;
	}

	public static function CreateBuilderStatusReporter(sys:System, w:Writer, locale:Locale, options:CompilerOptions,
			testing:Null<CommandLineTesting>):DiagnosticReporter {
		if (options.Quiet.IsTrue()) {
			return QuietDiagnosticReporter;
		}

		final formatOpts = getFormatOptsOfSys(sys, locale);
		final writeStatus = Core.IfElse(shouldBePretty(sys, options), Diagnosticwriter.FormatDiagnosticsStatusWithColorAndTime,
			Diagnosticwriter.FormatDiagnosticsStatusAndTime);
		return function(diagnostic:Diagnostic) {
			final writerDiagnostic = Diagnosticwriter.WrapASTDiagnostic(diagnostic);
			if (testing != null) {
				testing.OnBuildStatusReportStart(w);
			}
			writeStatus(w, formatClock(sys.Now()), writerDiagnostic, formatOpts);
			Fmt.Fprint(w, [formatOpts.NewLine, formatOpts.NewLine]);
			if (testing != null) {
				testing.OnBuildStatusReportEnd(w);
			}
		};
	}

	public static function CreateWatchStatusReporter(sys:System, locale:Locale, options:CompilerOptions, testing:Null<CommandLineTesting>):DiagnosticReporter {
		final formatOpts = getFormatOptsOfSys(sys, locale);
		final writeStatus = Core.IfElse(shouldBePretty(sys, options), Diagnosticwriter.FormatDiagnosticsStatusWithColorAndTime,
			Diagnosticwriter.FormatDiagnosticsStatusAndTime);
		return function(diagnostic:Diagnostic) {
			final writerDiagnostic = Diagnosticwriter.WrapASTDiagnostic(diagnostic);
			final writer = sys.Writer();
			if (testing != null) {
				testing.OnWatchStatusReportStart();
			}
			Diagnosticwriter.TryClearScreen(writer, writerDiagnostic, options);
			writeStatus(writer, formatClock(sys.Now()), writerDiagnostic, formatOpts);
			Fmt.Fprint(writer, [formatOpts.NewLine, formatOpts.NewLine]);
			if (testing != null) {
				testing.OnWatchStatusReportEnd();
			}
		};
	}

	// PORT: Go `t.Format("03:04:05 PM")` (local time) — go.Time has no Format.
	static function formatClock(t:Time):std.String {
		final d = Date.fromTime(Time.DurationFloat64(t.sec) * 1000.0);
		var h = d.getHours();
		final pm = h >= 12;
		h = h % 12;
		if (h == 0)
			h = 12;
		function two(n:Int):std.String
			return n < 10 ? "0" + n : "" + n;
		return two(h) + ":" + two(d.getMinutes()) + ":" + two(d.getSeconds()) + (pm ? " PM" : " AM");
	}

	// --- emit.go ---

	public static function GetTraceWithWriterFromSys(w:Writer, locale:Locale, testing:Null<CommandLineTesting>):TraceFunc {
		if (testing == null) {
			return function(msg:Message, args:Array<Any>) {
				w.Write(msg.Localize(locale, args) + "\n");
			};
		} else {
			return testing.GetTrace(w, locale);
		}
	}

	// PORT: (CompileAndEmitResult, *Statistics) → Pair.
	public static function EmitAndReportStatistics(input:EmitInput):Pair<CompileAndEmitResult, Null<Statistics>> {
		var statistics:Null<Statistics> = null;
		final result = EmitFilesAndReportErrors(input);
		if (result.Status != ExitStatusSuccess) {
			// compile exited early
			return new Pair(result, null);
		}
		result.times.totalTime = input.Sys.SinceStart();

		if (input.Config.CompilerOptions().Diagnostics.IsTrue() || input.Config.CompilerOptions().ExtendedDiagnostics.IsTrue()) {
			final memStats = new MemStats();
			// GC must be called twice to allow things to settle.
			Runtime.GC();
			Runtime.GC();
			Runtime.ReadMemStats(memStats);

			statistics = statisticsFromProgram(input, memStats);
			statistics.Report(input.Writer, input.Testing);
		}

		if (result.EmitResult.EmitSkipped && Core.len(result.Diagnostics) > 0) {
			result.Status = ExitStatusDiagnosticsPresent_OutputsSkipped;
		} else if (Core.len(result.Diagnostics) > 0) {
			result.Status = ExitStatusDiagnosticsPresent_OutputsGenerated;
		}
		return new Pair(result, statistics);
	}

	public static function EmitFilesAndReportErrors(input:EmitInput):CompileAndEmitResult {
		final result = new CompileAndEmitResult();
		result.times = input.CompileTimes;
		final ctx = Context.Background();

		var allDiagnostics:Array<Diagnostic> = Compiler.GetDiagnosticsOfAnyProgram(ctx, input.ProgramLike, null, false, function(ctx:Context, file:SourceFile):Array<Diagnostic> {
			// Options diagnostics include global diagnostics (even though we collect them separately),
			// and global diagnostics create checkers, which then bind all of the files. Do this binding
			// early so we can track the time.
			final tr = input.Tracing;
			final pop = tr != null ? tr.Push(PhaseBind, "bindSourceFiles", null, true) : null;
			final bindStart = input.Sys.Now();
			final diags = input.ProgramLike.GetBindDiagnostics(ctx, file);
			result.times.bindTime = input.Sys.Now().Sub(bindStart);
			if (pop != null)
				pop();
			return diags;
		}, function(ctx:Context, file:SourceFile):Array<Diagnostic> {
			final tr = input.Tracing;
			final pop = tr != null ? tr.Push(PhaseCheck, "checkSourceFiles", null, true) : null;
			final checkStart = input.Sys.Now();
			final diags = input.ProgramLike.GetSemanticDiagnostics(ctx, file);
			result.times.checkTime = input.Sys.Now().Sub(checkStart);
			if (pop != null)
				pop();
			return diags;
		});

		var emitResult = new EmitResult();
		emitResult.EmitSkipped = true;
		emitResult.Diagnostics = [];
		if (!input.ProgramLike.Options().ListFilesOnly.IsTrue()) {
			final emitStart = input.Sys.Now();
			final emitOptions = new EmitOptions();
			emitOptions.WriteFile = input.WriteFile;
			emitResult = input.ProgramLike.Emit(ctx, emitOptions);
			result.times.emitTime = input.Sys.Now().Sub(emitStart);
		}
		if (emitResult != null) {
			// PORT: `append(allDiagnostics, ...)` — allDiagnostics is owned here (a fresh slice).
			if (Core.len(emitResult.Diagnostics) > 0) {
				if (allDiagnostics == null)
					allDiagnostics = [];
				for (d in emitResult.Diagnostics)
					allDiagnostics.push(d);
			}
		}
		if (input.Testing != null) {
			input.Testing.OnEmittedFiles(emitResult, input.TestingMTimesCache);
		}

		allDiagnostics = Compiler.SortAndDeduplicateDiagnostics(allDiagnostics);
		for (diagnostic in allDiagnostics) {
			input.ReportDiagnostic(diagnostic);
		}

		listFiles(input, emitResult);

		input.ReportErrorSummary(allDiagnostics);
		result.Diagnostics = allDiagnostics;
		result.EmitResult = emitResult;
		result.Status = ExitStatusSuccess;
		return result;
	}

	static function listFiles(input:EmitInput, emitResult:EmitResult):Void {
		if (input.Testing != null) {
			input.Testing.OnListFilesStart(input.Writer);
		}
		final options = input.Program.Options();
		if (options.ListEmittedFiles.IsTrue()) {
			for (file in emitResult.EmittedFiles) {
				input.Writer.Write("TSFILE: " + Tspath.GetNormalizedAbsolutePath(file, input.Program.GetCurrentDirectory()) + "\n");
			}
		}
		if (options.ExplainFiles.IsTrue()) {
			input.Program.ExplainFiles(input.Writer, input.Config.Locale());
		} else if (options.ListFiles.IsTrue() || options.ListFilesOnly.IsTrue()) {
			for (file in input.Program.GetSourceFiles()) {
				input.Writer.Write(file.FileName() + "\n");
			}
		}
		if (input.Testing != null) {
			input.Testing.OnListFilesEnd(input.Writer);
		}
	}

	// --- help.go ---

	public static function PrintVersion(sys:System, locale:Locale):Void {
		sys.Writer().Write(Diagnostics.Version_0.Localize(locale, [Core.Version()]) + "\n");
	}

	public static function PrintHelp(sys:System, locale:Locale, commandLine:ParsedCommandLine):Void {
		if (commandLine.CompilerOptions().All.IsFalseOrUnknown()) {
			printEasyHelp(sys, locale, getOptionsForHelp(commandLine));
		} else {
			printAllHelp(sys, locale, getOptionsForHelp(commandLine));
		}
	}

	static function getOptionsForHelp(commandLine:ParsedCommandLine):Array<CommandLineOption> {
		// Sort our options by their names, (e.g. "--noImplicitAny" comes before "--watch")
		final opts = Slices.Clone(Tsoptions.OptionsDeclarations);
		opts.push(Tsoptions.TscBuildOption);

		if (commandLine.CompilerOptions().All.IsTrue()) {
			Slices.SortFunc(opts, function(a:CommandLineOption, b:CommandLineOption):Int {
				return Strings.Compare(Strings.ToLower(a.Name), Strings.ToLower(b.Name));
			});
			return opts;
		} else {
			return Core.Filter(opts, function(opt:CommandLineOption):Bool {
				return opt.ShowInSimplifiedHelpView;
			});
		}
	}

	static function getHeader(sys:System, message:std.String):Array<std.String> {
		final colors = createColors(sys);
		final header:Array<std.String> = [];
		final terminalWidth = sys.GetWidthOfTerminal();
		final tsIcon = "     ";
		final tsIconTS = "  TS ";
		final tsIconLength = tsIcon.length;

		final tsIconFirstLine = colors.blueBackground(tsIcon);
		final tsIconSecondLine = colors.blueBackground(colors.brightWhite(tsIconTS));
		// If we have enough space, print TS icon.
		// PORT: byte — len(message) counts UTF-8 bytes in Go.
		if (terminalWidth >= Utf8.ByteLen(message) + tsIconLength) {
			// right align of the icon is 120 at most.
			final rightAlign = Core.IfElse(terminalWidth > 120, 120, terminalWidth);
			final leftAlign = rightAlign - tsIconLength;
			header.push(Fmt.Sprintf("%-*s", [leftAlign, message]));
			header.push(tsIconFirstLine);
			header.push("\n");
			header.push(Strings.Repeat(" ", leftAlign));
			header.push(tsIconSecondLine);
			header.push("\n");
		} else {
			header.push(message);
			header.push("\n");
			header.push("\n");
		}
		return header;
	}

	static function printEasyHelp(sys:System, locale:Locale, simpleOptions:Array<CommandLineOption>):Void {
		final colors = createColors(sys);
		var output:Array<std.String> = [];
		final example = function(examples:Array<std.String>, desc:Message) {
			for (example in examples) {
				output.push("  ");
				output.push(colors.blue(example));
				output.push("\n");
			}
			output.push("  ");
			output.push(desc.Localize(locale, []));
			output.push("\n");
			output.push("\n");
		};

		final msg = Diagnostics.X_tsc_Colon_The_TypeScript_Compiler.Localize(locale, []) + " - "
			+ Diagnostics.Version_0.Localize(locale, [Core.Version()]);
		output = output.concat(getHeader(sys, msg));

		output.push(colors.bold(Diagnostics.COMMON_COMMANDS.Localize(locale, [])));
		output.push("\n");
		output.push("\n");

		example(["tsc"], Diagnostics.Compiles_the_current_project_tsconfig_json_in_the_working_directory);
		example(["tsc app.ts util.ts"], Diagnostics.Ignoring_tsconfig_json_compiles_the_specified_files_with_default_compiler_options);
		example(["tsc -b"], Diagnostics.Build_a_composite_project_in_the_working_directory);
		example(["tsc --init"], Diagnostics.Creates_a_tsconfig_json_with_the_recommended_settings_in_the_working_directory);
		example(["tsc -p ./path/to/tsconfig.json"], Diagnostics.Compiles_the_TypeScript_project_located_at_the_specified_path);
		example(["tsc --help --all"], Diagnostics.An_expanded_version_of_this_information_showing_all_possible_compiler_options);
		example(["tsc --noEmit", "tsc --target esnext"], Diagnostics.Compiles_the_current_project_with_additional_settings);

		var cliCommands:Array<CommandLineOption> = null;
		var configOpts:Array<CommandLineOption> = null;
		for (opt in simpleOptions) {
			if (opt.IsCommandLineOnly || opt.Category == Diagnostics.Command_line_Options) {
				if (cliCommands == null)
					cliCommands = [];
				cliCommands.push(opt);
			} else {
				if (configOpts == null)
					configOpts = [];
				configOpts.push(opt);
			}
		}

		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.COMMAND_LINE_FLAGS.Localize(locale, []), cliCommands /*subCategory*/,
			false /*beforeOptionsDescription*/, null /*afterOptionsDescription*/, null));

		final after = Diagnostics.You_can_learn_about_all_of_the_compiler_options_at_0.Localize(locale, ["https://aka.ms/tsc"]);
		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.COMMON_COMPILER_OPTIONS.Localize(locale, []), configOpts /*subCategory*/,
			false /*beforeOptionsDescription*/, null, after));

		for (chunk in output) {
			Fmt.Fprint(sys.Writer(), [chunk]);
		}
	}

	static function printAllHelp(sys:System, locale:Locale, options:Array<CommandLineOption>):Void {
		var output:Array<std.String> = [];
		final msg = Diagnostics.X_tsc_Colon_The_TypeScript_Compiler.Localize(locale, []) + " - "
			+ Diagnostics.Version_0.Localize(locale, [Core.Version()]);
		output = output.concat(getHeader(sys, msg));

		// ALL COMPILER OPTIONS section
		final afterCompilerOptions = Diagnostics.You_can_learn_about_all_of_the_compiler_options_at_0.Localize(locale, ["https://aka.ms/tsc"]);
		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.ALL_COMPILER_OPTIONS.Localize(locale, []), options, true, null,
			afterCompilerOptions));

		// WATCH OPTIONS section
		final beforeWatchOptions = Diagnostics.Including_watch_w_will_start_watching_the_current_project_for_the_file_changes_Once_set_you_can_config_watch_mode_with_Colon.Localize(locale,
			[]);
		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.WATCH_OPTIONS.Localize(locale, []), Tsoptions.OptionsForWatch, false,
			beforeWatchOptions, null));

		// BUILD OPTIONS section
		final beforeBuildOptions = Diagnostics.Using_build_b_will_make_tsc_behave_more_like_a_build_orchestrator_than_a_compiler_This_is_used_to_trigger_building_composite_projects_which_you_can_learn_more_about_at_0.Localize(locale,
			["https://aka.ms/tsc-composite-builds"]);
		final buildOptions = Core.Filter(Tsoptions.OptionsForBuild, function(option:CommandLineOption):Bool {
			return option != Tsoptions.TscBuildOption;
		});
		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.BUILD_OPTIONS.Localize(locale, []), buildOptions, false,
			beforeBuildOptions, null));

		for (chunk in output) {
			Fmt.Fprint(sys.Writer(), [chunk]);
		}
	}

	public static function PrintBuildHelp(sys:System, locale:Locale, buildOptions:Array<CommandLineOption>):Void {
		var output:Array<std.String> = [];
		output = output.concat(getHeader(sys,
			Diagnostics.X_tsc_Colon_The_TypeScript_Compiler.Localize(locale, []) + " - " + Diagnostics.Version_0.Localize(locale, [Core.Version()])));
		final before = Diagnostics.Using_build_b_will_make_tsc_behave_more_like_a_build_orchestrator_than_a_compiler_This_is_used_to_trigger_building_composite_projects_which_you_can_learn_more_about_at_0.Localize(locale,
			["https://aka.ms/tsc-composite-builds"]);
		final options = Core.Filter(buildOptions, function(option:CommandLineOption):Bool {
			return option != Tsoptions.TscBuildOption;
		});
		output = output.concat(generateSectionOptionsOutput(sys, locale, Diagnostics.BUILD_OPTIONS.Localize(locale, []), options, false, before, null));

		for (chunk in output) {
			Fmt.Fprint(sys.Writer(), [chunk]);
		}
	}

	// PORT: `beforeOptionsDescription, afterOptionsDescription *string` → Null<String> (nil → null).
	static function generateSectionOptionsOutput(sys:System, locale:Locale, sectionName:std.String, options:Null<Array<CommandLineOption>>,
			subCategory:Bool, beforeOptionsDescription:Null<std.String>, afterOptionsDescription:Null<std.String>):Array<std.String> {
		var output:Array<std.String> = [];
		output.push(createColors(sys).bold(sectionName));
		output.push("\n");
		output.push("\n");

		if (beforeOptionsDescription != null) {
			output.push(beforeOptionsDescription);
			output.push("\n");
			output.push("\n");
		}
		if (!subCategory) {
			output = output.concat(generateGroupOptionOutput(sys, locale, options));
			if (afterOptionsDescription != null) {
				output.push(afterOptionsDescription);
				output.push("\n");
				output.push("\n");
			}
			return output;
		}
		final categoryMap = new StringMap<Array<CommandLineOption>>();
		final categoryOrder:Array<std.String> = [];
		for (option in options) {
			if (option.Category == null) {
				continue;
			}
			final curCategory = option.Category.Localize(locale, []);
			if (!categoryMap.exists(curCategory)) {
				categoryOrder.push(curCategory);
				categoryMap.set(curCategory, []);
			}
			categoryMap.get(curCategory).push(option);
		}
		for (key in categoryOrder) {
			final value = categoryMap.get(key);
			output.push("### ");
			output.push(key);
			output.push("\n");
			output.push("\n");
			output = output.concat(generateGroupOptionOutput(sys, locale, value));
		}
		if (afterOptionsDescription != null) {
			output.push(afterOptionsDescription);
			output.push("\n");
			output.push("\n");
		}

		return output;
	}

	static function generateGroupOptionOutput(sys:System, locale:Locale, optionsList:Null<Array<CommandLineOption>>):Array<std.String> {
		var maxLength = 0;
		for (option in optionsList) {
			final curLenght = getDisplayNameTextOfOption(option).length;
			maxLength = curLenght > maxLength ? curLenght : maxLength;
		}

		// left part should be right align, right part should be left align

		// assume 2 space between left margin and left part.
		final rightAlignOfLeftPart = maxLength + 2;
		// assume 2 space between left and right part
		final leftAlignOfRightPart = rightAlignOfLeftPart + 2;

		final lines:Array<std.String> = [];
		for (option in optionsList) {
			final tmp = generateOptionOutput(sys, locale, option, rightAlignOfLeftPart, leftAlignOfRightPart);
			for (x in tmp)
				lines.push(x);
		}

		// make sure always a blank line in the end.
		if (lines.length < 2 || lines[lines.length - 2] != "\n") {
			lines.push("\n");
		}

		return lines;
	}

	static function generateOptionOutput(sys:System, locale:Locale, option:CommandLineOption, rightAlignOfLeft:Int, leftAlignOfRight:Int):Array<std.String> {
		final text:Array<std.String> = [];
		final colors = createColors(sys);

		// name and description
		final name = getDisplayNameTextOfOption(option);

		// value type and possible value
		final valueCandidates = getValueCandidate(sys, locale, option);

		var defaultValueDescription:std.String;
		if (Std.isOfType(option.DefaultValueDescription, Message) && option.DefaultValueDescription != null) {
			final msg:Message = option.DefaultValueDescription;
			defaultValueDescription = msg.Localize(locale, []);
		} else {
			defaultValueDescription = formatDefaultValue(option.DefaultValueDescription,
				Core.IfElse(option.Kind == CommandLineOptionTypeList || option.Kind == CommandLineOptionTypeListOrElement, option.Elements(), option), option);
		}

		final terminalWidth = sys.GetWidthOfTerminal();

		if (terminalWidth >= 80) {
			var description = "";
			if (option.Description != null) {
				description = option.Description.Localize(locale, []);
			}
			for (x in getPrettyOutput(colors, name, description, rightAlignOfLeft, leftAlignOfRight, terminalWidth, true /*colorLeft*/))
				text.push(x);
			text.push("\n");
			if (showAdditionalInfoOutput(valueCandidates, option)) {
				if (valueCandidates != null) {
					for (x in getPrettyOutput(colors, valueCandidates.valueType, valueCandidates.possibleValues, rightAlignOfLeft, leftAlignOfRight,
						terminalWidth, false /*colorLeft*/))
						text.push(x);
					text.push("\n");
				}
				if (defaultValueDescription != "") {
					for (x in getPrettyOutput(colors, Diagnostics.X_default_Colon.Localize(locale, []), defaultValueDescription, rightAlignOfLeft,
						leftAlignOfRight, terminalWidth, false /*colorLeft*/))
						text.push(x);
					text.push("\n");
				}
			}
			text.push("\n");
		} else {
			text.push(colors.blue(name));
			text.push("\n");
			if (option.Description != null) {
				text.push(option.Description.Localize(locale, []));
			}
			text.push("\n");
			if (showAdditionalInfoOutput(valueCandidates, option)) {
				if (valueCandidates != null) {
					text.push(valueCandidates.valueType);
					text.push(" ");
					text.push(valueCandidates.possibleValues);
				}
				if (defaultValueDescription != "") {
					if (valueCandidates != null) {
						text.push("\n");
					}
					text.push(Diagnostics.X_default_Colon.Localize(locale, []));
					text.push(" ");
					text.push(defaultValueDescription);
				}

				text.push("\n");
			}
			text.push("\n");
		}

		return text;
	}

	// PORT: Go compares `defaultValue == core.TSUnknown` (an `any` holding a core.Tristate). In Haxe
	// TSUnknown is the Int 0 at run time, like the int default 0 of maxNodeModuleJsDepth. The
	// Tristate default TSUnknown is only used on non-number options, so `declOption` (the declared
	// option, before Elements()) decides: Int 0 on a number option is the number 0.
	static function formatDefaultValue(defaultValue:Dynamic, option:CommandLineOption, declOption:CommandLineOption):std.String {
		if (defaultValue == null || (Std.isOfType(defaultValue, Int) && (defaultValue : Int) == 0 && declOption.Kind != CommandLineOptionTypeNumber)) {
			return "undefined";
		}

		if (option.Kind == CommandLineOptionTypeEnum) {
			// e.g. ScriptTarget.ES2015 -> "es6/es2015"
			final names:Array<std.String> = [];
			for (name => value in option.EnumMap().Entries()) {
				if (value == defaultValue) {
					names.push(name);
				}
			}
			return names.join("/");
		}
		return Fmt.Sprintv(defaultValue);
	}

	static function showAdditionalInfoOutput(valueCandidates:Null<ValueCandidate>, option:CommandLineOption):Bool {
		if (option.Category == Diagnostics.Command_line_Options) {
			return false;
		}
		if (valueCandidates != null
			&& valueCandidates.possibleValues == "string"
			&& (option.DefaultValueDescription == null
				|| isStringValue(option.DefaultValueDescription, "false")
				|| isStringValue(option.DefaultValueDescription, "n/a"))) {
			return false;
		}
		return true;
	}

	// PORT: Go `any == "false"` is true only for a string value.
	static function isStringValue(v:Dynamic, s:std.String):Bool {
		return Std.isOfType(v, std.String) && (v : std.String) == s;
	}

	static function getValueCandidate(sys:System, locale:Locale, option:CommandLineOption):Null<ValueCandidate> {
		// option.type might be "string" | "number" | "boolean" | "object" | "list" | Map<string, number | string>
		// string -- any of: string
		// number -- any of: number
		// boolean -- any of: boolean
		// object -- null
		// list -- one or more: , content depends on `option.element.type`, the same as others
		// Map<string, number | string> -- any of: key1, key2, ....
		if (option.Kind == CommandLineOptionTypeObject) {
			return null;
		}

		final res = new ValueCandidate();
		if (option.Kind == CommandLineOptionTypeListOrElement) {
			// assert(option.type !== "listOrElement")
			throw "no value candidate for list or element";
		}

		if (option.Kind == CommandLineOptionTypeString || option.Kind == CommandLineOptionTypeNumber || option.Kind == CommandLineOptionTypeBoolean) {
			res.valueType = Diagnostics.X_type_Colon.Localize(locale, []);
		} else if (option.Kind == CommandLineOptionTypeList) {
			res.valueType = Diagnostics.X_one_or_more_Colon.Localize(locale, []);
		} else {
			res.valueType = Diagnostics.X_one_of_Colon.Localize(locale, []);
		}

		res.possibleValues = getPossibleValues(option);

		return res;
	}

	static function getPossibleValues(option:CommandLineOption):std.String {
		if (option.Kind == CommandLineOptionTypeString || option.Kind == CommandLineOptionTypeNumber || option.Kind == CommandLineOptionTypeBoolean) {
			return (option.Kind : std.String);
		} else if (option.Kind == CommandLineOptionTypeList || option.Kind == CommandLineOptionTypeListOrElement) {
			return getPossibleValues(option.Elements());
		} else if (option.Kind == CommandLineOptionTypeObject) {
			return "";
		} else {
			// Map<string, number | string>
			// Group synonyms: es6/es2015
			final enumMap = option.EnumMap();
			final inverted = new OrderedMap<Dynamic, Array<std.String>>();
			final deprecatedKeys = option.DeprecatedKeys();

			for (name => value in enumMap.Entries()) {
				if (deprecatedKeys == null || !deprecatedKeys.Has(name)) {
					var names = inverted.GetOrZero(value);
					if (names == null)
						names = [];
					names.push(name);
					inverted.Set(value, names);
				}
			}
			final syns:Array<std.String> = [];
			for (synonyms in inverted.Values()) {
				syns.push(synonyms.join("/"));
			}
			return syns.join(", ");
		}
	}

	static function getPrettyOutput(colors:Colors, left:std.String, right:std.String, rightAlignOfLeft:Int, leftAlignOfRight:Int, terminalWidth:Int,
			colorLeft:Bool):Array<std.String> {
		// !!! How does terminalWidth interact with UTF-8 encoding? Strada just assumed UTF-16.
		// PORT: byte — Go slices `right` at UTF-8 byte offsets; the English messages are ASCII, so
		// UTF-16 code units give the same cut.
		final res:Array<std.String> = [];
		var isFirstLine = true;
		var remainRight = right;
		final rightCharacterNumber = terminalWidth - leftAlignOfRight;
		while (remainRight.length > 0) {
			var curLeft = "";
			if (isFirstLine) {
				curLeft = Fmt.Sprintf("%*s", [rightAlignOfLeft, left]);
				curLeft = Fmt.Sprintf("%-*s", [leftAlignOfRight, curLeft]);
				if (colorLeft) {
					curLeft = colors.blue(curLeft);
				}
			} else {
				curLeft = Strings.Repeat(" ", leftAlignOfRight);
			}

			final idx = rightCharacterNumber < remainRight.length ? rightCharacterNumber : remainRight.length;
			final curRight = remainRight.substring(0, idx);
			remainRight = remainRight.substring(idx);
			res.push(curLeft);
			res.push(curRight);
			res.push("\n");
			isFirstLine = false;
		}
		return res;
	}

	static function getDisplayNameTextOfOption(option:CommandLineOption):std.String {
		return "--" + option.Name + Core.IfElse(option.ShortName != "", ", -" + option.ShortName, "");
	}

	// --- init.go ---

	public static function WriteConfigFile(sys:System, locale:Locale, reportDiagnostic:DiagnosticReporter, options:OrderedMap<std.String, Dynamic>):Void {
		final getCurrentDirectory = sys.GetCurrentDirectory();
		final file = Tspath.NormalizePath(Tspath.CombinePaths(getCurrentDirectory, "tsconfig.json"));
		if (sys.FS().FileExists(file)) {
			reportDiagnostic(Ast.NewCompilerDiagnostic(Diagnostics.A_tsconfig_json_file_is_already_defined_at_Colon_0, file));
		} else {
			sys.FS().WriteFile(file, generateTSConfig(options, locale));
			var output = ["\n"];
			output = output.concat(getHeader(sys, "Created a new tsconfig.json"));
			output.push("You can learn more at https://aka.ms/tsconfig");
			output.push("\n");
			Fmt.Fprint(sys.Writer(), [output.join("")]);
		}
	}

	static function generateTSConfig(options:OrderedMap<std.String, Dynamic>, locale:Locale):std.String {
		final tab = "  ";
		final result:Array<std.String> = [];

		var allSetOptions:Array<std.String> = [];
		for (k in options.Keys()) {
			if (k != "init" && k != "help" && k != "watch") {
				allSetOptions.push(k);
			}
		}

		final emitHeader = function(header:Message) {
			result.push(tab + tab + "// " + header.Localize(locale, []));
		};
		final newline = function() {
			result.push("");
		};
		final push = function(args:Array<std.String>) {
			for (a in args)
				result.push(a);
		};

		final formatSingleValue = function(value:Dynamic, enumMap:Null<OrderedMap<std.String, Dynamic>>):std.String {
			if (enumMap != null) {
				var found = false;
				for (k => v in enumMap.Entries()) {
					if (value == v) {
						value = k;
						found = true;
						break;
					}
				}
				if (!found) {
					throw Fmt.Sprintf("No matching value of %v", [value]);
				}
			}

			return Json.MarshalOrdered(value);
		};

		final formatValueOrArray = function(settingName:std.String, value:Dynamic):std.String {
			var option:CommandLineOption = null;
			for (decl in Tsoptions.OptionsDeclarations) {
				if (decl.Name == settingName) {
					option = decl;
				}
			}
			if (option == null) {
				throw "No option named " + settingName;
			}

			if (Std.isOfType(value, Array)) {
				var enumMap:Null<OrderedMap<std.String, Dynamic>> = null;
				final elemOption = option.Elements();
				if (elemOption != null) {
					enumMap = elemOption.EnumMap();
				}

				final elems:Array<std.String> = [];
				final rval:Array<Dynamic> = value;
				for (i in 0...rval.length) {
					elems.push(formatSingleValue(rval[i], enumMap));
				}
				return "[" + elems.join(", ") + "]";
			} else {
				return formatSingleValue(value, option.EnumMap());
			}
		};

		// commentedNever': Never comment this out
		// commentedAlways': Always comment this out, even if it's on commandline
		// commentedOptional': Comment out unless it's on commandline
		final commentedNever = 0;
		final commentedAlways = 1;
		final commentedOptional = 2;
		final emitOption = function(setting:std.String, defaultValue:Dynamic, commented:Int) {
			if (commented > 2) {
				throw "should not happen: invalid `commented`, must be a bug.";
			}

			final existingOptionIndex = allSetOptions.indexOf(setting);
			if (existingOptionIndex >= 0) {
				allSetOptions.splice(existingOptionIndex, 1);
			}

			var comment:Bool;
			if (commented == commentedAlways) {
				comment = true;
			} else if (commented == commentedNever) {
				comment = false;
			} else {
				comment = !options.Has(setting);
			}

			final r = options.Get(setting);
			var value:Dynamic = r.value;
			if (!r.ok) {
				value = defaultValue;
			}

			if (comment) {
				push([tab + tab + "// \"" + setting + "\": " + formatValueOrArray(setting, value) + ","]);
			} else {
				push([tab + tab + "\"" + setting + "\": " + formatValueOrArray(setting, value) + ","]);
			}
		};

		push(["{"]);
		push([tab + "// " + Diagnostics.Visit_https_Colon_Slash_Slashaka_ms_Slashtsconfig_to_read_more_about_this_file.Localize(locale, [])]);
		push([tab + "\"compilerOptions\": {"]);

		emitHeader(Diagnostics.File_Layout);
		emitOption("rootDir", "./src", commentedOptional);
		emitOption("outDir", "./dist", commentedOptional);

		newline();

		emitHeader(Diagnostics.Environment_Settings);
		emitHeader(Diagnostics.See_also_https_Colon_Slash_Slashaka_ms_Slashtsconfig_Slashmodule);
		emitOption("module", ModuleKindNodeNext, commentedNever);
		emitOption("target", ScriptTargetESNext, commentedNever);
		emitOption("types", ([] : Array<Dynamic>), commentedNever);
		final lib = options.Get("lib");
		if (lib.ok) {
			emitOption("lib", lib.value, commentedNever);
		}
		emitHeader(Diagnostics.For_nodejs_Colon);
		push([tab + tab + "// \"lib\": [\"esnext\"],"]);
		push([tab + tab + "// \"types\": [\"node\"],"]);
		emitHeader(Diagnostics.X_and_npm_install_D_types_Slashnode);

		newline();

		emitHeader(Diagnostics.Other_Outputs);
		emitOption("sourceMap" /*defaultValue*/, true, commentedNever);
		emitOption("declaration" /*defaultValue*/, true, commentedNever);
		emitOption("declarationMap" /*defaultValue*/, true, commentedNever);

		newline();

		emitHeader(Diagnostics.Stricter_Typechecking_Options);
		emitOption("noUncheckedIndexedAccess" /*defaultValue*/, true, commentedNever);
		emitOption("exactOptionalPropertyTypes" /*defaultValue*/, true, commentedNever);

		newline();

		emitHeader(Diagnostics.Style_Options);
		emitOption("noImplicitReturns" /*defaultValue*/, true, commentedOptional);
		emitOption("noImplicitOverride" /*defaultValue*/, true, commentedOptional);
		emitOption("noUnusedLocals" /*defaultValue*/, true, commentedOptional);
		emitOption("noUnusedParameters" /*defaultValue*/, true, commentedOptional);
		emitOption("noFallthroughCasesInSwitch" /*defaultValue*/, true, commentedOptional);
		emitOption("noPropertyAccessFromIndexSignature" /*defaultValue*/, true, commentedOptional);

		newline();

		emitHeader(Diagnostics.Recommended_Options);
		emitOption("strict" /*defaultValue*/, true, commentedNever);
		emitOption("jsx", JsxEmitReactJSX, commentedNever);
		emitOption("verbatimModuleSyntax" /*defaultValue*/, true, commentedNever);
		emitOption("isolatedModules" /*defaultValue*/, true, commentedNever);
		emitOption("noUncheckedSideEffectImports" /*defaultValue*/, true, commentedNever);
		emitOption("moduleDetection", ModuleDetectionKindForce, commentedNever);
		emitOption("skipLibCheck" /*defaultValue*/, true, commentedNever);

		// Write any user-provided options we haven't already
		if (allSetOptions.length > 0) {
			newline();
			while (allSetOptions.length > 0) {
				emitOption(allSetOptions[0], options.GetOrZero(allSetOptions[0]), commentedNever);
			}
		}

		push([tab + "}"]);
		push(["}"]);
		push([""]);

		return result.join("\n");
	}

	// --- statistics.go ---

	static function formatDuration(d:Duration):std.String {
		// fmt.Sprintf("%.3fs", d.Seconds())
		// PORT: Fmt has no %f; d is rounded to milliseconds here (Go rounds the float64 seconds).
		final ms = Math.round(Time.DurationFloat64(d) / 1e6);
		final s = Std.int(ms / 1000);
		final frac = Std.int(ms - s * 1000.0);
		return s + "." + StringTools.lpad(Std.string(frac), "0", 3) + "s";
	}

	// PORT: strconv.FormatUint / %v of a uint64 held in a Float.
	static function formatUint(v:Float):std.String {
		if (v < 2147483648.0)
			return Std.string(Std.int(v));
		final hi = Math.ffloor(v / 1e9);
		final lo = v - hi * 1e9;
		return Std.string(Std.int(hi)) + StringTools.lpad(Std.string(Std.int(lo)), "0", 9);
	}

	static function identifierCount(p:Program):Int {
		var count = 0;
		for (file in p.SourceFiles()) {
			count += file.IdentifierCount;
		}
		return count;
	}

	static function statisticsFromProgram(input:EmitInput, memStats:MemStats):Statistics {
		final s = new Statistics();
		s.files = input.Program.SourceFiles().length;
		s.lines = input.Program.LineCount();
		s.identifiers = input.Program.IdentifierCount();
		s.symbols = input.Program.SymbolCount();
		s.types = input.Program.TypeCount();
		s.instantiations = input.Program.InstantiationCount();
		s.memoryUsed = memStats.Alloc;
		s.memoryAllocs = memStats.Mallocs;
		s.compileTimes = input.CompileTimes;
		return s;
	}
}
