package ts.tsoptions;

import ts.scanner.Scanner;
import ts.jsnum.Jsnum;
import ts.json.Json;
import ts.locale.Locale;

// Port of internal/tsoptions: package-level vars and funcs of all files, in Go file order.
//
// PORT: Go `any` option values are Haxe Dynamic. The Go dynamic types map to:
//   nil → null; bool → Bool; string → std.String; int, float64 and the int32 enums (ModuleKind,
//   ...) → Int / Float; *collections.OrderedMap[string, any] → OrderedMap; []any → Array.
// Go tells apart things Haxe cannot see at run time:
//   - a nil slice stored in an `any` is != nil, has reflect.Kind Slice and marshals as `[]`.
//     Haxe null cannot carry that type, so a nil []any held in an `any` is the shared empty array
//     nilAnySlice, and a nil []string held in an `any` is nilStringSlice (anySliceToAny /
//     asAnySlice convert at the boundaries; they are compared by identity and never mutated).
//   - `[]string{}` (the only []string value stored in an option map) is emptyStringSlice; every
//     other array in an `any` is a Go []any.
//
// PORT: package-level vars whose initializer uses other classes are lazy getters (PORTING §7a).
@:allow(ts.tsoptions)
class Tsoptions {
	// --- any-value helpers (PORT) ---

	static final nilAnySlice:Array<Dynamic> = [];
	static final nilStringSlice:Array<std.String> = [];
	static final emptyStringSlice:Array<std.String> = [];

	static inline function isString(v:Dynamic):Bool {
		return Std.isOfType(v, std.String);
	}

	static inline function isBool(v:Dynamic):Bool {
		return Std.isOfType(v, Bool);
	}

	static inline function isOrderedMap(v:Dynamic):Bool {
		return Std.isOfType(v, OrderedMap);
	}

	// Go reflect.Kind == reflect.Slice
	static inline function isSlice(v:Dynamic):Bool {
		return Std.isOfType(v, Array);
	}

	// Identity of a sentinel array (Core.Same treats all empty slices as the same).
	static function isSentinel(v:Dynamic, sentinel:Dynamic):Bool {
		return v != null && v == sentinel;
	}

	// Go `v.([]string)` succeeds
	static function isStringSlice(v:Dynamic):Bool {
		return isSentinel(v, emptyStringSlice) || isSentinel(v, nilStringSlice);
	}

	// Go `v.([]any)` succeeds
	static function isAnySlice(v:Dynamic):Bool {
		return isSlice(v) && !isStringSlice(v);
	}

	// Go `[]any` value of an `any` that holds a []any (nil for a nil slice).
	static function asAnySlice(v:Dynamic):Null<Array<Dynamic>> {
		if (v == null || isSentinel(v, nilAnySlice)) {
			return null;
		}
		return v;
	}

	// Go: store a []any into an `any`.
	static function anySliceToAny(s:Null<Array<Dynamic>>):Dynamic {
		return s == null ? nilAnySlice : s;
	}

	// Go: store a []string into an `any`.
	static function stringSliceToAny(s:Null<Array<std.String>>):Dynamic {
		return s == null ? nilStringSlice : s;
	}

	// Go single-value type assertion `v.(string)` (panics on a mismatch).
	static function mustString(v:Dynamic):std.String {
		if (!isString(v)) {
			throw "interface conversion: interface {} is not string";
		}
		return v;
	}

	// Go single-value type assertion `v.(bool)` (panics on a mismatch).
	static function mustBool(v:Dynamic):Bool {
		if (!isBool(v)) {
			throw "interface conversion: interface {} is not bool";
		}
		return v;
	}

	// Go: append errs to errors (a nil result stays nil when both are empty).
	static function appendDiags(errors:Null<Array<Diagnostic>>, errs:Null<Array<Diagnostic>>):Null<Array<Diagnostic>> {
		if (errs == null || errs.length == 0) {
			return errors;
		}
		if (errors == null) {
			errors = [];
		}
		for (e in errs) {
			errors.push(e);
		}
		return errors;
	}

	static function appendDiag(errors:Null<Array<Diagnostic>>, d:Diagnostic):Array<Diagnostic> {
		if (errors == null) {
			errors = [];
		}
		errors.push(d);
		return errors;
	}

	// --- commandlineoption.go ---

	// CommandLineOption.Elements()
	static var commandLineOptionElements(get, never):StringMap<CommandLineOption>;
	static var _commandLineOptionElements:StringMap<CommandLineOption> = null;

	static function get_commandLineOptionElements():StringMap<CommandLineOption> {
		if (_commandLineOptionElements == null) {
			final m = new StringMap<CommandLineOption>();
			function add(key:std.String, name:std.String, kind:CommandLineOptionKind, ?f:(CommandLineOption) -> Void) {
				final o = new CommandLineOption();
				o.Name = name;
				o.Kind = kind;
				if (f != null)
					f(o);
				m.set(key, o);
			}
			add("lib", "lib", CommandLineOptionTypeEnum, o -> o.DefaultValueDescription = TSUnknown); // libMap,
			add("rootDirs", "rootDirs", CommandLineOptionTypeString, o -> o.IsFilePath = true);
			add("typeRoots", "typeRoots", CommandLineOptionTypeString, o -> o.IsFilePath = true);
			add("types", "types", CommandLineOptionTypeString);
			add("moduleSuffixes", "moduleSuffixes", CommandLineOptionTypeString);
			add("customConditions", "condition", CommandLineOptionTypeString);
			add("plugins", "plugin", CommandLineOptionTypeObject);
			// For tsconfig root options
			add("references", "references", CommandLineOptionTypeObject);
			add("files", "files", CommandLineOptionTypeString);
			add("include", "include", CommandLineOptionTypeString);
			add("exclude", "exclude", CommandLineOptionTypeString);
			add("extends", "extends", CommandLineOptionTypeString);
			// For Watch options
			add("excludeDirectories", "excludeDirectory", CommandLineOptionTypeString, o -> {
				o.IsFilePath = true;
				o.extraValidation = extraValidationSpec;
			});
			add("excludeFiles", "excludeFile", CommandLineOptionTypeString, o -> {
				o.IsFilePath = true;
				o.extraValidation = extraValidationSpec;
			});
			// Test infra options
			add("libFiles", "libFiles", CommandLineOptionTypeString);
			_commandLineOptionElements = m;
		}
		return _commandLineOptionElements;
	}

	// CommandLineOption.EnumMap()
	static var commandLineOptionEnumMap(get, never):StringMap<OrderedMap<std.String, Dynamic>>;
	static var _commandLineOptionEnumMap:StringMap<OrderedMap<std.String, Dynamic>> = null;

	static function get_commandLineOptionEnumMap():StringMap<OrderedMap<std.String, Dynamic>> {
		if (_commandLineOptionEnumMap == null) {
			final m = new StringMap<OrderedMap<std.String, Dynamic>>();
			m.set("lib", LibMap);
			m.set("moduleResolution", moduleResolutionOptionMap);
			m.set("module", moduleOptionMap);
			m.set("target", targetOptionMap);
			m.set("moduleDetection", moduleDetectionOptionMap);
			m.set("jsx", jsxOptionMap);
			m.set("newLine", newLineOptionMap);
			m.set("watchFile", watchFileEnumMap);
			m.set("watchDirectory", watchDirectoryEnumMap);
			m.set("fallbackPolling", fallbackEnumMap);
			_commandLineOptionEnumMap = m;
		}
		return _commandLineOptionEnumMap;
	}

	// CommandLineOption.DeprecatedKeys()
	static var commandLineOptionDeprecated(get, never):StringMap<Set<std.String>>;
	static var _commandLineOptionDeprecated:StringMap<Set<std.String>> = null;

	static function get_commandLineOptionDeprecated():StringMap<Set<std.String>> {
		if (_commandLineOptionDeprecated == null) {
			final m = new StringMap<Set<std.String>>();
			m.set("module", Collections.NewSetFromItems("none", "amd", "system", "umd"));
			m.set("moduleResolution", Collections.NewSetFromItems("node", "classic", "node10"));
			m.set("target", Collections.NewSetFromItems("es5"));
			_commandLineOptionDeprecated = m;
		}
		return _commandLineOptionDeprecated;
	}

	// --- commandlineparser.go ---

	public static function ParseCommandLine(commandLine:Null<Array<std.String>>, host:ParseConfigHost):ParsedCommandLine {
		if (commandLine == null) {
			commandLine = [];
		}
		final parser = parseCommandLineWorker(CompilerOptionsDidYouMeanDiagnostics, commandLine, host.FS(), host.GetCurrentDirectory());
		final optionsWithAbsolutePaths = convertToOptionsWithAbsolutePaths(parser.options.Clone(), CommandLineCompilerOptionsMap,
			host.GetCurrentDirectory());
		final compilerOptions = convertMapToOptions(optionsWithAbsolutePaths, new CompilerOptionsParser(new CompilerOptions())).CompilerOptions;
		final watchOptions = convertMapToOptions(optionsWithAbsolutePaths, new WatchOptionsParser(new WatchOptions())).WatchOptions;
		final result = NewParsedCommandLine(compilerOptions, parser.fileNames,
			new ComparePathsOptions(host.FS().UseCaseSensitiveFileNames(), host.GetCurrentDirectory()));
		result.ParsedConfig.WatchOptions = watchOptions;
		result.Errors = parser.errors;
		result.Raw = parser.options;
		return result;
	}

	public static function ParseBuildCommandLine(commandLine:Null<Array<std.String>>, host:ParseConfigHost):ParsedBuildCommandLine {
		if (commandLine == null) {
			commandLine = [];
		}
		final parser = parseCommandLineWorker(buildOptionsDidYouMeanDiagnostics, commandLine, host.FS(), host.GetCurrentDirectory());
		final compilerOptions = new CompilerOptions();
		for (key => value in parser.options.Entries()) {
			final buildOption = BuildNameMap.Get(key);
			if (buildOption == TscBuildOption || buildOption == CompilerNameMap.Get(key)) {
				ParseCompilerOptions(key, value, compilerOptions);
			}
		}
		final result = new ParsedBuildCommandLine();
		result.BuildOptions = convertMapToOptions(parser.options, new BuildOptionsParser(new BuildOptions())).BuildOptions;
		result.CompilerOptions = compilerOptions;
		result.WatchOptions = convertMapToOptions(parser.options, new WatchOptionsParser(new WatchOptions())).WatchOptions;
		result.Projects = parser.fileNames;
		result.Errors = parser.errors;
		result.Raw = parser.options;

		result.comparePathsOptions = new ComparePathsOptions(host.FS().UseCaseSensitiveFileNames(), host.GetCurrentDirectory());

		if (Core.len(result.Projects) == 0) {
			// tsc -b invoked with no extra arguments; act as if invoked with "tsc -b ."
			if (result.Projects == null)
				result.Projects = [];
			result.Projects.push(".");
		}

		// Nonsensical combinations
		if (result.BuildOptions.Clean.IsTrue() && result.BuildOptions.Force.IsTrue()) {
			result.Errors = appendDiag(result.Errors, Ast.NewCompilerDiagnostic(Diagnostics.Options_0_and_1_cannot_be_combined, "clean", "force"));
		}
		if (result.BuildOptions.Clean.IsTrue() && result.BuildOptions.Verbose.IsTrue()) {
			result.Errors = appendDiag(result.Errors, Ast.NewCompilerDiagnostic(Diagnostics.Options_0_and_1_cannot_be_combined, "clean", "verbose"));
		}
		if (result.BuildOptions.Clean.IsTrue() && result.CompilerOptions.Watch.IsTrue()) {
			result.Errors = appendDiag(result.Errors, Ast.NewCompilerDiagnostic(Diagnostics.Options_0_and_1_cannot_be_combined, "clean", "watch"));
		}
		if (result.CompilerOptions.Watch.IsTrue() && result.BuildOptions.Dry.IsTrue()) {
			result.Errors = appendDiag(result.Errors, Ast.NewCompilerDiagnostic(Diagnostics.Options_0_and_1_cannot_be_combined, "watch", "dry"));
		}

		return result;
	}

	static function parseCommandLineWorker(parseCommandLineWithDiagnostics:ParseCommandLineWorkerDiagnostics, commandLine:Array<std.String>,
			fs:Null<FS>, currentDirectory:std.String):CommandLineParser {
		final parser = new CommandLineParser();
		parser.fs = fs;
		parser.currentDirectory = currentDirectory;
		parser.workerDiagnostics = parseCommandLineWithDiagnostics;
		parser.fileNames = [];
		parser.options = new OrderedMap<std.String, Dynamic>();
		parser.errors = [];
		parser.optionsMap = GetNameMapFromList(parser.OptionsDeclarations());
		parser.parseStrings(commandLine);
		return parser;
	}

	static function getInputOptionName(input:std.String):std.String {
		// removes at most two leading '-' from the input string
		return Strings.TrimPrefix(Strings.TrimPrefix(input, "-"), "-");
	}

	// PORT: readFile returns (string, bool) as ValueOk; the result (string, []*ast.Diagnostic) is a Pair.
	static function tryReadFile(fileName:std.String, readFile:(std.String) -> ValueOk<std.String>,
			errors:Null<Array<Diagnostic>>):Pair<std.String, Null<Array<Diagnostic>>> {
		// this function adds a compiler diagnostic if the file cannot be read
		final r = readFile(fileName);
		var text = r.value;
		final e = r.ok;

		if (!e) {
			// !!! Divergence: the returned error will not give a useful message
			// errors = append(errors, ast.NewCompilerDiagnostic(diagnostics.Cannot_read_file_0_Colon_1, *e));
			text = "";
			errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Cannot_read_file_0, fileName));
		}
		return new Pair<std.String, Null<Array<Diagnostic>>>(text, errors);
	}

	// PORT: ([]any, []*ast.Diagnostic) → Pair (a nil []any is null).
	public static function ParseListTypeOption(opt:CommandLineOption, value:std.String):Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>> {
		value = Strings.TrimSpace(value);
		var errors:Null<Array<Diagnostic>> = null;
		if (StringTools.startsWith(value, "-")) {
			return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>([], errors);
		}
		if (opt.Kind == CommandLineOptionTypeListOrElement && value.indexOf(",") < 0) {
			final r = validateJsonOptionValue(opt, value, null, null);
			if (r.b != null) {
				return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>([], r.b);
			}
			return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>([mustString(r.a)], errors);
		}
		if (value == "") {
			return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>([], errors);
		}
		final values = Strings.Split(value, ",");
		switch (opt.Elements().Kind) {
			case CommandLineOptionTypeString:
				final elements = Core.MapFiltered(values, function(v:std.String):ValueOk<Dynamic> {
					final r = validateJsonOptionValue(opt.Elements(), v, null, null);
					final val = r.a;
					final err = r.b;
					if (isString(val) && Core.len(err) == 0 && (val : std.String) != "") {
						return new ValueOk<Dynamic>(val, true);
					}
					errors = appendDiags(errors, err);
					return new ValueOk<Dynamic>("", false);
				});
				return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>(elements, errors);
			case CommandLineOptionTypeBoolean, CommandLineOptionTypeObject, CommandLineOptionTypeNumber:
				// do nothing: only string and enum/object types currently allowed as list entries
				// 				!!! we don't actually have number list options, so I didn't implement number list parsing
				throw "List of " + (opt.Elements().Kind : std.String) + " is not yet supported.";
			default:
				final result = Core.MapFiltered(values, function(v:std.String):ValueOk<Dynamic> {
					final r = convertJsonOptionOfEnumType(opt.Elements(), Strings.TrimFunc(v, Stringutil.IsWhiteSpaceLike), null, null);
					final val = r.a;
					final err = r.b;
					if (isString(val) && Core.len(err) == 0 && (val : std.String) != "") {
						return new ValueOk<Dynamic>(val, true);
					}
					errors = appendDiags(errors, err);
					return new ValueOk<Dynamic>("", false);
				});
				return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>(result, errors);
		}
	}

	static function convertJsonOptionOfEnumType(opt:CommandLineOption, value:std.String, valueExpression:Null<Node>,
			sourceFile:Null<SourceFile>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		if (value == "") {
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
		}
		final key = Strings.ToLower(value);
		final typeMap = opt.EnumMap();
		if (typeMap == null) {
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
		}
		final r = typeMap.Get(key);
		if (r.ok) {
			return validateJsonOptionValue(opt, r.value, valueExpression, sourceFile);
		}
		return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, [createDiagnosticForInvalidEnumType(opt, sourceFile, valueExpression)]);
	}

	// --- declsbuild.go ---

	public static var TscBuildOption(get, never):CommandLineOption;
	static var _TscBuildOption:CommandLineOption = null;

	static function get_TscBuildOption():CommandLineOption {
		if (_TscBuildOption == null) {
			final o = new CommandLineOption();
			o.Name = "build";
			o.Kind = CommandLineOptionTypeBoolean;
			o.ShortName = "b";
			o.ShowInSimplifiedHelpView = true;
			o.Category = Diagnostics.Command_line_Options;
			o.Description = Diagnostics.Build_one_or_more_projects_and_their_dependencies_if_out_of_date;
			o.DefaultValueDescription = false;
			_TscBuildOption = o;
		}
		return _TscBuildOption;
	}

	public static var OptionsForBuild(get, never):Array<CommandLineOption>;
	static var _OptionsForBuild:Array<CommandLineOption> = null;

	static function get_OptionsForBuild():Array<CommandLineOption> {
		if (_OptionsForBuild == null) {
			_OptionsForBuild = [
				TscBuildOption,
				{
					final o = new CommandLineOption();
					o.Name = "verbose";
					o.ShortName = "v";
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Enable_verbose_logging;
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "dry";
					o.ShortName = "d";
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Show_what_would_be_built_or_deleted_if_specified_with_clean;
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "force";
					o.ShortName = "f";
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Build_all_projects_including_those_that_appear_to_be_up_to_date;
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "clean";
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Delete_the_outputs_of_all_projects;
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "builders";
					o.Kind = CommandLineOptionTypeNumber;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Set_the_number_of_projects_to_build_concurrently;
					o.DefaultValueDescription = Diagnostics.X_4_unless_singleThreaded_is_passed;
					o.minValue = 1;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "stopBuildOnErrors";
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Skip_building_downstream_projects_on_error_in_upstream_project;
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
			];
		}
		return _OptionsForBuild;
	}

	public static var BuildOpts(get, never):Array<CommandLineOption>;
	static var _BuildOpts:Array<CommandLineOption> = null;

	static function get_BuildOpts():Array<CommandLineOption> {
		if (_BuildOpts == null) {
			_BuildOpts = Slices.Concat(commonOptionsWithBuild, OptionsForBuild);
		}
		return _BuildOpts;
	}

	// --- declscompiler.go ---

	public static var OptionsDeclarations(get, never):Array<CommandLineOption>;
	static var _OptionsDeclarations:Array<CommandLineOption> = null;

	static function get_OptionsDeclarations():Array<CommandLineOption> {
		if (_OptionsDeclarations == null) {
			_OptionsDeclarations = Slices.Concat(commonOptionsWithBuild, optionsForCompiler);
		}
		return _OptionsDeclarations;
	}

	static var commonOptionsWithBuild(get, never):Array<CommandLineOption>;
	static var _commonOptionsWithBuild:Array<CommandLineOption> = null;

	static function get_commonOptionsWithBuild():Array<CommandLineOption> {
		if (_commonOptionsWithBuild == null) {
			_commonOptionsWithBuild = [
				//******* commonOptionsWithBuild *******
				{
					final o = new CommandLineOption();
					o.Name = "help";
					o.ShortName = "h";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.IsCommandLineOnly = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Print_this_message;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "help";
					o.ShortName = "?";
					o.Kind = CommandLineOptionTypeBoolean;
					o.IsCommandLineOnly = true;
					o.Category = Diagnostics.Command_line_Options;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "watch";
					o.ShortName = "w";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.IsCommandLineOnly = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Watch_input_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "preserveWatchOutput";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = false;
					o.Category = Diagnostics.Output_Formatting;
					o.Description = Diagnostics.Disable_wiping_the_console_in_watch_mode;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "listFiles";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Print_all_of_the_files_read_during_the_compilation;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "explainFiles";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Print_files_read_during_the_compilation_including_why_it_was_included;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "listEmittedFiles";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Print_the_names_of_emitted_files_after_a_compilation;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "pretty";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Output_Formatting;
					o.Description = Diagnostics.Enable_color_and_formatting_in_TypeScript_s_output_to_make_compiler_errors_easier_to_read;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "traceResolution";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Log_paths_used_during_the_moduleResolution_process;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "diagnostics";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Output_compiler_performance_information_after_building;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "extendedDiagnostics";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Output_more_detailed_compiler_performance_information_after_building;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "generateCpuProfile";
					o.Kind = CommandLineOptionTypeString;
					o.IsFilePath = true;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Emit_a_v8_CPU_profile_of_the_compiler_run_for_debugging;
					o.DefaultValueDescription = "profile.cpuprofile";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "generateTrace";
					o.Kind = CommandLineOptionTypeString;
					o.IsFilePath = true;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Generates_an_event_trace_and_a_list_of_types;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "incremental";
					o.ShortName = "i";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Projects;
					o.Description = Diagnostics.Save_tsbuildinfo_files_to_allow_for_incremental_compilation_of_projects;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = Diagnostics.X_false_unless_composite_is_set;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "declaration";
					o.ShortName = "d";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.transpileOptionValue = TSUnknown;
					o.Description = Diagnostics.Generate_d_ts_files_from_TypeScript_and_JavaScript_files_in_your_project;
					o.DefaultValueDescription = Diagnostics.X_false_unless_composite_is_set;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "declarationMap";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.DefaultValueDescription = false;
					o.Description = Diagnostics.Create_sourcemaps_for_d_ts_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "emitDeclarationOnly";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Only_output_d_ts_files_and_not_JavaScript_files;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "sourceMap";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.DefaultValueDescription = false;
					o.Description = Diagnostics.Create_source_map_files_for_emitted_JavaScript_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "inlineSourceMap";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Include_sourcemap_files_inside_the_emitted_JavaScript;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noCheck";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = false;
					o.Category = Diagnostics.Compiler_Diagnostics;
					o.Description = Diagnostics.Disable_full_type_checking_only_critical_parse_and_emit_errors_will_be_reported;
					o.transpileOptionValue = TSTrue;
					o.DefaultValueDescription = false;
					// Not setting affectsSemanticDiagnostics or affectsBuildInfo because we dont want all diagnostics to go away, its handled in builder
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "deduplicatePackages";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Deduplicate_packages_with_the_same_name_and_version;
					o.DefaultValueDescription = true;
					o.AffectsProgramStructure = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noEmit";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Disable_emitting_files_from_a_compilation;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "assumeChangesOnlyAffectDirectDependencies";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Have_recompiles_in_projects_that_use_incremental_and_watch_mode_assume_that_changes_within_a_file_will_only_affect_files_directly_depending_on_it;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "locale";
					o.Kind = CommandLineOptionTypeString;
					o.Category = Diagnostics.Command_line_Options;
					o.IsCommandLineOnly = true;
					o.Description = Diagnostics.Set_the_language_of_the_messaging_from_TypeScript_This_does_not_affect_emit;
					o.DefaultValueDescription = Diagnostics.Platform_specific;
					o.extraValidation = extraValidationLocale;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "quiet";
					o.ShortName = "q";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Do_not_print_diagnostics;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "singleThreaded";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Run_in_single_threaded_mode;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "pprofDir";
					o.Kind = CommandLineOptionTypeString;
					o.IsFilePath = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Generate_pprof_CPU_Slashmemory_profiles_to_the_given_directory;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "checkers";
					o.Kind = CommandLineOptionTypeNumber;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Set_the_number_of_checkers_per_project;
					o.DefaultValueDescription = Diagnostics.X_4_unless_singleThreaded_is_passed;
					o.minValue = 1;
					o;
				},
			];
		}
		return _commonOptionsWithBuild;
	}

	static var optionsForCompiler(get, never):Array<CommandLineOption>;
	static var _optionsForCompiler:Array<CommandLineOption> = null;

	static function get_optionsForCompiler():Array<CommandLineOption> {
		if (_optionsForCompiler == null) {
			_optionsForCompiler = [
				//******* compilerOptions not common with --build *******
				// CommandLine only options
				{
					final o = new CommandLineOption();
					o.Name = "all";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Show_all_compiler_options;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "version";
					o.ShortName = "v";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Print_the_compiler_s_version;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "init";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Initializes_a_TypeScript_project_and_creates_a_tsconfig_json_file;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "project";
					o.ShortName = "p";
					o.Kind = CommandLineOptionTypeString;
					o.IsFilePath = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.Description = Diagnostics.Compile_the_project_given_the_path_to_its_configuration_file_or_to_a_folder_with_a_tsconfig_json;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "showConfig";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.IsCommandLineOnly = true;
					o.Description = Diagnostics.Print_the_final_configuration_instead_of_building;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "listFilesOnly";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Command_line_Options;
					o.IsCommandLineOnly = true;
					o.Description = Diagnostics.Print_names_of_files_that_are_part_of_the_compilation_and_then_stop_processing;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "ignoreConfig";
					o.Kind = CommandLineOptionTypeBoolean;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Command_line_Options;
					o.IsCommandLineOnly = true;
					o.Description = Diagnostics.Ignore_the_tsconfig_found_and_build_with_commandline_options_and_files;
					o.DefaultValueDescription = false;
					o;
				},
				// Basic
				// targetOptionDeclaration,
				{
					final o = new CommandLineOption();
					o.Name = "target";
					o.ShortName = "t";
					o.Kind = CommandLineOptionTypeEnum; // targetOptionMap
					o.AffectsSourceFile = true;
					o.AffectsModuleResolution = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Set_the_JavaScript_language_version_for_emitted_JavaScript_and_include_compatible_library_declarations;
					o.DefaultValueDescription = ScriptTargetLatestStandard;
					o;
				},
				// moduleOptionDeclaration,
				{
					final o = new CommandLineOption();
					o.Name = "module";
					o.ShortName = "m";
					o.Kind = CommandLineOptionTypeEnum; // moduleOptionMap
					o.AffectsModuleResolution = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_what_module_code_is_generated;
					o.DefaultValueDescription = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "lib";
					o.Kind = CommandLineOptionTypeList;
					// elements: &CommandLineOption{
					// 	name:                    "lib",
					// 	kind:                   CommandLineOptionTypeEnum, // libMap,
					// 	defaultValueDescription: core.TSUnknown,
					// },
					o.AffectsProgramStructure = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_a_set_of_bundled_library_declaration_files_that_describe_the_target_runtime_environment;
					o.transpileOptionValue = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowJs";
					o.Kind = CommandLineOptionTypeBoolean;
					o.allowJsFlag = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.JavaScript_Support;
					o.Description = Diagnostics.Allow_JavaScript_files_to_be_a_part_of_your_program_Use_the_checkJs_option_to_get_errors_from_these_files;
					o.DefaultValueDescription = Diagnostics.X_false_unless_checkJs_is_set;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "checkJs";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.JavaScript_Support;
					o.Description = Diagnostics.Enable_error_reporting_in_type_checked_JavaScript_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "jsx";
					o.Kind = CommandLineOptionTypeEnum; // jsxOptionMap,
					o.AffectsSourceFile = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsModuleResolution = true;
					// The checker emits an error when it sees JSX but this option is not set in compilerOptions.
					// This is effectively a semantic error, so mark this option as affecting semantic diagnostics
					// so we know to refresh errors when this option is changed.
					o.AffectsSemanticDiagnostics = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_what_JSX_code_is_generated;
					o.DefaultValueDescription = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "outFile";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsDeclarationPath = true;
					o.IsFilePath = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Specify_a_file_that_bundles_all_outputs_into_one_JavaScript_file_If_declaration_is_true_also_designates_a_file_that_bundles_all_d_ts_output;
					o.transpileOptionValue = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "outDir";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsDeclarationPath = true;
					o.IsFilePath = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Specify_an_output_folder_for_all_emitted_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "rootDir";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsDeclarationPath = true;
					o.IsFilePath = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_the_root_folder_within_your_source_files;
					o.DefaultValueDescription = Diagnostics.Computed_from_the_list_of_input_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "composite";
					o.Kind = CommandLineOptionTypeBoolean;
					// Not setting affectsEmit because we calculate this flag might not affect full emit
					o.AffectsBuildInfo = true;
					o.IsTSConfigOnly = true;
					o.Category = Diagnostics.Projects;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = false;
					o.Description = Diagnostics.Enable_constraints_that_allow_a_TypeScript_project_to_be_used_with_project_references;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "tsBuildInfoFile";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.IsFilePath = true;
					o.Category = Diagnostics.Projects;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = ".tsbuildinfo";
					o.Description = Diagnostics.Specify_the_path_to_tsbuildinfo_incremental_compilation_file;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "removeComments";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Emit;
					o.DefaultValueDescription = false;
					o.Description = Diagnostics.Disable_emitting_comments;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "importHelpers";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsSourceFile = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Allow_importing_helper_functions_from_tslib_once_per_project_instead_of_including_them_per_file;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "downlevelIteration";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Emit_more_compliant_but_verbose_and_less_performant_JavaScript_for_iteration;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "isolatedModules";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Ensure_that_each_file_can_be_safely_transpiled_without_relying_on_other_imports;
					o.transpileOptionValue = TSTrue;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "verbatimModuleSyntax";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Do_not_transform_or_elide_any_imports_or_exports_not_marked_as_type_only_ensuring_they_are_written_in_the_output_file_s_format_based_on_the_module_setting;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "isolatedDeclarations";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Require_sufficient_annotation_on_exports_so_other_tools_can_trivially_generate_declaration_files;
					o.DefaultValueDescription = false;
					o.AffectsBuildInfo = true;
					o.AffectsSemanticDiagnostics = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "erasableSyntaxOnly";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Do_not_allow_runtime_constructs_that_are_not_part_of_ECMAScript;
					o.DefaultValueDescription = false;
					o.AffectsBuildInfo = true;
					o.AffectsSemanticDiagnostics = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "libReplacement";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsProgramStructure = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Enable_lib_replacement;
					o.DefaultValueDescription = false;
					o;
				},
				// Strict Type Checks
				{
					final o = new CommandLineOption();
					o.Name = "strict";
					o.Kind = CommandLineOptionTypeBoolean;
					// Though this affects semantic diagnostics, affectsSemanticDiagnostics is not set here
					// The value of each strictFlag depends on own strictFlag value or this and never accessed directly.
					// But we need to store `strict` in builf info, even though it won't be examined directly, so that the
					// flags it controls (e.g. `strictNullChecks`) will be retrieved correctly
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_all_strict_type_checking_options;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noImplicitAny";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_error_reporting_for_expressions_and_declarations_with_an_implied_any_type;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "strictNullChecks";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.When_type_checking_take_into_account_null_and_undefined;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "strictFunctionTypes";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.When_assigning_functions_check_to_ensure_parameters_and_the_return_values_are_subtype_compatible;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "strictBindCallApply";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Check_that_the_arguments_for_bind_call_and_apply_methods_match_the_original_function;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "strictPropertyInitialization";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Check_for_class_properties_that_are_declared_but_not_set_in_the_constructor;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "strictBuiltinIteratorReturn";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Built_in_iterators_are_instantiated_with_a_TReturn_type_of_undefined_instead_of_any;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noImplicitThis";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_error_reporting_when_this_is_given_the_type_any;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "useUnknownInCatchVariables";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.strictFlag = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Default_catch_clause_variables_as_unknown_instead_of_any;
					o.DefaultValueDescription = Diagnostics.X_true_unless_strict_is_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "alwaysStrict";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSourceFile = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Ensure_use_strict_is_always_emitted;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "stableTypeOrdering";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Ensure_types_are_ordered_stably_and_deterministically_across_compilations;
					o.DefaultValueDescription = true;
					o;
				},
				// Additional Checks
				{
					final o = new CommandLineOption();
					o.Name = "noUnusedLocals";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_error_reporting_when_local_variables_aren_t_read;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noUnusedParameters";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Raise_an_error_when_a_function_parameter_isn_t_read;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "exactOptionalPropertyTypes";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Interpret_optional_property_types_as_written_rather_than_adding_undefined;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noImplicitReturns";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_error_reporting_for_codepaths_that_do_not_explicitly_return_in_a_function;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noFallthroughCasesInSwitch";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsBindDiagnostics = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enable_error_reporting_for_fallthrough_cases_in_switch_statements;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noUncheckedIndexedAccess";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Add_undefined_to_a_type_when_accessed_using_an_index;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noImplicitOverride";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Ensure_overriding_members_in_derived_classes_are_marked_with_an_override_modifier;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noPropertyAccessFromIndexSignature";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = false;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Enforces_using_indexed_accessors_for_keys_declared_using_an_indexed_type;
					o.DefaultValueDescription = false;
					o;
				},
				// Module Resolution
				{
					final o = new CommandLineOption();
					o.Name = "moduleResolution";
					o.Kind = CommandLineOptionTypeEnum;
					//    new Map(Object.entries({
					//         // N.B. The first entry specifies the value shown in `tsc --init`
					//         node10: ModuleResolutionKind.Node10,
					//         node: ModuleResolutionKind.Node10,
					//         classic: ModuleResolutionKind.Classic,
					//         node16: ModuleResolutionKind.Node16,
					//         nodenext: ModuleResolutionKind.NodeNext,
					//         bundler: ModuleResolutionKind.Bundler,
					//     })),
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_how_TypeScript_looks_up_a_file_from_a_given_module_specifier;
					o.DefaultValueDescription = Diagnostics.X_nodenext_if_module_is_nodenext_node16_if_module_is_node16_or_node18_otherwise_bundler;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "baseUrl";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsModuleResolution = true;
					o.IsFilePath = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_the_base_directory_to_resolve_non_relative_module_names;
					o;
				},
				{
					final o = new CommandLineOption();
					// this option can only be specified in tsconfig.json
					// use type = object to copy the value as-is
					o.Name = "paths";
					o.Kind = CommandLineOptionTypeObject;
					o.AffectsModuleResolution = true;
					o.allowConfigDirTemplateSubstitution = true;
					o.IsTSConfigOnly = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_a_set_of_entries_that_re_map_imports_to_additional_lookup_locations;
					o.transpileOptionValue = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					// this option can only be specified in tsconfig.json
					// use type = object to copy the value as-is
					o.Name = "rootDirs";
					o.Kind = CommandLineOptionTypeList;
					o.IsTSConfigOnly = true;
					o.AffectsModuleResolution = true;
					o.allowConfigDirTemplateSubstitution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Allow_multiple_folders_to_be_treated_as_one_when_resolving_modules;
					o.transpileOptionValue = TSUnknown;
					o.DefaultValueDescription = Diagnostics.Computed_from_the_list_of_input_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "typeRoots";
					o.Kind = CommandLineOptionTypeList;
					o.AffectsModuleResolution = true;
					o.allowConfigDirTemplateSubstitution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_multiple_folders_that_act_like_Slashnode_modules_Slash_types;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "types";
					o.Kind = CommandLineOptionTypeList;
					o.AffectsProgramStructure = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Specify_type_package_names_to_be_included_without_being_referenced_in_a_source_file;
					o.transpileOptionValue = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowSyntheticDefaultImports";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Allow_import_x_from_y_when_a_module_doesn_t_have_a_default_export;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "esModuleInterop";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.ShowInSimplifiedHelpView = true;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Emit_additional_JavaScript_to_ease_support_for_importing_CommonJS_modules_This_enables_allowSyntheticDefaultImports_for_type_compatibility;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "preserveSymlinks";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Disable_resolving_symlinks_to_their_realpath_This_correlates_to_the_same_flag_in_node;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowUmdGlobalAccess";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Allow_accessing_UMD_globals_from_modules;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "moduleSuffixes";
					o.Kind = CommandLineOptionTypeList;
					o.listPreserveFalsyValues = true;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.List_of_file_name_suffixes_to_search_when_resolving_a_module;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowImportingTsExtensions";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Allow_imports_to_include_TypeScript_file_extensions_Requires_moduleResolution_bundler_and_either_noEmit_or_emitDeclarationOnly_to_be_set;
					o.DefaultValueDescription = false;
					o.transpileOptionValue = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "rewriteRelativeImportExtensions";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Rewrite_ts_tsx_mts_and_cts_file_extensions_in_relative_import_paths_to_their_JavaScript_equivalent_in_output_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "resolvePackageJsonExports";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Use_the_package_json_exports_field_when_resolving_package_imports;
					o.DefaultValueDescription = Diagnostics.X_true_when_moduleResolution_is_node16_nodenext_or_bundler_otherwise_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "resolvePackageJsonImports";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Use_the_package_json_imports_field_when_resolving_imports;
					o.DefaultValueDescription = Diagnostics.X_true_when_moduleResolution_is_node16_nodenext_or_bundler_otherwise_false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "customConditions";
					o.Kind = CommandLineOptionTypeList;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Conditions_to_set_in_addition_to_the_resolver_specific_defaults_when_resolving_imports;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noUncheckedSideEffectImports";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Check_side_effect_imports;
					o.DefaultValueDescription = true;
					o;
				},
				// Source Maps
				{
					final o = new CommandLineOption();
					o.Name = "sourceRoot";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Specify_the_root_path_for_debuggers_to_find_the_reference_source_code;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "mapRoot";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Specify_the_location_where_debugger_should_locate_map_files_instead_of_generated_locations;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "inlineSources";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Include_source_code_in_the_sourcemaps_inside_the_emitted_JavaScript;
					o.DefaultValueDescription = false;
					o;
				},
				// Experimental
				{
					final o = new CommandLineOption();
					o.Name = "experimentalDecorators";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Enable_experimental_support_for_legacy_experimental_decorators;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "emitDecoratorMetadata";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Emit_design_type_metadata_for_decorated_declarations_in_source_files;
					o.DefaultValueDescription = false;
					o;
				},
				// Advanced
				{
					final o = new CommandLineOption();
					o.Name = "jsxFactory";
					o.Kind = CommandLineOptionTypeString;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_the_JSX_factory_function_used_when_targeting_React_JSX_emit_e_g_React_createElement_or_h;
					o.DefaultValueDescription = "`React.createElement`";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "jsxFragmentFactory";
					o.Kind = CommandLineOptionTypeString;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_the_JSX_Fragment_reference_used_for_fragments_when_targeting_React_JSX_emit_e_g_React_Fragment_or_Fragment;
					o.DefaultValueDescription = "React.Fragment";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "jsxImportSource";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsModuleResolution = true;
					o.AffectsSourceFile = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_module_specifier_used_to_import_the_JSX_factory_functions_when_using_jsx_Colon_react_jsx_Asterisk;
					o.DefaultValueDescription = "react";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "resolveJsonModule";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Enable_importing_json_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowArbitraryExtensions";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsProgramStructure = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Enable_importing_files_with_any_extension_provided_a_declaration_file_is_present;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "reactNamespace";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Specify_the_object_invoked_for_createElement_This_only_applies_when_targeting_react_JSX_emit;
					o.DefaultValueDescription = "`React`";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "skipDefaultLibCheck";
					o.Kind = CommandLineOptionTypeBoolean;
					// We need to store these to determine whether `lib` files need to be rechecked
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Completeness;
					o.Description = Diagnostics.Skip_type_checking_d_ts_files_that_are_included_with_TypeScript;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "emitBOM";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Emit_a_UTF_8_Byte_Order_Mark_BOM_in_the_beginning_of_output_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "newLine";
					o.Kind = CommandLineOptionTypeEnum; // newLineOptionMap,
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Set_the_newline_character_for_emitting_files;
					o.DefaultValueDescription = "lf";
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noErrorTruncation";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Output_Formatting;
					o.Description = Diagnostics.Disable_truncating_types_in_error_messages;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noLib";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Language_and_Environment;
					o.AffectsProgramStructure = true;
					o.Description = Diagnostics.Disable_including_any_library_files_including_the_default_lib_d_ts;
					// We are not returning a sourceFile for lib file when asked by the program,
					// so pass --noLib to avoid reporting a file not found error.
					o.transpileOptionValue = TSTrue;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noResolve";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Modules;
					o.Description = Diagnostics.Disallow_import_s_require_s_or_reference_s_from_expanding_the_number_of_files_TypeScript_should_add_to_a_project;
					// We are not doing a full typecheck, we are not resolving the whole context,
					// so pass --noResolve to avoid reporting missing file errors.
					o.transpileOptionValue = TSTrue;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "stripInternal";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Disable_emitting_declarations_that_have_internal_in_their_JSDoc_comments;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "disableSizeLimit";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsProgramStructure = true;
					o.Category = Diagnostics.Editor_Support;
					o.Description = Diagnostics.Remove_the_20mb_cap_on_total_source_code_size_for_JavaScript_files_in_the_TypeScript_language_server;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "disableSourceOfProjectReferenceRedirect";
					o.Kind = CommandLineOptionTypeBoolean;
					o.IsTSConfigOnly = true;
					o.Category = Diagnostics.Projects;
					o.Description = Diagnostics.Disable_preferring_source_files_instead_of_declaration_files_when_referencing_composite_projects;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "disableSolutionSearching";
					o.Kind = CommandLineOptionTypeBoolean;
					o.IsTSConfigOnly = true;
					o.Category = Diagnostics.Projects;
					o.Description = Diagnostics.Opt_a_project_out_of_multi_project_reference_checking_when_editing;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "disableReferencedProjectLoad";
					o.Kind = CommandLineOptionTypeBoolean;
					o.IsTSConfigOnly = true;
					o.Category = Diagnostics.Projects;
					o.Description = Diagnostics.Reduce_the_number_of_projects_loaded_automatically_by_TypeScript;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noEmitHelpers";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Disable_generating_custom_helper_functions_like_extends_in_compiled_output;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "noEmitOnError";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.transpileOptionValue = TSUnknown;
					o.Description = Diagnostics.Disable_emitting_files_if_any_type_checking_errors_are_reported;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "preserveConstEnums";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Emit;
					o.Description = Diagnostics.Disable_erasing_const_enum_declarations_in_generated_code;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "declarationDir";
					o.Kind = CommandLineOptionTypeString;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.AffectsDeclarationPath = true;
					o.IsFilePath = true;
					o.Category = Diagnostics.Emit;
					o.transpileOptionValue = TSUnknown;
					o.Description = Diagnostics.Specify_the_output_directory_for_generated_declaration_files;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "skipLibCheck";
					o.Kind = CommandLineOptionTypeBoolean;
					// We need to store these to determine whether `lib` files need to be rechecked
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Completeness;
					o.Description = Diagnostics.Skip_type_checking_all_d_ts_files;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowUnusedLabels";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsBindDiagnostics = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Disable_error_reporting_for_unused_labels;
					o.DefaultValueDescription = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "allowUnreachableCode";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsBindDiagnostics = true;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Type_Checking;
					o.Description = Diagnostics.Disable_error_reporting_for_unreachable_code;
					o.DefaultValueDescription = TSUnknown;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "forceConsistentCasingInFileNames";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.Interop_Constraints;
					o.Description = Diagnostics.Ensure_that_casing_is_correct_in_imports;
					o.DefaultValueDescription = true;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "maxNodeModuleJsDepth";
					o.Kind = CommandLineOptionTypeNumber;
					o.AffectsModuleResolution = true;
					o.Category = Diagnostics.JavaScript_Support;
					o.Description = Diagnostics.Specify_the_maximum_folder_depth_used_for_checking_JavaScript_files_from_node_modules_Only_applicable_with_allowJs;
					o.DefaultValueDescription = 0;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "useDefineForClassFields";
					o.Kind = CommandLineOptionTypeBoolean;
					o.AffectsSemanticDiagnostics = true;
					o.AffectsEmit = true;
					o.AffectsBuildInfo = true;
					o.Category = Diagnostics.Language_and_Environment;
					o.Description = Diagnostics.Emit_ECMAScript_standard_compliant_class_fields;
					o.DefaultValueDescription = Diagnostics.X_true_for_ES2022_and_above_including_ESNext;
					o;
				},
				{
					final o = new CommandLineOption();
					// A list of plugins to load in the language service
					o.Name = "plugins";
					o.Kind = CommandLineOptionTypeList;
					o.IsTSConfigOnly = true;
					o.Description = Diagnostics.Specify_a_list_of_language_service_plugins_to_include;
					o.Category = Diagnostics.Editor_Support;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "moduleDetection";
					o.Kind = CommandLineOptionTypeEnum;
					o.AffectsSourceFile = true;
					o.AffectsModuleResolution = true;
					o.Description = Diagnostics.Control_what_method_is_used_to_detect_module_format_JS_files;
					o.Category = Diagnostics.Language_and_Environment;
					o.DefaultValueDescription = Diagnostics.X_auto_Colon_Treat_files_with_imports_exports_import_meta_jsx_with_jsx_Colon_react_jsx_or_esm_format_with_module_Colon_node16_as_modules;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "ignoreDeprecations";
					o.Kind = CommandLineOptionTypeString;
					o.DefaultValueDescription = TSUnknown;
					o;
				},
			];
		}
		return _optionsForCompiler;
	}

	// PORT: `optionsType = reflect.TypeFor[core.CompilerOptions]()` → compilerOptionsFields (see
	// the end of this file).

	static function optionsHaveChanges(oldOptions:Null<CompilerOptions>, newOptions:Null<CompilerOptions>,
			declFilter:(CommandLineOption) -> Bool):Bool {
		if (oldOptions == newOptions) {
			return false;
		}
		if (oldOptions == null || newOptions == null) {
			return true;
		}
		return ForEachCompilerOptionValue(newOptions, declFilter, function(option:CommandLineOption, value:Dynamic, i:Int):Bool {
			final newValue = value;
			final oldValue = compilerOptionsFields[i].Get(oldOptions);
			if (option.strictFlag) {
				return oldOptions.GetStrictOptionValue((oldValue : Tristate)) != newOptions.GetStrictOptionValue((newValue : Tristate));
			}
			if (option.allowJsFlag) {
				return oldOptions.GetAllowJS() != newOptions.GetAllowJS();
			}
			return !compilerOptionsFields[i].DeepEqual(newValue, oldValue);
		});
	}

	// PORT: Go passes the field as a reflect.Value and its struct field index; here the field
	// value and its index in compilerOptionsFields.
	public static function ForEachCompilerOptionValue(options:CompilerOptions, declFilter:(CommandLineOption) -> Bool,
			fn:(option:CommandLineOption, value:Dynamic, i:Int) -> Bool):Bool {
		final fields = compilerOptionsFields;
		for (i in 0...fields.length) {
			final field = fields[i];
			final optionDeclaration = CommandLineCompilerOptionsMap.Get(field.Name);
			if (optionDeclaration != null && declFilter(optionDeclaration)) {
				if (fn(optionDeclaration, field.Get(options), i)) {
					return true;
				}
			}
		}
		return false;
	}

	public static function CompilerOptionsAffectSemanticDiagnostics(oldOptions:Null<CompilerOptions>, newOptions:Null<CompilerOptions>):Bool {
		return optionsHaveChanges(oldOptions, newOptions, function(option:CommandLineOption):Bool {
			return option.AffectsSemanticDiagnostics;
		});
	}

	public static function CompilerOptionsAffectDeclarationPath(oldOptions:Null<CompilerOptions>, newOptions:Null<CompilerOptions>):Bool {
		return optionsHaveChanges(oldOptions, newOptions, function(option:CommandLineOption):Bool {
			return option.AffectsDeclarationPath;
		});
	}

	public static function CompilerOptionsAffectEmit(oldOptions:Null<CompilerOptions>, newOptions:Null<CompilerOptions>):Bool {
		return optionsHaveChanges(oldOptions, newOptions, function(option:CommandLineOption):Bool {
			return option.AffectsEmit;
		});
	}

	// --- declstypeacquisition.go ---

	static var typeAcquisitionDeclaration(get, never):CommandLineOption;
	static var _typeAcquisitionDeclaration:CommandLineOption = null;

	static function get_typeAcquisitionDeclaration():CommandLineOption {
		if (_typeAcquisitionDeclaration == null) {
			final o = new CommandLineOption();
			o.Name = "typeAcquisition";
			o.Kind = CommandLineOptionTypeObject;
			o.ElementOptions = commandLineOptionsToMap(typeAcquisitionDecls);
			_typeAcquisitionDeclaration = o;
		}
		return _typeAcquisitionDeclaration;
	}

	// Do not delete this without updating the website's tsconfig generation.
	static var typeAcquisitionDecls(get, never):Array<CommandLineOption>;
	static var _typeAcquisitionDecls:Array<CommandLineOption> = null;

	static function get_typeAcquisitionDecls():Array<CommandLineOption> {
		if (_typeAcquisitionDecls == null) {
			_typeAcquisitionDecls = [
				{
					final o = new CommandLineOption();
					o.Name = "enable";
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "include";
					o.Kind = CommandLineOptionTypeList;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "exclude";
					o.Kind = CommandLineOptionTypeList;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "disableFilenameBasedTypeAcquisition";
					o.Kind = CommandLineOptionTypeBoolean;
					o.DefaultValueDescription = false;
					o;
				},
			];
		}
		return _typeAcquisitionDecls;
	}

	// --- declswatch.go ---

	public static var OptionsForWatch(get, never):Array<CommandLineOption>;
	static var _OptionsForWatch:Array<CommandLineOption> = null;

	static function get_OptionsForWatch():Array<CommandLineOption> {
		if (_OptionsForWatch == null) {
			_OptionsForWatch = [
				{
					final o = new CommandLineOption();
					o.Name = "watchInterval";
					o.Kind = CommandLineOptionTypeNumber;
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "watchFile";
					o.Kind = CommandLineOptionTypeEnum;
					// new Map(Object.entries({
					//     fixedpollinginterval: WatchFileKind.FixedPollingInterval,
					//     prioritypollinginterval: WatchFileKind.PriorityPollingInterval,
					//     dynamicprioritypolling: WatchFileKind.DynamicPriorityPolling,
					//     fixedchunksizepolling: WatchFileKind.FixedChunkSizePolling,
					//     usefsevents: WatchFileKind.UseFsEvents,
					//     usefseventsonparentdirectory: WatchFileKind.UseFsEventsOnParentDirectory,
					// })),
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Specify_how_the_TypeScript_watch_mode_works;
					o.DefaultValueDescription = WatchFileKindUseFsEvents;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "watchDirectory";
					o.Kind = CommandLineOptionTypeEnum;
					// new Map(Object.entries({
					//     usefsevents: WatchDirectoryKind.UseFsEvents,
					//     fixedpollinginterval: WatchDirectoryKind.FixedPollingInterval,
					//     dynamicprioritypolling: WatchDirectoryKind.DynamicPriorityPolling,
					//     fixedchunksizepolling: WatchDirectoryKind.FixedChunkSizePolling,
					// })),
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Specify_how_directories_are_watched_on_systems_that_lack_recursive_file_watching_functionality;
					o.DefaultValueDescription = WatchDirectoryKindUseFsEvents;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "fallbackPolling";
					o.Kind = CommandLineOptionTypeEnum;
					// new Map(Object.entries({
					//     fixedinterval: PollingWatchKind.FixedInterval,
					//     priorityinterval: PollingWatchKind.PriorityInterval,
					//     dynamicpriority: PollingWatchKind.DynamicPriority,
					//     fixedchunksize: PollingWatchKind.FixedChunkSize,
					// })),
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Specify_what_approach_the_watcher_should_use_if_the_system_runs_out_of_native_file_watchers;
					o.DefaultValueDescription = PollingKindPriorityInterval;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "synchronousWatchDirectory";
					o.Kind = CommandLineOptionTypeBoolean;
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Synchronously_call_callbacks_and_update_the_state_of_directory_watchers_on_platforms_that_don_t_support_recursive_watching_natively;
					o.DefaultValueDescription = false;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "excludeDirectories";
					o.Kind = CommandLineOptionTypeList;
					// element: {
					//     Name: "excludeDirectory",
					//     Kind: "string",
					//     isFilePath: true,
					//     extraValidation: specToDiagnostic,
					// },
					o.allowConfigDirTemplateSubstitution = true;
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Remove_a_list_of_directories_from_the_watch_process;
					o;
				},
				{
					final o = new CommandLineOption();
					o.Name = "excludeFiles";
					o.Kind = CommandLineOptionTypeList;
					// element: {
					//     Name: "excludeFile",
					//     Kind: "string",
					//     isFilePath: true,
					//     extraValidation: specToDiagnostic,
					// },
					o.allowConfigDirTemplateSubstitution = true;
					o.Category = Diagnostics.Watch_and_Build_Modes;
					o.Description = Diagnostics.Remove_a_list_of_files_from_the_watch_mode_s_processing;
					o;
				},
			];
		}
		return _OptionsForWatch;
	}

	// --- diagnostics.go ---

	public static var CompilerOptionsDidYouMeanDiagnostics(get, never):ParseCommandLineWorkerDiagnostics;
	static var _CompilerOptionsDidYouMeanDiagnostics:ParseCommandLineWorkerDiagnostics = null;

	static function get_CompilerOptionsDidYouMeanDiagnostics():ParseCommandLineWorkerDiagnostics {
		if (_CompilerOptionsDidYouMeanDiagnostics == null) {
			_CompilerOptionsDidYouMeanDiagnostics = getParseCommandLineWorkerDiagnostics(OptionsDeclarations);
		}
		return _CompilerOptionsDidYouMeanDiagnostics;
	}

	static function getParseCommandLineWorkerDiagnostics(decls:Array<CommandLineOption>):ParseCommandLineWorkerDiagnostics {
		// this will only return the correct diagnostics for `compiler` mode, and is factored into a function for testing reasons.
		final r = new ParseCommandLineWorkerDiagnostics();
		r.didYouMean.alternateMode = new AlternateModeDiagnostics(Diagnostics.Compiler_option_0_may_only_be_used_with_build, BuildNameMap);
		r.didYouMean.OptionDeclarations = decls;
		r.didYouMean.UnknownOptionDiagnostic = Diagnostics.Unknown_compiler_option_0;
		r.didYouMean.UnknownDidYouMeanDiagnostic = Diagnostics.Unknown_compiler_option_0_Did_you_mean_1;
		r.OptionTypeMismatchDiagnostic = Diagnostics.Compiler_option_0_expects_an_argument;
		return r;
	}

	static var watchOptionsDidYouMeanDiagnostics(get, never):ParseCommandLineWorkerDiagnostics;
	static var _watchOptionsDidYouMeanDiagnostics:ParseCommandLineWorkerDiagnostics = null;

	static function get_watchOptionsDidYouMeanDiagnostics():ParseCommandLineWorkerDiagnostics {
		if (_watchOptionsDidYouMeanDiagnostics == null) {
			final r = new ParseCommandLineWorkerDiagnostics();
			// no alternateMode
			r.didYouMean.OptionDeclarations = OptionsForWatch;
			r.didYouMean.UnknownOptionDiagnostic = Diagnostics.Unknown_watch_option_0;
			r.didYouMean.UnknownDidYouMeanDiagnostic = Diagnostics.Unknown_watch_option_0_Did_you_mean_1;
			r.OptionTypeMismatchDiagnostic = Diagnostics.Watch_option_0_requires_a_value_of_type_1;
			_watchOptionsDidYouMeanDiagnostics = r;
		}
		return _watchOptionsDidYouMeanDiagnostics;
	}

	static var buildOptionsDidYouMeanDiagnostics(get, never):ParseCommandLineWorkerDiagnostics;
	static var _buildOptionsDidYouMeanDiagnostics:ParseCommandLineWorkerDiagnostics = null;

	static function get_buildOptionsDidYouMeanDiagnostics():ParseCommandLineWorkerDiagnostics {
		if (_buildOptionsDidYouMeanDiagnostics == null) {
			final r = new ParseCommandLineWorkerDiagnostics();
			r.didYouMean.alternateMode = new AlternateModeDiagnostics(Diagnostics.Compiler_option_0_may_not_be_used_with_build, CompilerNameMap);
			r.didYouMean.OptionDeclarations = BuildOpts;
			r.didYouMean.UnknownOptionDiagnostic = Diagnostics.Unknown_build_option_0;
			r.didYouMean.UnknownDidYouMeanDiagnostic = Diagnostics.Unknown_build_option_0_Did_you_mean_1;
			r.OptionTypeMismatchDiagnostic = Diagnostics.Build_option_0_requires_a_value_of_type_1;
			_buildOptionsDidYouMeanDiagnostics = r;
		}
		return _buildOptionsDidYouMeanDiagnostics;
	}

	// --- enummaps.go ---

	public static var LibMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _LibMap:OrderedMap<std.String, Dynamic> = null;

	static function get_LibMap():OrderedMap<std.String, Dynamic> {
		if (_LibMap == null) {
			_LibMap = Collections.NewOrderedMapFromList([
				// JavaScript only
				new MapEntry<std.String, Dynamic>("es5", "lib.es5.d.ts"),
				new MapEntry<std.String, Dynamic>("es6", "lib.es2015.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015", "lib.es2015.d.ts"),
				new MapEntry<std.String, Dynamic>("es7", "lib.es2016.d.ts"),
				new MapEntry<std.String, Dynamic>("es2016", "lib.es2016.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017", "lib.es2017.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018", "lib.es2018.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019", "lib.es2019.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020", "lib.es2020.d.ts"),
				new MapEntry<std.String, Dynamic>("es2021", "lib.es2021.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022", "lib.es2022.d.ts"),
				new MapEntry<std.String, Dynamic>("es2023", "lib.es2023.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024", "lib.es2024.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025", "lib.es2025.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext", "lib.esnext.d.ts"),
				// Host only
				new MapEntry<std.String, Dynamic>("dom", "lib.dom.d.ts"),
				new MapEntry<std.String, Dynamic>("dom.iterable", "lib.dom.iterable.d.ts"),
				new MapEntry<std.String, Dynamic>("dom.asynciterable", "lib.dom.asynciterable.d.ts"),
				new MapEntry<std.String, Dynamic>("webworker", "lib.webworker.d.ts"),
				new MapEntry<std.String, Dynamic>("webworker.importscripts", "lib.webworker.importscripts.d.ts"),
				new MapEntry<std.String, Dynamic>("webworker.iterable", "lib.webworker.iterable.d.ts"),
				new MapEntry<std.String, Dynamic>("webworker.asynciterable", "lib.webworker.asynciterable.d.ts"),
				new MapEntry<std.String, Dynamic>("scripthost", "lib.scripthost.d.ts"),
				// ES2015 and later By-feature options
				new MapEntry<std.String, Dynamic>("es2015.core", "lib.es2015.core.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.collection", "lib.es2015.collection.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.generator", "lib.es2015.generator.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.iterable", "lib.es2015.iterable.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.promise", "lib.es2015.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.proxy", "lib.es2015.proxy.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.reflect", "lib.es2015.reflect.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.symbol", "lib.es2015.symbol.d.ts"),
				new MapEntry<std.String, Dynamic>("es2015.symbol.wellknown", "lib.es2015.symbol.wellknown.d.ts"),
				new MapEntry<std.String, Dynamic>("es2016.array.include", "lib.es2016.array.include.d.ts"),
				new MapEntry<std.String, Dynamic>("es2016.intl", "lib.es2016.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.arraybuffer", "lib.es2017.arraybuffer.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.date", "lib.es2017.date.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.object", "lib.es2017.object.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.sharedmemory", "lib.es2017.sharedmemory.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.string", "lib.es2017.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.intl", "lib.es2017.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2017.typedarrays", "lib.es2017.typedarrays.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018.asyncgenerator", "lib.es2018.asyncgenerator.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018.asynciterable", "lib.es2018.asynciterable.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018.intl", "lib.es2018.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018.promise", "lib.es2018.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2018.regexp", "lib.es2018.regexp.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019.array", "lib.es2019.array.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019.object", "lib.es2019.object.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019.string", "lib.es2019.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019.symbol", "lib.es2019.symbol.d.ts"),
				new MapEntry<std.String, Dynamic>("es2019.intl", "lib.es2019.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.bigint", "lib.es2020.bigint.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.date", "lib.es2020.date.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.promise", "lib.es2020.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.sharedmemory", "lib.es2020.sharedmemory.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.string", "lib.es2020.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.symbol.wellknown", "lib.es2020.symbol.wellknown.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.intl", "lib.es2020.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2020.number", "lib.es2020.number.d.ts"),
				new MapEntry<std.String, Dynamic>("es2021.promise", "lib.es2021.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2021.string", "lib.es2021.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2021.weakref", "lib.es2021.weakref.d.ts"),
				new MapEntry<std.String, Dynamic>("es2021.intl", "lib.es2021.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.array", "lib.es2022.array.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.error", "lib.es2022.error.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.intl", "lib.es2022.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.object", "lib.es2022.object.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.string", "lib.es2022.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2022.regexp", "lib.es2022.regexp.d.ts"),
				new MapEntry<std.String, Dynamic>("es2023.array", "lib.es2023.array.d.ts"),
				new MapEntry<std.String, Dynamic>("es2023.collection", "lib.es2023.collection.d.ts"),
				new MapEntry<std.String, Dynamic>("es2023.intl", "lib.es2023.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.arraybuffer", "lib.es2024.arraybuffer.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.collection", "lib.es2024.collection.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.object", "lib.es2024.object.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.promise", "lib.es2024.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.regexp", "lib.es2024.regexp.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.sharedmemory", "lib.es2024.sharedmemory.d.ts"),
				new MapEntry<std.String, Dynamic>("es2024.string", "lib.es2024.string.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.collection", "lib.es2025.collection.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.float16", "lib.es2025.float16.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.intl", "lib.es2025.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.iterator", "lib.es2025.iterator.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.promise", "lib.es2025.promise.d.ts"),
				new MapEntry<std.String, Dynamic>("es2025.regexp", "lib.es2025.regexp.d.ts"),
				// Fallback for backward compatibility
				new MapEntry<std.String, Dynamic>("esnext.asynciterable", "lib.es2018.asynciterable.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.symbol", "lib.es2019.symbol.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.bigint", "lib.es2020.bigint.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.weakref", "lib.es2021.weakref.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.object", "lib.es2024.object.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.regexp", "lib.es2024.regexp.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.string", "lib.es2024.string.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.float16", "lib.es2025.float16.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.iterator", "lib.es2025.iterator.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.promise", "lib.es2025.promise.d.ts"),
				// ESNext By-feature options
				new MapEntry<std.String, Dynamic>("esnext.array", "lib.esnext.array.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.collection", "lib.esnext.collection.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.date", "lib.esnext.date.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.decorators", "lib.esnext.decorators.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.disposable", "lib.esnext.disposable.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.error", "lib.esnext.error.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.intl", "lib.esnext.intl.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.sharedmemory", "lib.esnext.sharedmemory.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.temporal", "lib.esnext.temporal.d.ts"),
				new MapEntry<std.String, Dynamic>("esnext.typedarrays", "lib.esnext.typedarrays.d.ts"),
				// Decorators
				new MapEntry<std.String, Dynamic>("decorators", "lib.decorators.d.ts"),
				new MapEntry<std.String, Dynamic>("decorators.legacy", "lib.decorators.legacy.d.ts"),
			]);
		}
		return _LibMap;
	}

	public static var Libs(get, never):Null<Array<std.String>>;
	static var _Libs:Null<Array<std.String>> = null;

	static function get_Libs():Null<Array<std.String>> {
		if (_Libs == null) {
			_Libs = Slices.Collect(LibMap.Keys());
		}
		return _Libs;
	}

	public static var LibFilesSet(get, never):Set<std.String>;
	static var _LibFilesSet:Set<std.String> = null;

	static function get_LibFilesSet():Set<std.String> {
		if (_LibFilesSet == null) {
			_LibFilesSet = Collections.NewSetFromItems(...Core.Map(Slices.Collect(LibMap.Values()), function(s:Dynamic):std.String {
				return mustString(s);
			}));
		}
		return _LibFilesSet;
	}

	// PORT: (string, bool) → ValueOk.
	public static function GetLibFileName(libName:std.String):ValueOk<std.String> {
		// checks if the libName is a valid lib name or file name and converts the lib name to the filename if needed
		libName = Tspath.ToFileNameLowerCase(libName);
		if (LibFilesSet.Has(libName)) {
			return new ValueOk<std.String>(libName, true);
		}
		final r = LibMap.Get(libName);
		if (!r.ok) {
			return new ValueOk<std.String>("", false);
		}
		return new ValueOk<std.String>(mustString(r.value), true);
	}

	static var moduleResolutionOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _moduleResolutionOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_moduleResolutionOptionMap():OrderedMap<std.String, Dynamic> {
		if (_moduleResolutionOptionMap == null) {
			_moduleResolutionOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("node16", ModuleResolutionKindNode16),
				new MapEntry<std.String, Dynamic>("nodenext", ModuleResolutionKindNodeNext),
				new MapEntry<std.String, Dynamic>("bundler", ModuleResolutionKindBundler),
				new MapEntry<std.String, Dynamic>("classic", ModuleResolutionKindClassic),
				new MapEntry<std.String, Dynamic>("node", ModuleResolutionKindNode10),
				new MapEntry<std.String, Dynamic>("node10", ModuleResolutionKindNode10),
			]);
		}
		return _moduleResolutionOptionMap;
	}

	static var targetOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _targetOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_targetOptionMap():OrderedMap<std.String, Dynamic> {
		if (_targetOptionMap == null) {
			_targetOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("es5", ScriptTargetES5),
				new MapEntry<std.String, Dynamic>("es6", ScriptTargetES2015),
				new MapEntry<std.String, Dynamic>("es2015", ScriptTargetES2015),
				new MapEntry<std.String, Dynamic>("es2016", ScriptTargetES2016),
				new MapEntry<std.String, Dynamic>("es2017", ScriptTargetES2017),
				new MapEntry<std.String, Dynamic>("es2018", ScriptTargetES2018),
				new MapEntry<std.String, Dynamic>("es2019", ScriptTargetES2019),
				new MapEntry<std.String, Dynamic>("es2020", ScriptTargetES2020),
				new MapEntry<std.String, Dynamic>("es2021", ScriptTargetES2021),
				new MapEntry<std.String, Dynamic>("es2022", ScriptTargetES2022),
				new MapEntry<std.String, Dynamic>("es2023", ScriptTargetES2023),
				new MapEntry<std.String, Dynamic>("es2024", ScriptTargetES2024),
				new MapEntry<std.String, Dynamic>("es2025", ScriptTargetES2025),
				new MapEntry<std.String, Dynamic>("esnext", ScriptTargetESNext),
			]);
		}
		return _targetOptionMap;
	}

	static var moduleOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _moduleOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_moduleOptionMap():OrderedMap<std.String, Dynamic> {
		if (_moduleOptionMap == null) {
			_moduleOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("commonjs", ModuleKindCommonJS),
				new MapEntry<std.String, Dynamic>("amd", ModuleKindAMD),
				new MapEntry<std.String, Dynamic>("system", ModuleKindSystem),
				new MapEntry<std.String, Dynamic>("umd", ModuleKindUMD),
				new MapEntry<std.String, Dynamic>("es6", ModuleKindES2015),
				new MapEntry<std.String, Dynamic>("es2015", ModuleKindES2015),
				new MapEntry<std.String, Dynamic>("es2020", ModuleKindES2020),
				new MapEntry<std.String, Dynamic>("es2022", ModuleKindES2022),
				new MapEntry<std.String, Dynamic>("esnext", ModuleKindESNext),
				new MapEntry<std.String, Dynamic>("node16", ModuleKindNode16),
				new MapEntry<std.String, Dynamic>("node18", ModuleKindNode18),
				new MapEntry<std.String, Dynamic>("node20", ModuleKindNode20),
				new MapEntry<std.String, Dynamic>("nodenext", ModuleKindNodeNext),
				new MapEntry<std.String, Dynamic>("preserve", ModuleKindPreserve),
			]);
		}
		return _moduleOptionMap;
	}

	static var moduleDetectionOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _moduleDetectionOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_moduleDetectionOptionMap():OrderedMap<std.String, Dynamic> {
		if (_moduleDetectionOptionMap == null) {
			_moduleDetectionOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("auto", ModuleDetectionKindAuto),
				new MapEntry<std.String, Dynamic>("legacy", ModuleDetectionKindLegacy),
				new MapEntry<std.String, Dynamic>("force", ModuleDetectionKindForce),
			]);
		}
		return _moduleDetectionOptionMap;
	}

	static var jsxOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _jsxOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_jsxOptionMap():OrderedMap<std.String, Dynamic> {
		if (_jsxOptionMap == null) {
			_jsxOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("preserve", JsxEmitPreserve),
				new MapEntry<std.String, Dynamic>("react-native", JsxEmitReactNative),
				new MapEntry<std.String, Dynamic>("react-jsx", JsxEmitReactJSX),
				new MapEntry<std.String, Dynamic>("react-jsxdev", JsxEmitReactJSXDev),
				new MapEntry<std.String, Dynamic>("react", JsxEmitReact),
			]);
		}
		return _jsxOptionMap;
	}

	static var newLineOptionMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _newLineOptionMap:OrderedMap<std.String, Dynamic> = null;

	static function get_newLineOptionMap():OrderedMap<std.String, Dynamic> {
		if (_newLineOptionMap == null) {
			_newLineOptionMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("crlf", NewLineKindCRLF),
				new MapEntry<std.String, Dynamic>("lf", NewLineKindLF),
			]);
		}
		return _newLineOptionMap;
	}

	static var targetToLibMap(get, never):IntMap<std.String>;
	static var _targetToLibMap:IntMap<std.String> = null;

	static function get_targetToLibMap():IntMap<std.String> {
		if (_targetToLibMap == null) {
			final m = new IntMap<std.String>();
			m.set(ScriptTargetESNext, "lib.esnext.full.d.ts");
			m.set(ScriptTargetES2025, "lib.es2025.full.d.ts");
			m.set(ScriptTargetES2024, "lib.es2024.full.d.ts");
			m.set(ScriptTargetES2023, "lib.es2023.full.d.ts");
			m.set(ScriptTargetES2022, "lib.es2022.full.d.ts");
			m.set(ScriptTargetES2021, "lib.es2021.full.d.ts");
			m.set(ScriptTargetES2020, "lib.es2020.full.d.ts");
			m.set(ScriptTargetES2019, "lib.es2019.full.d.ts");
			m.set(ScriptTargetES2018, "lib.es2018.full.d.ts");
			m.set(ScriptTargetES2017, "lib.es2017.full.d.ts");
			m.set(ScriptTargetES2016, "lib.es2016.full.d.ts");
			m.set(ScriptTargetES2015, "lib.es6.d.ts"); // We don't use lib.es2015.full.d.ts due to breaking change.
			_targetToLibMap = m;
		}
		return _targetToLibMap;
	}

	public static function TargetToLibMap():IntMap<std.String> {
		return targetToLibMap;
	}

	public static function GetDefaultLibFileName(options:CompilerOptions):std.String {
		final target:Int = options.GetEmitScriptTarget();
		if (!targetToLibMap.exists(target)) {
			return "lib.d.ts";
		}
		return targetToLibMap.get(target);
	}

	static var watchFileEnumMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _watchFileEnumMap:OrderedMap<std.String, Dynamic> = null;

	static function get_watchFileEnumMap():OrderedMap<std.String, Dynamic> {
		if (_watchFileEnumMap == null) {
			_watchFileEnumMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("fixedpollinginterval", WatchFileKindFixedPollingInterval),
				new MapEntry<std.String, Dynamic>("prioritypollinginterval", WatchFileKindPriorityPollingInterval),
				new MapEntry<std.String, Dynamic>("dynamicprioritypolling", WatchFileKindDynamicPriorityPolling),
				new MapEntry<std.String, Dynamic>("fixedchunksizepolling", WatchFileKindFixedChunkSizePolling),
				new MapEntry<std.String, Dynamic>("usefsevents", WatchFileKindUseFsEvents),
				new MapEntry<std.String, Dynamic>("usefseventsonparentdirectory", WatchFileKindUseFsEventsOnParentDirectory),
			]);
		}
		return _watchFileEnumMap;
	}

	static var watchDirectoryEnumMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _watchDirectoryEnumMap:OrderedMap<std.String, Dynamic> = null;

	static function get_watchDirectoryEnumMap():OrderedMap<std.String, Dynamic> {
		if (_watchDirectoryEnumMap == null) {
			_watchDirectoryEnumMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("usefsevents", WatchDirectoryKindUseFsEvents),
				new MapEntry<std.String, Dynamic>("fixedpollinginterval", WatchDirectoryKindFixedPollingInterval),
				new MapEntry<std.String, Dynamic>("dynamicprioritypolling", WatchDirectoryKindDynamicPriorityPolling),
				new MapEntry<std.String, Dynamic>("fixedchunksizepolling", WatchDirectoryKindFixedChunkSizePolling),
			]);
		}
		return _watchDirectoryEnumMap;
	}

	static var fallbackEnumMap(get, never):OrderedMap<std.String, Dynamic>;
	static var _fallbackEnumMap:OrderedMap<std.String, Dynamic> = null;

	static function get_fallbackEnumMap():OrderedMap<std.String, Dynamic> {
		if (_fallbackEnumMap == null) {
			_fallbackEnumMap = Collections.NewOrderedMapFromList([
				new MapEntry<std.String, Dynamic>("fixedinterval", PollingKindFixedInterval),
				new MapEntry<std.String, Dynamic>("priorityinterval", PollingKindPriorityInterval),
				new MapEntry<std.String, Dynamic>("dynamicpriority", PollingKindDynamicPriority),
				new MapEntry<std.String, Dynamic>("fixedchunksize", PollingKindFixedChunkSize),
			]);
		}
		return _fallbackEnumMap;
	}

	// --- errors.go ---

	static function createDiagnosticForInvalidEnumType(opt:CommandLineOption, sourceFile:Null<SourceFile>, node:Null<Node>):Diagnostic {
		final namesOfType = Slices.Collect(opt.EnumMap().Keys());
		final stringNames = formatEnumTypeKeys(opt, namesOfType);
		final optName = "--" + opt.Name;
		return CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, node, Diagnostics.Argument_for_0_option_must_be_Colon_1, optName,
			stringNames);
	}

	static function formatEnumTypeKeys(opt:CommandLineOption, keys:Null<Array<std.String>>):std.String {
		if (opt.DeprecatedKeys() != null) {
			keys = Core.Filter(keys, function(key:std.String):Bool {
				return !opt.DeprecatedKeys().Has(key);
			});
		}
		return "'" + (keys == null ? "" : keys.join("', '")) + "'";
	}

	static function getCompilerOptionValueTypeString(option:CommandLineOption):std.String {
		switch (option.Kind) {
			case CommandLineOptionTypeListOrElement:
				return getCompilerOptionValueTypeString(option.Elements()) + " or Array";
			case CommandLineOptionTypeList:
				return "Array";
			default:
				return (option.Kind : std.String);
		}
	}

	static function createUnknownOptionError(unknownOption:std.String, unknownOptionDiagnostic:Message,
			unknownOptionErrorText:std.String, // optional
			node:Null<Node>, // optional
			sourceFile:Null<SourceFile>, // optional
			alternateMode:Null<AlternateModeDiagnostics> // optional
	):Diagnostic {
		if (alternateMode != null && alternateMode.optionsNameMap != null) {
			final otherOption = alternateMode.optionsNameMap.Get(Strings.ToLower(unknownOption));
			if (otherOption != null) {
				// tscbuildoption
				var diagnostic = alternateMode.diagnostic;
				if (otherOption.Name == "build") {
					diagnostic = Diagnostics.Option_build_must_be_the_first_command_line_argument;
				}
				return CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, node, diagnostic, unknownOption);
			}
		}
		if (unknownOptionErrorText == "") {
			unknownOptionErrorText = unknownOption;
		}
		// TODO: possibleOption := spelling suggestion
		return CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, node, unknownOptionDiagnostic, unknownOptionErrorText);
	}

	public static function CreateDiagnosticForNodeInSourceFile(sourceFile:SourceFile, node:Node, message:Message, ...args:Any):Diagnostic {
		return Ast.NewDiagnostic(sourceFile, Core.NewTextRange(Scanner.SkipTrivia(sourceFile.Text(), node.Loc.Pos()), node.End()), message, ...args);
	}

	public static function CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile:Null<SourceFile>, node:Null<Node>, message:Message,
			...args:Any):Diagnostic {
		if (sourceFile != null && node != null) {
			return CreateDiagnosticForNodeInSourceFile(sourceFile, node, message, ...args);
		}
		return Ast.NewCompilerDiagnostic(message, ...args);
	}

	static function extraKeyDiagnostics(s:std.String):Null<Message> {
		switch (s) {
			case "compilerOptions":
				return Diagnostics.Unknown_compiler_option_0;
			case "watchOptions":
				return Diagnostics.Unknown_watch_option_0;
			case "typeAcquisition":
				return Diagnostics.Unknown_type_acquisition_option_0;
			case "buildOptions":
				return Diagnostics.Unknown_build_option_0;
			default:
				return null;
		}
	}

	static function extraKeyDidYouMeanDiagnostics(s:std.String):Null<Message> {
		switch (s) {
			case "compilerOptions":
				return Diagnostics.Unknown_compiler_option_0_Did_you_mean_1;
			case "watchOptions":
				return Diagnostics.Unknown_watch_option_0_Did_you_mean_1;
			case "typeAcquisition":
				return Diagnostics.Unknown_type_acquisition_option_0_Did_you_mean_1;
			case "buildOptions":
				return Diagnostics.Unknown_build_option_0_Did_you_mean_1;
			default:
				return null;
		}
	}

	// --- namemap.go ---

	public static var CompilerNameMap(get, never):NameMap;
	static var _CompilerNameMap:NameMap = null;

	static function get_CompilerNameMap():NameMap {
		if (_CompilerNameMap == null) {
			_CompilerNameMap = GetNameMapFromList(OptionsDeclarations);
		}
		return _CompilerNameMap;
	}

	public static var BuildNameMap(get, never):NameMap;
	static var _BuildNameMap:NameMap = null;

	static function get_BuildNameMap():NameMap {
		if (_BuildNameMap == null) {
			_BuildNameMap = GetNameMapFromList(BuildOpts);
		}
		return _BuildNameMap;
	}

	public static var WatchNameMap(get, never):NameMap;
	static var _WatchNameMap:NameMap = null;

	static function get_WatchNameMap():NameMap {
		if (_WatchNameMap == null) {
			_WatchNameMap = GetNameMapFromList(OptionsForWatch);
		}
		return _WatchNameMap;
	}

	public static function GetNameMapFromList(optDecls:Null<Array<CommandLineOption>>):NameMap {
		final optionsNames = Collections.NewOrderedMapWithSizeHint(Core.len(optDecls), (null : CommandLineOption));
		final shortOptionNames = new StringMap<std.String>();
		if (optDecls != null) {
			for (option in optDecls) {
				optionsNames.Set(Strings.ToLower(option.Name), option);
				if (option.ShortName != "") {
					shortOptionNames.set(option.ShortName, option.Name);
				}
			}
		}
		return new NameMap(optionsNames, shortOptionNames);
	}

	// --- parsedcommandline.go ---

	static inline final fileGlobPattern = "*.{js,jsx,mjs,cjs,ts,tsx,mts,cts,json}";
	static inline final recursiveFileGlobPattern = "**/*.{js,jsx,mjs,cjs,ts,tsx,mts,cts,json}";

	public static function NewParsedCommandLine(compilerOptions:CompilerOptions, rootFileNames:Null<Array<std.String>>,
			comparePathsOptions:ComparePathsOptions):ParsedCommandLine {
		final p = new ParsedCommandLine();
		final parsedConfig = new ParsedOptions();
		parsedConfig.CompilerOptions = compilerOptions;
		parsedConfig.FileNames = rootFileNames;
		p.ParsedConfig = parsedConfig;
		p.comparePathsOptions = comparePathsOptions;
		return p;
	}

	// --- parsinghelpers.go ---

	public static function ParseTristate(value:Dynamic):Tristate {
		if (value == null) {
			return TSUnknown;
		}
		// PORT: a core.Tristate in an `any` is an Int here (Go `value.(core.Tristate)`).
		if (!isBool(value) && Std.isOfType(value, Int)) {
			return (value : Tristate);
		}
		if (isBool(value) && (value : Bool) == true) {
			return TSTrue;
		} else {
			return TSFalse;
		}
	}

	public static function ParseStringArray(value:Dynamic):Null<Array<std.String>> {
		if (isAnySlice(value)) {
			final arr = asAnySlice(value);
			if (arr == null) {
				return null;
			}
			final result:Array<std.String> = [];
			for (v in arr) {
				if (isString(v)) {
					result.push(v);
				}
			}
			return result;
		}
		return null;
	}

	static function parseStringMap(value:Dynamic):Null<OrderedMap<std.String, Array<std.String>>> {
		if (isOrderedMap(value)) {
			final m:OrderedMap<std.String, Dynamic> = value;
			final result = Collections.NewOrderedMapWithSizeHint(m.Size(), (null : Array<std.String>));
			for (k => v in m.Entries()) {
				result.Set(k, ParseStringArray(v));
			}
			return result;
		}
		return null;
	}

	public static function ParseString(value:Dynamic):std.String {
		if (isString(value)) {
			return value;
		}
		return "";
	}

	// PORT: *int → Null<Int>. Go tells int from float64; both are numbers here and give the
	// same result (int(num) truncates).
	static function parseNumber(value:Dynamic):Null<Int> {
		if (isBool(value) || value == null) {
			return null;
		}
		if (Std.isOfType(value, Int)) {
			final num:Int = value;
			return num;
		}
		if (Std.isOfType(value, Float)) {
			final n = Std.int((value : Float));
			return n;
		}
		return null;
	}

	static function parseProjectReference(json:Dynamic):Null<Array<ProjectReference>> {
		var result:Null<Array<ProjectReference>> = null;
		if (isOrderedMap(json)) {
			final v:OrderedMap<std.String, Dynamic> = json;
			final reference = new ProjectReference();
			final p = v.Get("path");
			if (p.ok) {
				reference.Path = mustString(p.value);
			}
			final c = v.Get("circular");
			if (c.ok) {
				reference.Circular = mustBool(c.value);
			}
			result = [reference];
		}
		return result;
	}

	static function parseJsonToStringKey(json:Dynamic):OrderedMap<std.String, Dynamic> {
		final result:OrderedMap<std.String, Dynamic> = Collections.NewOrderedMapWithSizeHint(6, (null : Dynamic));
		if (isOrderedMap(json)) {
			final m:OrderedMap<std.String, Dynamic> = json;
			var r = m.Get("include");
			if (r.ok) {
				result.Set("include", r.value);
			}
			r = m.Get("exclude");
			if (r.ok) {
				result.Set("exclude", r.value);
			}
			r = m.Get("files");
			if (r.ok) {
				result.Set("files", r.value);
			}
			r = m.Get("references");
			if (r.ok) {
				result.Set("references", r.value);
			}
			r = m.Get("extends");
			if (r.ok) {
				final v = r.value;
				if (isString(v)) {
					final str:std.String = v;
					result.Set("extends", ([str] : Array<Dynamic>));
				}
				result.Set("extends", v);
			}
			r = m.Get("compilerOptions");
			if (r.ok) {
				result.Set("compilerOptions", r.value);
			}
			r = m.Get("excludes");
			if (r.ok) {
				result.Set("excludes", r.value);
			}
			r = m.Get("typeAcquisition");
			if (r.ok) {
				result.Set("typeAcquisition", r.value);
			}
		}
		return result;
	}

	public static function ParseCompilerOptions(key:std.String, value:Dynamic, allOptions:Null<CompilerOptions>):Null<Array<Diagnostic>> {
		if (value == null) {
			return null;
		}
		if (allOptions == null) {
			return null;
		}
		parseCompilerOptions(key, value, allOptions);
		return null;
	}

	static function parseCompilerOptions(key:std.String, value:Dynamic, allOptions:CompilerOptions):Bool /* foundKey */ {
		final option = CommandLineCompilerOptionsMap.Get(key);
		if (option != null) {
			key = option.Name;
		}
		switch (key) {
			case "allowJs":
				allOptions.AllowJs = ParseTristate(value);
			case "allowImportingTsExtensions":
				allOptions.AllowImportingTsExtensions = ParseTristate(value);
			case "allowSyntheticDefaultImports":
				allOptions.AllowSyntheticDefaultImports = ParseTristate(value);
			case "allowNonTsExtensions":
				allOptions.AllowNonTsExtensions = ParseTristate(value);
			case "allowUmdGlobalAccess":
				allOptions.AllowUmdGlobalAccess = ParseTristate(value);
			case "allowUnreachableCode":
				allOptions.AllowUnreachableCode = ParseTristate(value);
			case "allowUnusedLabels":
				allOptions.AllowUnusedLabels = ParseTristate(value);
			case "allowArbitraryExtensions":
				allOptions.AllowArbitraryExtensions = ParseTristate(value);
			case "alwaysStrict":
				allOptions.AlwaysStrict = ParseTristate(value);
			case "assumeChangesOnlyAffectDirectDependencies":
				allOptions.AssumeChangesOnlyAffectDirectDependencies = ParseTristate(value);
			case "baseUrl":
				allOptions.BaseUrl = ParseString(value);
			case "build":
				allOptions.Build = ParseTristate(value);
			case "checkJs":
				allOptions.CheckJs = ParseTristate(value);
			case "customConditions":
				allOptions.CustomConditions = ParseStringArray(value);
			case "composite":
				allOptions.Composite = ParseTristate(value);
			case "declarationDir":
				allOptions.DeclarationDir = ParseString(value);
			case "deduplicatePackages":
				allOptions.DeduplicatePackages = ParseTristate(value);
			case "diagnostics":
				allOptions.Diagnostics = ParseTristate(value);
			case "disableSizeLimit":
				allOptions.DisableSizeLimit = ParseTristate(value);
			case "disableSourceOfProjectReferenceRedirect":
				allOptions.DisableSourceOfProjectReferenceRedirect = ParseTristate(value);
			case "disableSolutionSearching":
				allOptions.DisableSolutionSearching = ParseTristate(value);
			case "disableReferencedProjectLoad":
				allOptions.DisableReferencedProjectLoad = ParseTristate(value);
			case "declarationMap":
				allOptions.DeclarationMap = ParseTristate(value);
			case "declaration":
				allOptions.Declaration = ParseTristate(value);
			case "downlevelIteration":
				allOptions.DownlevelIteration = ParseTristate(value);
			case "erasableSyntaxOnly":
				allOptions.ErasableSyntaxOnly = ParseTristate(value);
			case "emitDeclarationOnly":
				allOptions.EmitDeclarationOnly = ParseTristate(value);
			case "extendedDiagnostics":
				allOptions.ExtendedDiagnostics = ParseTristate(value);
			case "emitDecoratorMetadata":
				allOptions.EmitDecoratorMetadata = ParseTristate(value);
			case "emitBOM":
				allOptions.EmitBOM = ParseTristate(value);
			case "esModuleInterop":
				allOptions.ESModuleInterop = ParseTristate(value);
			case "exactOptionalPropertyTypes":
				allOptions.ExactOptionalPropertyTypes = ParseTristate(value);
			case "explainFiles":
				allOptions.ExplainFiles = ParseTristate(value);
			case "experimentalDecorators":
				allOptions.ExperimentalDecorators = ParseTristate(value);
			case "forceConsistentCasingInFileNames":
				allOptions.ForceConsistentCasingInFileNames = ParseTristate(value);
			case "generateCpuProfile":
				allOptions.GenerateCpuProfile = ParseString(value);
			case "generateTrace":
				allOptions.GenerateTrace = ParseString(value);
			case "isolatedModules":
				allOptions.IsolatedModules = ParseTristate(value);
			case "ignoreConfig":
				allOptions.IgnoreConfig = ParseTristate(value);
			case "ignoreDeprecations":
				allOptions.IgnoreDeprecations = ParseString(value);
			case "importHelpers":
				allOptions.ImportHelpers = ParseTristate(value);
			case "incremental":
				allOptions.Incremental = ParseTristate(value);
			case "init":
				allOptions.Init = ParseTristate(value);
			case "inlineSourceMap":
				allOptions.InlineSourceMap = ParseTristate(value);
			case "inlineSources":
				allOptions.InlineSources = ParseTristate(value);
			case "isolatedDeclarations":
				allOptions.IsolatedDeclarations = ParseTristate(value);
			case "jsx":
				allOptions.Jsx = floatOrInt32ToFlag(value);
			case "jsxFactory":
				allOptions.JsxFactory = ParseString(value);
			case "jsxFragmentFactory":
				allOptions.JsxFragmentFactory = ParseString(value);
			case "jsxImportSource":
				allOptions.JsxImportSource = ParseString(value);
			case "lib":
				if (isStringSlice(value)) {
					// PORT: Go keeps the []string; a copy so the shared empty sentinel is never aliased.
					allOptions.Lib = isSentinel(value, nilStringSlice) ? null : (value : Array<std.String>).copy();
				} else {
					allOptions.Lib = ParseStringArray(value);
				}
			case "libReplacement":
				allOptions.LibReplacement = ParseTristate(value);
			case "listEmittedFiles":
				allOptions.ListEmittedFiles = ParseTristate(value);
			case "listFiles":
				allOptions.ListFiles = ParseTristate(value);
			case "listFilesOnly":
				allOptions.ListFilesOnly = ParseTristate(value);
			case "locale":
				allOptions.Locale = ParseString(value);
			case "mapRoot":
				allOptions.MapRoot = ParseString(value);
			case "module":
				allOptions.Module = floatOrInt32ToFlag(value);
			case "moduleDetectionKind":
				allOptions.ModuleDetection = floatOrInt32ToFlag(value);
			case "moduleResolution":
				allOptions.ModuleResolution = floatOrInt32ToFlag(value);
			case "moduleSuffixes":
				allOptions.ModuleSuffixes = ParseStringArray(value);
			case "moduleDetection":
				allOptions.ModuleDetection = floatOrInt32ToFlag(value);
			case "noCheck":
				allOptions.NoCheck = ParseTristate(value);
			case "noFallthroughCasesInSwitch":
				allOptions.NoFallthroughCasesInSwitch = ParseTristate(value);
			case "noEmitForJsFiles":
				allOptions.NoEmitForJsFiles = ParseTristate(value);
			case "noErrorTruncation":
				allOptions.NoErrorTruncation = ParseTristate(value);
			case "noImplicitAny":
				allOptions.NoImplicitAny = ParseTristate(value);
			case "noImplicitThis":
				allOptions.NoImplicitThis = ParseTristate(value);
			case "noLib":
				allOptions.NoLib = ParseTristate(value);
			case "noPropertyAccessFromIndexSignature":
				allOptions.NoPropertyAccessFromIndexSignature = ParseTristate(value);
			case "noUncheckedIndexedAccess":
				allOptions.NoUncheckedIndexedAccess = ParseTristate(value);
			case "noEmitHelpers":
				allOptions.NoEmitHelpers = ParseTristate(value);
			case "noEmitOnError":
				allOptions.NoEmitOnError = ParseTristate(value);
			case "noImplicitReturns":
				allOptions.NoImplicitReturns = ParseTristate(value);
			case "noUnusedLocals":
				allOptions.NoUnusedLocals = ParseTristate(value);
			case "noUnusedParameters":
				allOptions.NoUnusedParameters = ParseTristate(value);
			case "noImplicitOverride":
				allOptions.NoImplicitOverride = ParseTristate(value);
			case "noUncheckedSideEffectImports":
				allOptions.NoUncheckedSideEffectImports = ParseTristate(value);
			case "outFile":
				allOptions.OutFile = ParseString(value);
			case "noResolve":
				allOptions.NoResolve = ParseTristate(value);
			case "paths":
				allOptions.Paths = parseStringMap(value);
			case "preserveWatchOutput":
				allOptions.PreserveWatchOutput = ParseTristate(value);
			case "preserveConstEnums":
				allOptions.PreserveConstEnums = ParseTristate(value);
			case "preserveSymlinks":
				allOptions.PreserveSymlinks = ParseTristate(value);
			case "project":
				allOptions.Project = ParseString(value);
			case "pretty":
				allOptions.Pretty = ParseTristate(value);
			case "resolveJsonModule":
				allOptions.ResolveJsonModule = ParseTristate(value);
			case "resolvePackageJsonExports":
				allOptions.ResolvePackageJsonExports = ParseTristate(value);
			case "resolvePackageJsonImports":
				allOptions.ResolvePackageJsonImports = ParseTristate(value);
			case "reactNamespace":
				allOptions.ReactNamespace = ParseString(value);
			case "rewriteRelativeImportExtensions":
				allOptions.RewriteRelativeImportExtensions = ParseTristate(value);
			case "rootDir":
				allOptions.RootDir = ParseString(value);
			case "rootDirs":
				allOptions.RootDirs = ParseStringArray(value);
			case "removeComments":
				allOptions.RemoveComments = ParseTristate(value);
			case "stableTypeOrdering":
				allOptions.StableTypeOrdering = ParseTristate(value);
			case "strict":
				allOptions.Strict = ParseTristate(value);
			case "strictBindCallApply":
				allOptions.StrictBindCallApply = ParseTristate(value);
			case "strictBuiltinIteratorReturn":
				allOptions.StrictBuiltinIteratorReturn = ParseTristate(value);
			case "strictFunctionTypes":
				allOptions.StrictFunctionTypes = ParseTristate(value);
			case "strictNullChecks":
				allOptions.StrictNullChecks = ParseTristate(value);
			case "strictPropertyInitialization":
				allOptions.StrictPropertyInitialization = ParseTristate(value);
			case "skipDefaultLibCheck":
				allOptions.SkipDefaultLibCheck = ParseTristate(value);
			case "sourceMap":
				allOptions.SourceMap = ParseTristate(value);
			case "sourceRoot":
				allOptions.SourceRoot = ParseString(value);
			case "stripInternal":
				allOptions.StripInternal = ParseTristate(value);
			case "suppressOutputPathCheck":
				allOptions.SuppressOutputPathCheck = ParseTristate(value);
			case "target":
				allOptions.Target = floatOrInt32ToFlag(value);
			case "traceResolution":
				allOptions.TraceResolution = ParseTristate(value);
			case "tsBuildInfoFile":
				allOptions.TsBuildInfoFile = ParseString(value);
			case "typeRoots":
				allOptions.TypeRoots = ParseStringArray(value);
			case "types":
				allOptions.Types = ParseStringArray(value);
			case "useDefineForClassFields":
				allOptions.UseDefineForClassFields = ParseTristate(value);
			case "useUnknownInCatchVariables":
				allOptions.UseUnknownInCatchVariables = ParseTristate(value);
			case "verbatimModuleSyntax":
				allOptions.VerbatimModuleSyntax = ParseTristate(value);
			case "version":
				allOptions.Version = ParseTristate(value);
			case "help":
				allOptions.Help = ParseTristate(value);
			case "all":
				allOptions.All = ParseTristate(value);
			case "maxNodeModuleJsDepth":
				allOptions.MaxNodeModuleJsDepth = parseNumber(value);
			case "skipLibCheck":
				allOptions.SkipLibCheck = ParseTristate(value);
			case "noEmit":
				allOptions.NoEmit = ParseTristate(value);
			case "showConfig":
				allOptions.ShowConfig = ParseTristate(value);
			case "configFilePath":
				allOptions.ConfigFilePath = ParseString(value);
			case "noDtsResolution":
				allOptions.NoDtsResolution = ParseTristate(value);
			case "pathsBasePath":
				allOptions.PathsBasePath = ParseString(value);
			case "outDir":
				allOptions.OutDir = ParseString(value);
			case "newLine":
				allOptions.NewLine = floatOrInt32ToFlag(value);
			case "watch":
				allOptions.Watch = ParseTristate(value);
			case "pprofDir":
				allOptions.PprofDir = ParseString(value);
			case "singleThreaded":
				allOptions.SingleThreaded = ParseTristate(value);
			case "quiet":
				allOptions.Quiet = ParseTristate(value);
			case "checkers":
				allOptions.Checkers = parseNumber(value);
			default:
				// different than any key above
				return false;
		}
		return true;
	}

	// PORT: Go generic over the int32 enum type; the enums are Int here.
	static function floatOrInt32ToFlag(value:Dynamic):Int {
		if (Std.isOfType(value, Int)) {
			return value;
		}
		if (!Std.isOfType(value, Float)) {
			throw "interface conversion: interface {} is not float64";
		}
		return Std.int((value : Float));
	}

	public static function ParseWatchOptions(key:std.String, value:Dynamic, allOptions:Null<WatchOptions>):Null<Array<Diagnostic>> {
		if (allOptions == null) {
			return null;
		}
		switch (key) {
			case "watchInterval":
				allOptions.Interval = parseNumber(value);
			case "watchFile":
				if (value != null) {
					allOptions.FileKind = (value : Int);
				}
			case "watchDirectory":
				if (value != null) {
					allOptions.DirectoryKind = (value : Int);
				}
			case "fallbackPolling":
				if (value != null) {
					allOptions.FallbackPolling = (value : Int);
				}
			case "synchronousWatchDirectory":
				allOptions.SyncWatchDir = ParseTristate(value);
			case "excludeDirectories":
				allOptions.ExcludeDir = ParseStringArray(value);
			case "excludeFiles":
				allOptions.ExcludeFiles = ParseStringArray(value);
			default:
		}
		return null;
	}

	public static function ParseTypeAcquisition(key:std.String, value:Dynamic, allOptions:Null<TypeAcquisition>):Null<Array<Diagnostic>> {
		if (value == null) {
			return null;
		}
		if (allOptions == null) {
			return null;
		}
		switch (key) {
			case "enable":
				allOptions.Enable = ParseTristate(value);
			case "include":
				allOptions.Include = ParseStringArray(value);
			case "exclude":
				allOptions.Exclude = ParseStringArray(value);
			case "disableFilenameBasedTypeAcquisition":
				allOptions.DisableFilenameBasedTypeAcquisition = ParseTristate(value);
			default:
		}
		return null;
	}

	public static function ParseBuildOptions(key:std.String, value:Dynamic, allOptions:Null<BuildOptions>):Null<Array<Diagnostic>> {
		if (value == null) {
			return null;
		}
		if (allOptions == null) {
			return null;
		}
		final option = BuildNameMap.Get(key);
		if (option != null) {
			key = option.Name;
		}
		switch (key) {
			case "clean":
				allOptions.Clean = ParseTristate(value);
			case "dry":
				allOptions.Dry = ParseTristate(value);
			case "force":
				allOptions.Force = ParseTristate(value);
			case "builders":
				allOptions.Builders = parseNumber(value);
			case "stopBuildOnErrors":
				allOptions.StopBuildOnErrors = ParseTristate(value);
			case "verbose":
				allOptions.Verbose = ParseTristate(value);
			default:
		}
		return null;
	}

	// mergeCompilerOptions merges the source compiler options into the target compiler options
	// with optional awareness of explicitly set null values in the raw JSON.
	// Fields in the source options will overwrite the corresponding fields in the target options,
	// including when they are explicitly set to null in the raw configuration (if rawSource is provided).
	static function mergeCompilerOptions(targetOptions:Null<CompilerOptions>, sourceOptions:Null<CompilerOptions>, rawSource:Dynamic):Null<CompilerOptions> {
		if (sourceOptions == null) {
			return targetOptions;
		}

		// Collect explicitly null field names from raw JSON
		final explicitNullFields = new Set<std.String>();
		if (rawSource != null) {
			if (isOrderedMap(rawSource)) {
				final rawMap:OrderedMap<std.String, Dynamic> = rawSource;
				// Options are nested under "compilerOptions" in both tsconfig.json and wrapped command line options
				final compilerOptionsRaw = rawMap.Get("compilerOptions");
				if (compilerOptionsRaw.ok) {
					if (isOrderedMap(compilerOptionsRaw.value)) {
						final compilerOptionsMap:OrderedMap<std.String, Dynamic> = compilerOptionsRaw.value;
						for (key => value in compilerOptionsMap.Entries()) {
							if (value == null) {
								explicitNullFields.Add(key);
							}
						}
					}
				}
			}
		}

		// Do the merge, handling explicit nulls during the normal merge
		// PORT: Go walks the struct fields with reflect; compilerOptionsFields lists them.
		for (field in compilerOptionsFields) {
			// Get the JSON field name for this struct field and check if it's explicitly null
			if (field.JsonName != "" && explicitNullFields.Has(field.JsonName)) {
				field.Set(targetOptions, field.Zero());
				continue;
			}

			// Normal merge behavior: copy non-zero fields
			final sourceField = field.Get(sourceOptions);
			if (!field.IsZero(sourceField)) {
				field.Set(targetOptions, sourceField);
			}
		}

		return targetOptions;
	}

	static function convertToOptionsWithAbsolutePaths(optionsBase:Null<OrderedMap<std.String, Dynamic>>, optionMap:CommandLineOptionNameMap,
			cwd:std.String):Null<OrderedMap<std.String, Dynamic>> {
		// !!! convert to options with absolute paths was previously done with `CompilerOptions` object, but for ease of implementation, we do it pre-conversion.
		// !!! Revisit this choice if/when refactoring when conversion is done in tsconfig parsing
		if (optionsBase == null) {
			return null;
		}
		for (o => v in optionsBase.Entries()) {
			final r = ConvertOptionToAbsolutePath(o, v, optionMap, cwd);
			if (r.ok) {
				optionsBase.Set(o, r.value);
			}
		}
		return optionsBase;
	}

	// PORT: (any, bool) → ValueOk.
	public static function ConvertOptionToAbsolutePath(o:std.String, v:Dynamic, optionMap:CommandLineOptionNameMap, cwd:std.String):ValueOk<Dynamic> {
		final option = optionMap.Get(o);
		if (option == null) {
			return new ValueOk<Dynamic>(null, false);
		}
		if (option.Kind == CommandLineOptionTypeList) {
			if (option.Elements().IsFilePath) {
				if (isStringSlice(v)) {
					// PORT: Go maps the []string; the only []string values here are empty
					// (emptyStringSlice) or nil (nilStringSlice), which map to themselves.
					return new ValueOk<Dynamic>(v, true);
				}
				if (isAnySlice(v)) {
					final arr = asAnySlice(v);
					return new ValueOk<Dynamic>(anySliceToAny(Core.Map(arr, function(item:Dynamic):Dynamic {
						if (isString(item)) {
							return Tspath.GetNormalizedAbsolutePath(item, cwd);
						}
						return item;
					})), true);
				}
			}
		} else if (option.IsFilePath) {
			if (isString(v)) {
				return new ValueOk<Dynamic>(Tspath.GetNormalizedAbsolutePath(v, cwd), true);
			}
		}
		return new ValueOk<Dynamic>(null, false);
	}

	// --- showconfig.go ---

	// computeFn wraps a typed getter method so it can be stored in an impliedOption's
	// compute field (which has type func(*core.CompilerOptions) any).
	// PORT: the getters are wrapped with lambdas at the call sites (no generic method values).

	// impliedOptions lists the compiler options that may be implied by other options,
	// mirroring TypeScript's computedOptions used in convertToTSConfig.
	// Each compute function delegates directly to an existing core.CompilerOptions getter.
	static var impliedOptions(get, never):Array<ImpliedOption>;
	static var _impliedOptions:Array<ImpliedOption> = null;

	static function get_impliedOptions():Array<ImpliedOption> {
		if (_impliedOptions == null) {
			_impliedOptions = [
				new ImpliedOption("Module", ["Target"], o -> o.GetEmitModuleKind()),
				new ImpliedOption("ModuleResolution", ["Module", "Target"], o -> o.GetModuleResolutionKind()),
				new ImpliedOption("ModuleDetection", ["Module", "Target"], o -> o.GetEmitModuleDetectionKind()),
				new ImpliedOption("IsolatedModules", ["VerbatimModuleSyntax"], o -> o.GetIsolatedModules()),
				new ImpliedOption("PreserveConstEnums", ["IsolatedModules", "VerbatimModuleSyntax"], o -> o.ShouldPreserveConstEnums()),
				new ImpliedOption("Declaration", ["Composite"], o -> o.GetEmitDeclarations()),
				new ImpliedOption("DeclarationMap", ["Declaration", "Composite"], o -> o.GetAreDeclarationMapsEnabled()),
				new ImpliedOption("Incremental", ["Composite"], o -> o.IsIncremental()),
				new ImpliedOption("UseDefineForClassFields", ["Target", "Module"], o -> o.GetUseDefineForClassFields()),
				new ImpliedOption("ResolvePackageJsonExports", ["ModuleResolution", "Module", "Target"], o -> o.GetResolvePackageJsonExports()),
				new ImpliedOption("ResolvePackageJsonImports", ["ModuleResolution", "ResolvePackageJsonExports", "Module", "Target"],
					o -> o.GetResolvePackageJsonImports()),
				new ImpliedOption("ResolveJsonModule", ["ModuleResolution", "Module", "Target"], o -> o.GetResolveJsonModule()),
				new ImpliedOption("AllowJs", ["CheckJs"], o -> o.GetAllowJS()),
				new ImpliedOption("AllowImportingTsExtensions", ["RewriteRelativeImportExtensions"], o -> o.GetAllowImportingTsExtensions()),
			];
		}
		return _impliedOptions;
	}

	// ConvertToTSConfig generates a complete tsconfig representation for --showConfig output,
	// matching the behavior of TypeScript's convertToTSConfig function.
	public static function ConvertToTSConfig(configParseResult:ParsedCommandLine, configFileName:std.String):TSConfig {
		if (configFileName == "") {
			configFileName = "tsconfig.json";
		}
		final normalizedConfigPath = Tspath.GetNormalizedAbsolutePath(configFileName, configParseResult.GetCurrentDirectory());
		final comparePathsOptions = new ComparePathsOptions(configParseResult.UseCaseSensitiveFileNames(), configParseResult.GetCurrentDirectory());

		// Build the list of all resolved files as relative paths from the config file.
		var files:Null<Array<std.String>> = null;
		if (configParseResult.FileNames() != null) {
			for (f in configParseResult.FileNames()) {
				final normalizedFilePath = Tspath.GetNormalizedAbsolutePath(f, configParseResult.GetCurrentDirectory());
				final relativePath = Tspath.GetRelativePathFromFile(normalizedConfigPath, normalizedFilePath, comparePathsOptions);
				if (files == null)
					files = [];
				files.push(relativePath);
			}
		}

		// Serialize compiler options
		final optionMap = serializeCompilerOptions(configParseResult.CompilerOptions(), normalizedConfigPath, comparePathsOptions);

		// Remove command-line-only options from the output
		for (name in [
			"showConfig", "configFile", "configFilePath", "help", "init", "listFilesOnly", "listEmittedFiles", "project", "build", "version"
		]) {
			optionMap.Delete(name);
		}

		// Add implied compiler options (options that are derived from explicitly set options,
		// such as moduleResolution implied by module, or useDefineForClassFields implied by target).
		// This mirrors TypeScript's convertToTSConfig computedOptions logic.
		addImpliedOptions(optionMap, configParseResult.CompilerOptions(), normalizedConfigPath, comparePathsOptions);

		final config = new TSConfig();
		config.CompilerOptions = optionMap;

		// Add references
		final refs = configParseResult.ProjectReferences();
		if (Core.len(refs) > 0) {
			var references:Null<Array<Dynamic>> = null;
			for (r in refs) {
				final ref = new OrderedMap<std.String, Dynamic>();
				ref.Set("path", r.OriginalPath);
				if (r.Circular) {
					ref.Set("circular", true);
				}
				if (references == null)
					references = [];
				references.push(ref);
			}
			config.References = references;
		}

		// Add files
		if (Core.len(files) > 0) {
			config.Files = files;
		}

		// Add include/exclude from configFileSpecs
		if (configParseResult.ConfigFile != null && configParseResult.ConfigFile.configFileSpecs != null) {
			final specs = configParseResult.ConfigFile.configFileSpecs;
			final include = filterSameAsDefaultInclude(specs.validatedIncludeSpecs);
			if (Core.len(include) > 0) {
				config.Include = include;
			}
			config.Exclude = specs.validatedExcludeSpecs;
		}

		// Add compileOnSave
		if (configParseResult.CompileOnSave != null && configParseResult.CompileOnSave == true) {
			final t = true;
			config.CompileOnSave = t;
		}

		return config;
	}

	// filterSameAsDefaultInclude returns nil if specs is the default include spec ["**/*"]
	static function filterSameAsDefaultInclude(specs:Null<Array<std.String>>):Null<Array<std.String>> {
		if (Core.len(specs) == 0) {
			return null;
		}
		if (specs.length == 1 && specs[0] == defaultIncludeSpec) {
			return null;
		}
		return specs;
	}

	// getNameOfCompilerOptionValue returns the string key for a given enum value by
	// searching the option's enum map.
	static function getNameOfCompilerOptionValue(value:Dynamic, enumMap:OrderedMap<std.String, Dynamic>):std.String {
		for (k => v in enumMap.Entries()) {
			if (v == value) {
				return k;
			}
		}
		return "";
	}

	// serializeCompilerOptions converts CompilerOptions to an ordered map with
	// string names as keys and serialized values (enums as strings, paths as
	// relative paths, etc.) matching the output of tsc --showConfig.
	static function serializeCompilerOptions(options:CompilerOptions, configFilePath:std.String,
			comparePathsOptions:ComparePathsOptions):OrderedMap<std.String, Dynamic> {
		final result:OrderedMap<std.String, Dynamic> = Collections.NewOrderedMapWithSizeHint(32, (null : Dynamic));
		final configDir = Tspath.GetDirectoryPath(configFilePath);

		// PORT: Go walks the struct fields with reflect; compilerOptionsFields lists them.
		for (field in compilerOptionsFields) {
			final optionDecl = CommandLineCompilerOptionsMap.Get(field.Name);
			if (optionDecl == null) {
				continue;
			}

			// Skip command-line-only and output formatting options
			if (optionDecl.Category == Diagnostics.Command_line_Options || optionDecl.Category == Diagnostics.Output_Formatting) {
				continue;
			}

			final fieldValue = field.Get(options);

			// Skip zero values (unset options)
			if (field.IsZero(fieldValue)) {
				continue;
			}

			final name = optionDecl.Name;
			final value:Dynamic = fieldValue;

			final enumMap = optionDecl.EnumMap();
			if (enumMap != null) {
				// Enum option - convert numeric value to string name
				final serialized = serializeEnumValue(value, enumMap);
				if (serialized != "") {
					result.Set(name, serialized);
				}
				continue;
			}

			// PORT: Go `value.([]string)` is true exactly for the []string fields (FieldStrings).
			final isStrings = field.Kind == FieldStrings;
			switch (optionDecl.Kind) {
				case CommandLineOptionTypeListOrElement:
					Debug.Assert(false, "listOrElement option should not reach serialization");
				case CommandLineOptionTypeList:
					final elem = optionDecl.Elements();
					var done = false;
					if (elem != null && elem.IsFilePath) {
						// List of file paths - make relative
						if (isStrings) {
							final strs:Array<std.String> = value;
							final relPaths:Array<std.String> = [];
							for (s in strs) {
								final absPath = Tspath.GetNormalizedAbsolutePath(s, configDir);
								relPaths.push(Tspath.GetRelativePathFromFile(configFilePath, absPath, comparePathsOptions));
							}
							result.Set(name, relPaths);
							done = true;
						}
					}
					if (!done && elem != null && elem.EnumMap() != null) {
						// List of enum values (e.g., lib)
						final elemMap = elem.EnumMap();
						if (isStrings) {
							final strs:Array<std.String> = value;
							final serialized:Array<std.String> = [];
							for (s in strs) {
								// lib values are already stored as the d.ts filename, need to find original key
								final found = getNameOfCompilerOptionValue(s, elemMap);
								if (found != "") {
									serialized.push(found);
								} else {
									serialized.push(s);
								}
							}
							result.Set(name, serialized);
							done = true;
						}
					}
					if (!done) {
						result.Set(name, value);
					}

				case CommandLineOptionTypeString:
					var done = false;
					if (optionDecl.IsFilePath) {
						// File path option - make relative to config
						if (isString(value) && (value : std.String) != "") {
							final absPath = Tspath.GetNormalizedAbsolutePath(value, configDir);
							result.Set(name, Tspath.GetRelativePathFromFile(configFilePath, absPath, comparePathsOptions));
							done = true;
						}
					}
					if (!done) {
						result.Set(name, value);
					}

				case CommandLineOptionTypeBoolean:
					if (field.Kind == FieldTristate) {
						final t:Tristate = value;
						if (t.IsTrue()) {
							result.Set(name, true);
						} else if (t.IsFalse()) {
							result.Set(name, false);
						}
					} else {
						result.Set(name, value);
					}

				case CommandLineOptionTypeNumber:
					result.Set(name, value);

				default:
					result.Set(name, value);
			}
		}

		return result;
	}

	// serializeEnumValue converts an enum field value to its corresponding string key
	// using the option's enum map. It handles int32-based enum types.
	static function serializeEnumValue(value:Dynamic, enumMap:OrderedMap<std.String, Dynamic>):std.String {
		// The enum maps store values as core.ModuleKind, core.ScriptTarget, etc.
		// But those are all int32 underneath. We need to compare by the underlying int32 value.
		if (!isBool(value) && Std.isOfType(value, Int)) {
			final intVal:Int = value;
			for (k => v in enumMap.Entries()) {
				if (!isBool(v) && Std.isOfType(v, Int) && (v : Int) == intVal) {
					return k;
				}
			}
		}
		// Fallback: direct comparison
		return getNameOfCompilerOptionValue(value, enumMap);
	}

	// addImpliedOptions adds compiler options that are implied by other explicitly-set options,
	// mirroring TypeScript's convertToTSConfig behavior for computedOptions.
	// For example, when module: nodenext is set, moduleResolution: nodenext is implied.
	static function addImpliedOptions(optionMap:OrderedMap<std.String, Dynamic>, options:CompilerOptions, _:std.String, __:ComparePathsOptions):Void {
		// Build the set of explicitly provided option JSON names (e.g., "module", "target").
		final provided = new StringMap<Bool>();
		for (k in optionMap.Keys()) {
			provided.set(k, true);
		}

		final defaultOpts = new CompilerOptions();

		for (entry in impliedOptions) {
			// Get the option declaration for this implied option (using case-insensitive lookup).
			final optionDecl = CommandLineCompilerOptionsMap.Get(entry.name);
			if (optionDecl == null) {
				continue;
			}

			// Skip if this option is already explicitly provided.
			if (provided.get(optionDecl.Name) == true) {
				continue;
			}

			// Check if any direct dependency is in the provided set.
			// This mirrors TypeScript's optionDependsOn check.
			if (!anyDependencyProvided(entry.dependencies, provided)) {
				continue;
			}

			// Compute the effective value with current options and the default value with empty options.
			final implied = entry.compute(options);
			final defaultVal = entry.compute(defaultOpts);

			// If the implied value equals the default, this option doesn't add useful information.
			if (implied == defaultVal) {
				continue;
			}

			// Serialize the implied value and add it to the option map.
			final serialized = serializeImpliedOptionValue(optionDecl, implied);
			if (serialized == null) {
				continue;
			}
			optionMap.Set(optionDecl.Name, serialized);
		}
	}

	// anyDependencyProvided returns true if any of the given dependency names
	// (using Go field names like "Target") corresponds to an option in the provided set.
	static function anyDependencyProvided(dependencies:Null<Array<std.String>>, provided:StringMap<Bool>):Bool {
		if (dependencies != null) {
			for (dep in dependencies) {
				final depDecl = CommandLineCompilerOptionsMap.Get(dep);
				if (depDecl != null && provided.get(depDecl.Name) == true) {
					return true;
				}
			}
		}
		return false;
	}

	// serializeImpliedOptionValue converts a computed implied option value to its serializable form.
	// For enum options, it converts numeric values to their string names.
	// For boolean options, it returns the bool directly.
	static function serializeImpliedOptionValue(optionDecl:CommandLineOption, value:Dynamic):Dynamic {
		if (value == null) {
			return null;
		}
		final enumMap = optionDecl.EnumMap();
		if (enumMap != null) {
			final s = serializeEnumValue(value, enumMap);
			if (s != "") {
				return s;
			}
			return null;
		}
		if (isBool(value)) {
			return value;
		}
		// PORT: the Go `case core.Tristate` cannot be told from other ints here; no compute
		// function returns a Tristate, so it is not reached.
		return value;
	}

	// --- tsconfigparsing.go ---

	static var compilerOptionsDeclaration(get, never):CommandLineOption;
	static var _compilerOptionsDeclaration:CommandLineOption = null;

	static function get_compilerOptionsDeclaration():CommandLineOption {
		if (_compilerOptionsDeclaration == null) {
			final o = new CommandLineOption();
			o.Name = "compilerOptions";
			o.Kind = CommandLineOptionTypeObject;
			o.ElementOptions = CommandLineCompilerOptionsMap;
			_compilerOptionsDeclaration = o;
		}
		return _compilerOptionsDeclaration;
	}

	static var compileOnSaveCommandLineOption(get, never):CommandLineOption;
	static var _compileOnSaveCommandLineOption:CommandLineOption = null;

	static function get_compileOnSaveCommandLineOption():CommandLineOption {
		if (_compileOnSaveCommandLineOption == null) {
			final o = new CommandLineOption();
			o.Name = "compileOnSave";
			o.Kind = CommandLineOptionTypeBoolean;
			o.DefaultValueDescription = false;
			_compileOnSaveCommandLineOption = o;
		}
		return _compileOnSaveCommandLineOption;
	}

	static var extendsOptionDeclaration(get, never):CommandLineOption;
	static var _extendsOptionDeclaration:CommandLineOption = null;

	static function get_extendsOptionDeclaration():CommandLineOption {
		if (_extendsOptionDeclaration == null) {
			final o = new CommandLineOption();
			o.Name = "extends";
			o.Kind = CommandLineOptionTypeListOrElement;
			o.Category = Diagnostics.File_Management;
			final e = new CommandLineOption();
			e.Name = "extends";
			e.Kind = CommandLineOptionTypeString;
			o.ElementOptions = commandLineOptionsToMap([e]);
			_extendsOptionDeclaration = o;
		}
		return _extendsOptionDeclaration;
	}

	static var tsconfigRootOptionsMap(get, never):CommandLineOption;
	static var _tsconfigRootOptionsMap:CommandLineOption = null;

	static function get_tsconfigRootOptionsMap():CommandLineOption {
		if (_tsconfigRootOptionsMap == null) {
			final o = new CommandLineOption();
			o.Name = "undefined"; // should never be needed since this is root
			o.Kind = CommandLineOptionTypeObject;
			final references = new CommandLineOption();
			references.Name = "references";
			references.Kind = CommandLineOptionTypeList; // should be a list of projectReference
			// Category: diagnostics.Projects,
			final files = new CommandLineOption();
			files.Name = "files";
			files.Kind = CommandLineOptionTypeList;
			// Category: diagnostics.File_Management,
			final include = new CommandLineOption();
			include.Name = "include";
			include.Kind = CommandLineOptionTypeList;
			// Category: diagnostics.File_Management,
			// DefaultValueDescription: diagnostics.if_files_is_specified_otherwise_Asterisk_Asterisk_Slash_Asterisk,
			final exclude = new CommandLineOption();
			exclude.Name = "exclude";
			exclude.Kind = CommandLineOptionTypeList;
			// Category: diagnostics.File_Management,
			// DefaultValueDescription: diagnostics.Node_modules_bower_components_jspm_packages_plus_the_value_of_outDir_if_one_is_specified,
			o.ElementOptions = commandLineOptionsToMap([
				compilerOptionsDeclaration,
				// watchOptionsDeclaration,
				typeAcquisitionDeclaration,
				extendsOptionDeclaration,
				references,
				files,
				include,
				exclude,
				compileOnSaveCommandLineOption,
			]);
			_tsconfigRootOptionsMap = o;
		}
		return _tsconfigRootOptionsMap;
	}

	static function parseOwnConfigOfJsonSourceFile(sourceFile:SourceFile, host:ParseConfigHost, basePath:std.String,
			configFileName:std.String):Pair<ParsedTsconfig, Null<Array<Diagnostic>>> {
		final compilerOptions = getDefaultCompilerOptions(configFileName);
		final typeAcquisition = getDefaultTypeAcquisition(configFileName);
		// var watchOptions *compiler.WatchOptions
		var extendedConfigPath:Dynamic = null;
		var rootCompilerOptions:Null<Array<Node>> = null;
		var errors:Null<Array<Diagnostic>> = null;
		final onPropertySet = function(keyText:std.String, value:Dynamic, propertyAssignment:PropertyAssignment, parentOption:Null<CommandLineOption>, // TsConfigOnlyOption,
				option:Null<CommandLineOption>):Pair<Dynamic, Null<Array<Diagnostic>>> {
			// Ensure value is verified except for extends which is handled in its own way for error reporting
			var propertySetErrors:Null<Array<Diagnostic>> = null;
			if (option != null && option != extendsOptionDeclaration) {
				final r = convertJsonOption(option, value, basePath, propertyAssignment, propertyAssignment.Initializer, sourceFile);
				value = r.a;
				propertySetErrors = r.b;
			}
			if (parentOption != null && parentOption.Name != "undefined" && value != null) {
				if (option != null && option.Name != "") {
					var parseDiagnostics:Null<Array<Diagnostic>> = null;
					switch (parentOption.Name) {
						case "compilerOptions":
							parseDiagnostics = ParseCompilerOptions(option.Name, value, compilerOptions);
						case "typeAcquisition":
							parseDiagnostics = ParseTypeAcquisition(option.Name, value, typeAcquisition);
						default:
					}
					propertySetErrors = appendDiags(propertySetErrors, parseDiagnostics);
				} else if (keyText != "" && extraKeyDiagnostics(parentOption.Name) != null) {
					final unknownNameDiag = extraKeyDiagnostics(parentOption.Name);
					if (parentOption.ElementOptions != null) {
						final possibleOption = parentOption.ElementOptions.Get(keyText);
						if (possibleOption != null && possibleOption.Name != keyText) {
							propertySetErrors = appendDiag(propertySetErrors,
								CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, propertyAssignment.Name(),
									extraKeyDidYouMeanDiagnostics(parentOption.Name), keyText, possibleOption.Name));
						} else {
							propertySetErrors = appendDiag(propertySetErrors, createUnknownOptionError(keyText, unknownNameDiag, "", /*unknownOptionErrorText*/
								propertyAssignment.Name(), sourceFile, null /*alternateMode*/));
						}
					} else {
						// errors = append(errors, ast.NewCompilerDiagnostic(diagnostics.Unknown_compiler_option_0_Did_you_mean_1, keyText, core.FindKey(parentOption.ElementOptions, keyText)))
					}
				}
			} else if (parentOption == tsconfigRootOptionsMap) {
				if (option == extendsOptionDeclaration) {
					final r = getExtendsConfigPathOrArray(value, host, basePath, configFileName, propertyAssignment, propertyAssignment.Initializer,
						sourceFile);
					extendedConfigPath = stringSliceToAny(r.a);
					propertySetErrors = appendDiags(propertySetErrors, r.b);
				} else if (option == null) {
					if (keyText == "excludes") {
						propertySetErrors = appendDiag(propertySetErrors,
							CreateDiagnosticForNodeInSourceFile(sourceFile, propertyAssignment.Name(), Diagnostics.Unknown_option_excludes_Did_you_mean_exclude));
					}
					if (Core.Find(OptionsDeclarations, function(option:CommandLineOption):Bool {
						return option.Name == keyText;
					}) != null) {
						if (rootCompilerOptions == null)
							rootCompilerOptions = [];
						rootCompilerOptions.push(propertyAssignment.Name());
					}
				}
			}
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(value, propertySetErrors);
		};

		final r = convertConfigFileToObject(sourceFile, new JsonConversionNotifier(tsconfigRootOptionsMap, onPropertySet));
		final json = r.a;
		errors = appendDiags(errors, r.b);
		// if len(rootCompilerOptions) != 0  && json != nil && json.CompilerOptions != nil {
		//    errors = append(errors, ast.NewDiagnostic(sourceFile, rootCompilerOptions[0], diagnostics.X_0_should_be_set_inside_the_compilerOptions_object_of_the_config_json_file))
		// }
		final parsed = new ParsedTsconfig();
		parsed.raw = json;
		parsed.options = compilerOptions;
		// watchOptions:    watchOptions,
		parsed.typeAcquisition = typeAcquisition;
		parsed.extendedConfigPath = extendedConfigPath;
		return new Pair<ParsedTsconfig, Null<Array<Diagnostic>>>(parsed, errors);
	}

	static function tsconfigToSourceFile(tsconfigSourceFile:Null<TsConfigSourceFile>):Null<SourceFile> {
		if (tsconfigSourceFile == null) {
			return null;
		}
		return tsconfigSourceFile.SourceFile;
	}

	public static function NewTsconfigSourceFileFromFilePath(configFileName:std.String, configPath:Path, configSourceText:std.String):TsConfigSourceFile {
		final opts = new SourceFileParseOptions();
		opts.FileName = configFileName;
		opts.Path = configPath;
		final sourceFile = Parser.ParseSourceFile(opts, configSourceText, ScriptKindJSON);
		return new TsConfigSourceFile(sourceFile);
	}

	static function convertConfigFileToObject(sourceFile:SourceFile, jsonConversionNotifier:Null<JsonConversionNotifier>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		var rootExpression:Null<Node> = null;
		if (Core.len(sourceFile.Statements.Nodes) > 0) {
			rootExpression = sourceFile.Statements.Nodes[0].Expression();
		}
		if (rootExpression != null && rootExpression.Kind != KindObjectLiteralExpression) {
			var baseFileName = "tsconfig.json";
			if (Tspath.GetBaseFileName(sourceFile.FileName()) == "jsconfig.json") {
				baseFileName = "jsconfig.json";
			}
			final errors = [Ast.NewCompilerDiagnostic(Diagnostics.The_root_value_of_a_0_file_must_be_an_object, baseFileName)];
			// Last-ditch error recovery. Somewhat useful because the JSON parser will recover from some parse errors by
			// synthesizing a top-level array literal expression. There's a reasonable chance the first element of that
			// array is a well-formed configuration object, made into an array element by stray characters.
			if (Ast.IsArrayLiteralExpression(rootExpression)) {
				final firstObject = Core.Find(rootExpression.Elements(), Ast.IsObjectLiteralExpression);
				if (firstObject != null) {
					return convertToJson(sourceFile, firstObject, true /*returnValue*/, jsonConversionNotifier);
				}
			}
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(new OrderedMap<std.String, Dynamic>(), errors);
		}
		return convertToJson(sourceFile, rootExpression, true, jsonConversionNotifier);
	}

	// PORT: `orderedMapType = reflect.TypeFor[*collections.OrderedMap[string, any]]()` →
	// isOrderedMap.

	static function isCompilerOptionsValue(option:Null<CommandLineOption>, value:Dynamic):Bool {
		if (option != null) {
			if (value == null) {
				return !option.DisallowNullOrUndefined();
			}
			if (option.Kind == CommandLineOptionTypeList) {
				return isSlice(value);
			}
			if (option.Kind == CommandLineOptionTypeListOrElement) {
				if (isSlice(value)) {
					return true;
				} else {
					return isCompilerOptionsValue(option.Elements(), value);
				}
			}
			if (option.Kind == CommandLineOptionTypeString) {
				return isString(value);
			}
			if (option.Kind == CommandLineOptionTypeBoolean) {
				return isBool(value);
			}
			if (option.Kind == CommandLineOptionTypeNumber) {
				// PORT: Go reflect.Float64 (JSON numbers are float64).
				return !isBool(value) && Std.isOfType(value, Float);
			}
			if (option.Kind == CommandLineOptionTypeObject) {
				return isOrderedMap(value);
			}
			if (option.Kind == CommandLineOptionTypeEnum && isString(value)) {
				return true;
			}
		}
		return false;
	}

	static function validateJsonOptionValue(opt:CommandLineOption, val:Dynamic, valueExpression:Null<Node>,
			sourceFile:Null<SourceFile>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		if (val == null) {
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
		}

		var errors:Null<Array<Diagnostic>> = null;

		switch (opt.extraValidation) {
			case extraValidationSpec:
				final diag = specToDiagnostic(mustString(val), false);
				if (diag != null) {
					errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, valueExpression, diag));
				}
			case extraValidationLocale:
				if (ts.locale.Locale.Parse(mustString(val)) == null) {
					errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, valueExpression,
						Diagnostics.Locale_must_be_an_IETF_BCP_47_language_tag_Examples_Colon_0_1, "en", "ja-jp"));
				}
			default:
		}

		if (Core.len(errors) > 0) {
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, errors);
		}
		return new Pair<Dynamic, Null<Array<Diagnostic>>>(val, null);
	}

	// PORT: returns the Go []any (nil → null); callers that store it in an `any` use anySliceToAny.
	static function convertJsonOptionOfListType(option:CommandLineOption, values:Dynamic, basePath:std.String, propertyAssignment:Null<PropertyAssignment>,
			valueExpression:Null<Node>, sourceFile:Null<SourceFile>):Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>> {
		var expression:Null<Node> = null;
		var errors:Null<Array<Diagnostic>> = null;
		if (isAnySlice(values)) {
			final values = asAnySlice(values);
			final mappedValues = Core.MapIndex(values, function(v:Dynamic, index:Int):Dynamic {
				if (valueExpression != null) {
					expression = valueExpression.Elements()[index];
				}
				final r = convertJsonOption(option.Elements(), v, basePath, propertyAssignment, expression, sourceFile);
				errors = appendDiags(errors, r.b);
				return r.a;
			});
			var filteredValues = mappedValues;
			if (!option.listPreserveFalsyValues) {
				filteredValues = Core.Filter(mappedValues, function(v:Dynamic):Bool {
					// PORT: Go `v != 0` compares with an int 0; the values here are never ints.
					return (v != null && !(isBool(v) && (v : Bool) == false) && !(isString(v) && (v : std.String) == ""));
				});
			}
			return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>(filteredValues, errors);
		}
		return new Pair<Null<Array<Dynamic>>, Null<Array<Diagnostic>>>(null, errors);
	}

	static inline final configDirTemplate = "${configDir}";

	static function startsWithConfigDirTemplate(value:Dynamic):Bool {
		if (!isString(value)) {
			return false;
		}
		final str:std.String = value;
		return StringTools.startsWith(Strings.ToLower(str), Strings.ToLower(configDirTemplate));
	}

	static function normalizeNonListOptionValue(option:CommandLineOption, basePath:std.String, value:Dynamic):Dynamic {
		if (option.IsFilePath) {
			value = Tspath.NormalizeSlashes(mustString(value));
			if (!startsWithConfigDirTemplate(value)) {
				value = Tspath.GetNormalizedAbsolutePath(mustString(value), basePath);
			}
			if (isString(value) && (value : std.String) == "") {
				value = ".";
			}
		}
		return value;
	}

	static function convertJsonOption(opt:CommandLineOption, value:Dynamic, basePath:std.String, propertyAssignment:Null<PropertyAssignment>,
			valueExpression:Null<Node>, sourceFile:Null<SourceFile>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		if (opt.IsCommandLineOnly) {
			var nodeValue:Null<Node> = null;
			if (propertyAssignment != null) {
				nodeValue = propertyAssignment.Name();
			}
			if (sourceFile == null && nodeValue == null) {
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, [
					Ast.NewCompilerDiagnostic(Diagnostics.Option_0_can_only_be_specified_on_command_line, opt.Name)
				]);
			} else {
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, [
					CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, nodeValue, Diagnostics.Option_0_can_only_be_specified_on_command_line,
						opt.Name)
				]);
			}
		}
		if (isCompilerOptionsValue(opt, value)) {
			switch (opt.Kind) {
				case CommandLineOptionTypeList:
					final r = convertJsonOptionOfListType(opt, value, basePath, propertyAssignment, valueExpression, sourceFile); // as ArrayLiteralExpression | undefined
					return new Pair<Dynamic, Null<Array<Diagnostic>>>(anySliceToAny(r.a), r.b);
				case CommandLineOptionTypeListOrElement:
					if (isSlice(value)) {
						final r = convertJsonOptionOfListType(opt, value, basePath, propertyAssignment, valueExpression, sourceFile);
						return new Pair<Dynamic, Null<Array<Diagnostic>>>(anySliceToAny(r.a), r.b);
					} else {
						return convertJsonOption(opt.Elements(), value, basePath, propertyAssignment, valueExpression, sourceFile);
					}
				case CommandLineOptionTypeEnum:
					if (value == null) {
						return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
					}
					return convertJsonOptionOfEnumType(opt, mustString(value), valueExpression, sourceFile);
				default:
			}

			final r = validateJsonOptionValue(opt, value, valueExpression, sourceFile);
			final validatedValue = r.a;
			final errors = r.b;
			if (Core.len(errors) > 0 || validatedValue == null) {
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(validatedValue, errors);
			} else {
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(normalizeNonListOptionValue(opt, basePath, validatedValue), errors);
			}
		} else {
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, [
				CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(sourceFile, valueExpression, Diagnostics.Compiler_option_0_requires_a_value_of_type_1,
					opt.Name, getCompilerOptionValueTypeString(opt))
			]);
		}
	}

	// PORT: returns the Go []string (nil → null).
	static function getExtendsConfigPathOrArray(value:CompilerOptionsValue, host:ParseConfigHost, basePath:std.String, configFileName:std.String,
			propertyAssignment:Null<PropertyAssignment>, valueExpression:Null<Node>,
			sourceFile:Null<SourceFile>):Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>> {
		var extendedConfigPathArray:Null<Array<std.String>> = null;
		var newBase = basePath;
		if (configFileName != "") {
			newBase = directoryOfCombinedPath(configFileName, basePath);
		}
		if (value == null) {
			final r = convertJsonOption(extendsOptionDeclaration, value, basePath, propertyAssignment, valueExpression, sourceFile);
			return new Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>>(extendedConfigPathArray, r.b);
		}
		if (isString(value)) {
			final r = getExtendsConfigPath(value, host, newBase, valueExpression, sourceFile);
			if (r.a != "") {
				extendedConfigPathArray = [r.a];
			}
			return new Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>>(extendedConfigPathArray, r.b);
		}
		var errors:Null<Array<Diagnostic>> = null;
		if (isSlice(value)) {
			// PORT: Go `value.([]any)`; values here come from JSON and are []any.
			final arr = asAnySlice(value);
			if (arr != null) {
				for (index in 0...arr.length) {
					final fileName = arr[index];
					var expression:Null<Node> = null;
					if (valueExpression != null) {
						expression = valueExpression.Elements()[index];
					}
					if (isString(fileName)) {
						final r = getExtendsConfigPath(fileName, host, newBase, expression, sourceFile);
						if (r.a != "") {
							if (extendedConfigPathArray == null)
								extendedConfigPathArray = [];
							extendedConfigPathArray.push(r.a);
						}
						errors = appendDiags(errors, r.b);
					} else {
						final r = convertJsonOption(extendsOptionDeclaration.Elements(), value, basePath, propertyAssignment, expression, sourceFile);
						errors = appendDiags(errors, r.b);
					}
				}
			}
		} else {
			errors = convertJsonOption(extendsOptionDeclaration, value, basePath, propertyAssignment, valueExpression, sourceFile).b;
		}
		return new Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>>(extendedConfigPathArray, errors);
	}

	static function getExtendsConfigPath(extendedConfig:std.String, host:ParseConfigHost, basePath:std.String, valueExpression:Null<Node>,
			sourceFile:Null<SourceFile>):Pair<std.String, Null<Array<Diagnostic>>> {
		extendedConfig = Tspath.NormalizeSlashes(extendedConfig);
		var errors:Null<Array<Diagnostic>> = null;
		var errorFile:Null<SourceFile> = null;
		if (sourceFile != null) {
			errorFile = sourceFile;
		}
		if (Tspath.IsRootedDiskPath(extendedConfig) || StringTools.startsWith(extendedConfig, "./") || StringTools.startsWith(extendedConfig, "../")) {
			var extendedConfigPath = Tspath.GetNormalizedAbsolutePath(extendedConfig, basePath);
			if (!host.FS().FileExists(extendedConfigPath) && !StringTools.endsWith(extendedConfigPath, Tspath.ExtensionJson)) {
				extendedConfigPath = extendedConfigPath + Tspath.ExtensionJson;
				if (!host.FS().FileExists(extendedConfigPath)) {
					errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression, Diagnostics.File_0_not_found,
						extendedConfig));
					return new Pair<std.String, Null<Array<Diagnostic>>>("", errors);
				}
			}
			return new Pair<std.String, Null<Array<Diagnostic>>>(extendedConfigPath, errors);
		}
		// If the path isn't a rooted or relative path, resolve like a module
		final resolverHost = new ResolverHost(host);
		final resolved = ts.module.Module.ResolveConfig(extendedConfig, Tspath.CombinePaths(basePath, "tsconfig.json"), resolverHost);
		if (resolved.IsResolved()) {
			return new Pair<std.String, Null<Array<Diagnostic>>>(resolved.ResolvedFileName, errors);
		}
		if (extendedConfig == "") {
			errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression,
				Diagnostics.Compiler_option_0_cannot_be_given_an_empty_string, "extends"));
		} else {
			errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(errorFile, valueExpression, Diagnostics.File_0_not_found,
				extendedConfig));
		}
		return new Pair<std.String, Null<Array<Diagnostic>>>("", errors);
	}

	static function commandLineOptionsToMap(compilerOptions:Array<CommandLineOption>):CommandLineOptionNameMap {
		final result = new CommandLineOptionNameMap();
		for (i in 0...compilerOptions.length) {
			(result : StringMap<CommandLineOption>).set(compilerOptions[i].Name, compilerOptions[i]);
			(result : StringMap<CommandLineOption>).set(Strings.ToLower(compilerOptions[i].Name), compilerOptions[i]);
		}
		return result;
	}

	public static var CommandLineCompilerOptionsMap(get, never):CommandLineOptionNameMap;
	static var _CommandLineCompilerOptionsMap:CommandLineOptionNameMap = null;

	static function get_CommandLineCompilerOptionsMap():CommandLineOptionNameMap {
		if (_CommandLineCompilerOptionsMap == null) {
			_CommandLineCompilerOptionsMap = commandLineOptionsToMap(OptionsDeclarations);
		}
		return _CommandLineCompilerOptionsMap;
	}

	static function convertMapToOptions<O:OptionParser>(compilerOptions:OrderedMap<std.String, Dynamic>, result:O):O {
		// this assumes any `key`, `value` pair in `options` will have `value` already be the correct type. this function should no error handling
		for (key => value in compilerOptions.Entries()) {
			result.ParseOption(key, value);
		}
		return result;
	}

	static function convertOptionsFromJson<O:OptionParser>(optionsNameMap:CommandLineOptionNameMap, jsonOptions:Dynamic, basePath:std.String,
			result:O):Pair<O, Null<Array<Diagnostic>>> {
		if (jsonOptions == null) {
			return new Pair<O, Null<Array<Diagnostic>>>(result, null);
		}
		if (!isOrderedMap(jsonOptions)) {
			// !!! probably should be an error
			return new Pair<O, Null<Array<Diagnostic>>>(result, null);
		}
		final jsonMap:OrderedMap<std.String, Dynamic> = jsonOptions;
		var errors:Null<Array<Diagnostic>> = null;
		for (key => value in jsonMap.Entries()) {
			final opt = optionsNameMap.Get(key);
			if (opt != null && opt.Name != key) {
				// Case-insensitive match found but exact case doesn't match - provide "did you mean" suggestion
				errors = appendDiag(errors,
					CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(null, null, result.UnknownDidYouMeanDiagnostic(), key, opt.Name));
				continue;
			}
			if (opt == null) {
				errors = appendDiag(errors, createUnknownOptionError(key, result.UnknownOptionDiagnostic(), "", null, null, null));
				continue;
			}

			final commandLineOptionEnumMapVal = opt.EnumMap();
			if (commandLineOptionEnumMapVal != null) {
				if (isString(value)) {
					final r = commandLineOptionEnumMapVal.Get(Strings.ToLower(value));
					if (r.ok) {
						errors = result.ParseOption(key, r.value);
					}
				} else {
					final r = convertJsonOption(opt, value, basePath, null, null, null);
					errors = appendDiags(errors, r.b);
					final compilerOptionsErr = result.ParseOption(key, r.a);
					errors = appendDiags(errors, compilerOptionsErr);
				}
			} else {
				final r = convertJsonOption(opt, value, basePath, null, null, null);
				errors = appendDiags(errors, r.b);
				final compilerOptionsErr = result.ParseOption(key, r.a);
				errors = appendDiags(errors, compilerOptionsErr);
			}
		}
		return new Pair<O, Null<Array<Diagnostic>>>(result, errors);
	}

	static function convertArrayLiteralExpressionToJson(sourceFile:SourceFile, elements:Null<Array<Node>>, elementOption:Null<CommandLineOption>,
			returnValue:Bool):Pair<Dynamic, Null<Array<Diagnostic>>> {
		if (!returnValue) {
			if (elements != null) {
				for (element in elements) {
					convertPropertyValueToJson(sourceFile, element, elementOption, returnValue, null);
				}
			}
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
		}
		// Filter out invalid values
		if (Core.len(elements) == 0) {
			// Always return an empty array, even if elements is nil.
			// The parser will produce nil slices instead of allocating empty ones.
			return new Pair<Dynamic, Null<Array<Diagnostic>>>(([] : Array<Dynamic>), null);
		}
		var errors:Null<Array<Diagnostic>> = null;
		var value:Null<Array<Dynamic>> = null;
		for (element in elements) {
			final r = convertPropertyValueToJson(sourceFile, element, elementOption, returnValue, null);
			errors = appendDiags(errors, r.b);
			if (r.a != null) {
				if (value == null)
					value = [];
				value.push(r.a);
			}
		}
		return new Pair<Dynamic, Null<Array<Diagnostic>>>(anySliceToAny(value), errors);
	}

	static function directoryOfCombinedPath(fileName:std.String, basePath:std.String):std.String {
		// Use the `getNormalizedAbsolutePath` function to avoid canonicalizing the path, as it must remain noncanonical
		// until consistent casing errors are reported
		return Tspath.GetDirectoryPath(Tspath.GetNormalizedAbsolutePath(fileName, basePath));
	}

	// ParseConfigFileTextToJson parses the text of the tsconfig.json file
	// fileName is the path to the config file
	// jsonText is the text of the config file
	public static function ParseConfigFileTextToJson(fileName:std.String, path:Path, jsonText:std.String):Pair<Dynamic, Null<Array<Diagnostic>>> {
		final opts = new SourceFileParseOptions();
		opts.FileName = fileName;
		opts.Path = path;
		final jsonSourceFile = Parser.ParseSourceFile(opts, jsonText, ScriptKindJSON);
		final r = convertConfigFileToObject(jsonSourceFile /*jsonConversionNotifier*/, null);
		final config = r.a;
		var errors = r.b;
		if (Core.len(jsonSourceFile.Diagnostics()) > 0) {
			errors = [jsonSourceFile.Diagnostics()[0]];
		}
		return new Pair<Dynamic, Null<Array<Diagnostic>>>(config, errors);
	}

	public static function ParseJsonSourceFileConfigFileContent(sourceFile:TsConfigSourceFile, host:ParseConfigHost, basePath:std.String,
			existingOptions:Null<CompilerOptions>, existingOptionsRaw:Null<OrderedMap<std.String, Dynamic>>, configFileName:std.String,
			resolutionStack:Null<Array<Path>>, extraFileExtensions:Null<Array<FileExtensionInfo>>,
			extendedConfigCache:Null<ExtendedConfigCache>):ParsedCommandLine {
		// tracing?.push(tracing.Phase.Parse, "parseJsonSourceFileConfigFileContent", { path: sourceFile.fileName });
		final result = parseJsonConfigFileContentWorker(null /*json*/, sourceFile, host, basePath, existingOptions, existingOptionsRaw, configFileName,
			resolutionStack, extraFileExtensions, extendedConfigCache);
		// tracing?.pop();
		return result;
	}

	static function convertObjectLiteralExpressionToJson(sourceFile:SourceFile, returnValue:Bool, node:ObjectLiteralExpression,
			objectOption:Null<CommandLineOption>,
			jsonConversionNotifier:Null<JsonConversionNotifier>):Pair<Null<OrderedMap<std.String, Dynamic>>, Null<Array<Diagnostic>>> {
		var result:Null<OrderedMap<std.String, Dynamic>> = null;
		if (returnValue) {
			result = new OrderedMap<std.String, Dynamic>();
		}
		var errors:Null<Array<Diagnostic>> = null;
		final properties = node.Properties.Nodes;
		for (element in (properties == null ? [] : properties)) {
			if (element.Kind != KindPropertyAssignment) {
				errors = appendDiag(errors, Ast.NewDiagnostic(sourceFile, element.Loc, Diagnostics.Property_assignment_expected));
				continue;
			}

			final token = element.QuestionToken();
			if (token != null) {
				errors = appendDiag(errors, Ast.NewDiagnostic(sourceFile, token.Loc, Diagnostics.The_0_modifier_can_only_be_used_in_TypeScript_files, "?"));
			}
			var textOfKey = "";
			if (!Ast.IsComputedNonLiteralName(element.Name())) {
				textOfKey = Ast.TryGetTextOfPropertyName(element.Name()).value;
			}
			final keyText = textOfKey;
			var option:Null<CommandLineOption> = null;
			if (keyText != "" && objectOption != null && objectOption.ElementOptions != null) {
				option = objectOption.ElementOptions.Get(keyText);
				if (option != null && option.Name != keyText) {
					option = null;
				}
			}
			final r = convertPropertyValueToJson(sourceFile, element.AsPropertyAssignment().Initializer, option, returnValue, jsonConversionNotifier);
			final value = r.a;
			errors = appendDiags(errors, r.b);
			if (keyText != "") {
				if (returnValue) {
					result.Set(keyText, value);
				}
				// Notify key value set, if user asked for it
				if (jsonConversionNotifier != null) {
					final r2 = jsonConversionNotifier.onPropertySet(keyText, value, element.AsPropertyAssignment(), objectOption, option);
					errors = appendDiags(errors, r2.b);
				}
			}
		}
		return new Pair<Null<OrderedMap<std.String, Dynamic>>, Null<Array<Diagnostic>>>(result, errors);
	}

	// convertToJson converts the json syntax tree into the json value and report errors
	// This returns the json value (apart from checking errors) only if returnValue provided is true.
	// Otherwise it just checks the errors and returns undefined
	static function convertToJson(sourceFile:SourceFile, rootExpression:Null<Node>, returnValue:Bool,
			jsonConversionNotifier:Null<JsonConversionNotifier>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		if (rootExpression == null) {
			if (returnValue) {
				// PORT: Go returns `struct{}{}` (marshals as {}); an empty OrderedMap behaves the same
				// everywhere it is used (no keys, marshals as {}).
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(new OrderedMap<std.String, Dynamic>(), null);
			} else {
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);
			}
		}
		var rootOptions:Null<CommandLineOption> = null;
		if (jsonConversionNotifier != null) {
			rootOptions = jsonConversionNotifier.rootOptions;
		}
		return convertPropertyValueToJson(sourceFile, rootExpression, rootOptions, returnValue, jsonConversionNotifier);
	}

	static function isDoubleQuotedString(node:Node):Bool {
		return Ast.IsStringLiteral(node);
	}

	static function convertPropertyValueToJson(sourceFile:SourceFile, valueExpression:Node, option:Null<CommandLineOption>, returnValue:Bool,
			jsonConversionNotifier:Null<JsonConversionNotifier>):Pair<Dynamic, Null<Array<Diagnostic>>> {
		switch (valueExpression.Kind) {
			case KindTrueKeyword:
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(true, null);
			case KindFalseKeyword:
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(false, null);
			case KindNullKeyword: // todo: how to manage null
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, null);

			case KindStringLiteral:
				if (!isDoubleQuotedString(valueExpression)) {
					return new Pair<Dynamic, Null<Array<Diagnostic>>>(valueExpression.Text(), [
						Ast.NewDiagnostic(sourceFile, valueExpression.Loc, Diagnostics.String_literal_with_double_quotes_expected)
					]);
				}
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(valueExpression.Text(), null);

			case KindNumericLiteral:
				final n:Float = Jsnum.FromString(valueExpression.Text());
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(n, null);
			case KindPrefixUnaryExpression:
				// PORT: Go `break`s out of the switch when the operand is not valid JSON syntax.
				if (!(valueExpression.AsPrefixUnaryExpression().Operator != KindMinusToken
					|| valueExpression.AsPrefixUnaryExpression().Operand.Kind != KindNumericLiteral)) {
					final n:Float = -(Jsnum.FromString(valueExpression.AsPrefixUnaryExpression().Operand.Text()) : Float);
					return new Pair<Dynamic, Null<Array<Diagnostic>>>(n, null);
				}
				// not valid JSON syntax
			case KindObjectLiteralExpression:
				final objectLiteralExpression = valueExpression.AsObjectLiteralExpression();
				// Currently having element option declaration in the tsconfig with type "object"
				// determines if it needs onSetValidOptionKeyValueInParent callback or not
				// At moment there are only "compilerOptions", "typeAcquisition" and "typingOptions"
				// that satisfies it and need it to modify options set in them (for normalizing file paths)
				// vs what we set in the json
				// If need arises, we can modify this interface and callbacks as needed
				final r = convertObjectLiteralExpressionToJson(sourceFile, returnValue, objectLiteralExpression, option, jsonConversionNotifier);
				return new Pair<Dynamic, Null<Array<Diagnostic>>>(r.a, r.b);
			case KindArrayLiteralExpression:
				final r = convertArrayLiteralExpressionToJson(sourceFile, valueExpression.Elements(), option, returnValue);
				return r;
			default:
		}
		// Not in expected format
		var errors:Null<Array<Diagnostic>> = null;
		if (option != null) {
			errors = [
				Ast.NewDiagnostic(sourceFile, valueExpression.Loc, Diagnostics.Compiler_option_0_requires_a_value_of_type_1, option.Name,
					getCompilerOptionValueTypeString(option))
			];
		} else {
			errors = [
				Ast.NewDiagnostic(sourceFile, valueExpression.Loc,
					Diagnostics.Property_value_can_only_be_string_literal_numeric_literal_true_false_null_object_literal_or_array_literal)
			];
		}
		return new Pair<Dynamic, Null<Array<Diagnostic>>>(null, errors);
	}

	// ParseJsonConfigFileContent parses the contents of a config file (tsconfig.json).
	// jsonNode: The contents of the config file to parse
	// host: Instance of ParseConfigHost used to enumerate files in folder.
	// basePath: A root directory to resolve relative path entries in the config file to. e.g. outDir
	public static function ParseJsonConfigFileContent(json:Dynamic, host:ParseConfigHost, basePath:std.String, existingOptions:Null<CompilerOptions>,
			configFileName:std.String, resolutionStack:Null<Array<Path>>, extraFileExtensions:Null<Array<FileExtensionInfo>>,
			extendedConfigCache:Null<ExtendedConfigCache>):ParsedCommandLine {
		final result = parseJsonConfigFileContentWorker(parseJsonToStringKey(json), null /*sourceFile*/, host, basePath, existingOptions,
			null /*existingOptionsRaw*/, configFileName, resolutionStack, extraFileExtensions, extendedConfigCache);
		return result;
	}

	// convertToObject converts the json syntax tree into the json value
	static function convertToObject(sourceFile:SourceFile):Pair<Dynamic, Null<Array<Diagnostic>>> {
		var rootExpression:Null<Node> = null;
		if (Core.len(sourceFile.Statements.Nodes) != 0) {
			rootExpression = sourceFile.Statements.Nodes[0].Expression();
		}
		return convertToJson(sourceFile, rootExpression, true /*returnValue*/, null /*jsonConversionNotifier*/);
	}

	static function getDefaultCompilerOptions(configFileName:std.String):CompilerOptions {
		var options = new CompilerOptions();
		if (configFileName != "" && Tspath.GetBaseFileName(configFileName) == "jsconfig.json") {
			final depth = 2;
			options = new CompilerOptions();
			options.AllowJs = TSTrue;
			options.MaxNodeModuleJsDepth = depth;
			options.SkipLibCheck = TSTrue;
			options.NoEmit = TSTrue;
		}
		return options;
	}

	static function getDefaultTypeAcquisition(configFileName:std.String):TypeAcquisition {
		final options = new TypeAcquisition();
		if (configFileName != "" && Tspath.GetBaseFileName(configFileName) == "jsconfig.json") {
			options.Enable = TSTrue;
		}
		return options;
	}

	static function convertCompilerOptionsFromJsonWorker(jsonOptions:Dynamic, basePath:std.String,
			configFileName:std.String):Pair<CompilerOptions, Null<Array<Diagnostic>>> {
		final options = getDefaultCompilerOptions(configFileName);
		final errors = convertOptionsFromJson(CommandLineCompilerOptionsMap, jsonOptions, basePath, new CompilerOptionsParser(options)).b;
		if (configFileName != "") {
			options.ConfigFilePath = Tspath.NormalizeSlashes(configFileName);
		}
		return new Pair<CompilerOptions, Null<Array<Diagnostic>>>(options, errors);
	}

	static function convertTypeAcquisitionFromJsonWorker(jsonOptions:Dynamic, basePath:std.String,
			configFileName:std.String):Pair<TypeAcquisition, Null<Array<Diagnostic>>> {
		final options = getDefaultTypeAcquisition(configFileName);
		final errors = convertOptionsFromJson(typeAcquisitionDeclaration.ElementOptions, jsonOptions, basePath, new TypeAcquisitionParser(options)).b;
		return new Pair<TypeAcquisition, Null<Array<Diagnostic>>>(options, errors);
	}

	static function parseOwnConfigOfJson(json:OrderedMap<std.String, Dynamic>, host:ParseConfigHost, basePath:std.String,
			configFileName:std.String):Pair<ParsedTsconfig, Null<Array<Diagnostic>>> {
		var errors:Null<Array<Diagnostic>> = null;
		if (json.Has("excludes")) {
			errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Unknown_option_excludes_Did_you_mean_exclude));
		}
		final r = convertCompilerOptionsFromJsonWorker(json.GetOrZero("compilerOptions"), basePath, configFileName);
		final options = r.a;
		var err = r.b;
		final r2 = convertTypeAcquisitionFromJsonWorker(json.GetOrZero("typeAcquisition"), basePath, configFileName);
		final typeAcquisition = r2.a;
		final err2 = r2.b;
		errors = appendDiags(appendDiags(errors, err), err2);
		// watchOptions := convertWatchOptionsFromJsonWorker(json.watchOptions, basePath, errors)
		// json.compileOnSave = convertCompileOnSaveOptionFromJson(json, basePath, errors)
		var extendedConfigPath:Null<Array<std.String>> = null;
		final extends_ = json.GetOrZero("extends");
		if (extends_ != null && !(isString(extends_) && (extends_ : std.String) == "")) {
			final r3 = getExtendsConfigPathOrArray(extends_, host, basePath, configFileName, null, null, null);
			extendedConfigPath = r3.a;
			err = r3.b;
			errors = appendDiags(errors, err);
		}
		final parsedConfig = new ParsedTsconfig();
		parsedConfig.raw = json;
		parsedConfig.options = options;
		parsedConfig.typeAcquisition = typeAcquisition;
		parsedConfig.extendedConfigPath = stringSliceToAny(extendedConfigPath);
		return new Pair<ParsedTsconfig, Null<Array<Diagnostic>>>(parsedConfig, errors);
	}

	static function readJsonConfigFile(fileName:std.String, path:Path,
			readFile:(fileName:std.String) -> ValueOk<std.String>):Pair<TsConfigSourceFile, Null<Array<Diagnostic>>> {
		final r = tryReadFile(fileName, readFile, []);
		final text = r.a;
		final diagnostic = r.b;
		if (text != "") {
			final opts = new SourceFileParseOptions();
			opts.FileName = fileName;
			opts.Path = path;
			return new Pair<TsConfigSourceFile, Null<Array<Diagnostic>>>(new TsConfigSourceFile(Parser.ParseSourceFile(opts, text, ScriptKindJSON)),
				diagnostic);
		} else {
			final factory = new NodeFactory();
			final opts = new SourceFileParseOptions();
			opts.FileName = fileName;
			opts.Path = path;
			final file = new TsConfigSourceFile(factory.NewSourceFile(opts, "", factory.NewNodeList([]), factory.NewToken(KindEndOfFile)).AsSourceFile());
			file.SourceFile.SetDiagnostics(diagnostic);
			return new Pair<TsConfigSourceFile, Null<Array<Diagnostic>>>(file, diagnostic);
		}
	}

	static function getExtendedConfig(sourceFile:Null<TsConfigSourceFile>, extendedConfigFileName:std.String, host:ParseConfigHost,
			resolutionStack:Null<Array<Path>>, extendedConfigCache:Null<ExtendedConfigCache>,
			result:ExtendsResult):Pair<Null<ParsedTsconfig>, Null<Array<Diagnostic>>> {
		var errors:Null<Array<Diagnostic>> = null;
		final extendedConfigPath = Tspath.ToPath(extendedConfigFileName, host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames());

		var cacheEntry:ExtendedConfigCacheEntry = null;
		// Bypass the cache when we detect a cycle in the resolution stack.
		// The cache locks entries during parsing, and a cycle would cause the same goroutine
		// to re-lock the same entry, resulting in a deadlock. Let parseConfig handle the
		// circularity error via its own resolution stack check.
		if (extendedConfigCache != null && !Slices.Contains(resolutionStack, extendedConfigPath)) {
			cacheEntry = extendedConfigCache.GetExtendedConfig(extendedConfigFileName, extendedConfigPath, resolutionStack, host);
		} else {
			cacheEntry = ParseExtendedConfig(extendedConfigFileName, extendedConfigPath, resolutionStack, host, extendedConfigCache);
		}

		if (Core.len(cacheEntry.errors) > 0) {
			errors = appendDiags(errors, cacheEntry.errors);
		}

		if (cacheEntry.extendedResult != null) {
			if (sourceFile != null) {
				result.extendedSourceFiles.Add(cacheEntry.extendedResult.SourceFile.FileName());
				if (cacheEntry.extendedResult.ExtendedSourceFiles != null) {
					for (extendedSourceFile in cacheEntry.extendedResult.ExtendedSourceFiles) {
						result.extendedSourceFiles.Add(extendedSourceFile);
					}
				}
			}
		}
		return new Pair<Null<ParsedTsconfig>, Null<Array<Diagnostic>>>(cacheEntry.extendedConfig, errors);
	}

	public static function ParseExtendedConfig(fileName:std.String, path:Path, resolutionStack:Null<Array<Path>>, host:ParseConfigHost,
			extendedConfigCache:Null<ExtendedConfigCache>):ExtendedConfigCacheEntry {
		final fs = host.FS();
		final r = readJsonConfigFile(fileName, path, fs.ReadFile);
		final extendedResult = r.a;
		final readErrors = r.b;
		final entry = new ExtendedConfigCacheEntry();
		entry.extendedResult = extendedResult;

		if (Core.len(readErrors) > 0) {
			entry.errors = readErrors;
			return entry;
		}

		final parseDiagnostics = extendedResult.SourceFile.Diagnostics();
		if (Core.len(parseDiagnostics) > 0) {
			entry.errors = parseDiagnostics;
			return entry;
		}

		final r2 = parseConfig(null, extendedResult, host, Tspath.GetDirectoryPath(fileName), Tspath.GetBaseFileName(fileName), resolutionStack,
			extendedConfigCache);
		entry.extendedConfig = r2.a;
		entry.errors = r2.b;
		return entry;
	}

	// parseConfig just extracts options/include/exclude/files out of a config file.
	// It does not resolve the included files.
	static function parseConfig(json:Null<OrderedMap<std.String, Dynamic>>, sourceFile:Null<TsConfigSourceFile>, host:ParseConfigHost,
			basePath:std.String, configFileName:std.String, resolutionStack:Null<Array<Path>>,
			extendedConfigCache:Null<ExtendedConfigCache>):Pair<ParsedTsconfig, Null<Array<Diagnostic>>> {
		basePath = Tspath.NormalizeSlashes(basePath);
		final resolvedPath = Tspath.ToPath(configFileName, basePath, host.FS().UseCaseSensitiveFileNames());
		var errors:Null<Array<Diagnostic>> = null;
		if (Slices.Contains(resolutionStack, resolvedPath)) {
			var result:ParsedTsconfig = null;
			errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Circularity_detected_while_resolving_configuration_Colon_0));
			if (json.Size() == 0) {
				result = new ParsedTsconfig();
				result.raw = json;
			} else {
				final r = convertToObject(sourceFile.SourceFile);
				errors = appendDiags(errors, r.b);
				result = new ParsedTsconfig();
				result.raw = r.a;
			}
			return new Pair<ParsedTsconfig, Null<Array<Diagnostic>>>(result, errors);
		}

		var ownConfig:ParsedTsconfig = null;
		var err:Null<Array<Diagnostic>> = null;
		if (json != null) {
			final r = parseOwnConfigOfJson(json, host, basePath, configFileName);
			ownConfig = r.a;
			err = r.b;
		} else {
			final r = parseOwnConfigOfJsonSourceFile(tsconfigToSourceFile(sourceFile), host, basePath, configFileName);
			ownConfig = r.a;
			err = r.b;
		}
		errors = appendDiags(errors, err);
		if (ownConfig.options != null && ownConfig.options.Paths != null) {
			// If we end up needing to resolve relative paths from 'paths' relative to
			// the config file location, we'll need to know where that config file was.
			// Since 'paths' can be inherited from an extended config in another directory,
			// we wouldn't know which directory to use unless we store it here.
			ownConfig.options.PathsBasePath = basePath;
		}

		final applyExtendedConfig = function(result:ExtendsResult, extendedConfigPath:std.String):Void {
			final r = getExtendedConfig(sourceFile, extendedConfigPath, host, resolutionStack, extendedConfigCache, result);
			final extendedConfig = r.a;
			errors = appendDiags(errors, r.b);
			if (extendedConfig != null && extendedConfig.options != null) {
				final extendsRaw = extendedConfig.raw;
				var relativeDifference = "";
				final setPropertyValue = function(propertyName:std.String):Void {
					if (isOrderedMap(ownConfig.raw) && (ownConfig.raw : OrderedMap<std.String, Dynamic>).Has(propertyName)) {
						return;
					}
					if (propertyName == "include" || propertyName == "exclude" || propertyName == "files") {
						if (isOrderedMap(extendsRaw) && (extendsRaw : OrderedMap<std.String, Dynamic>).Has(propertyName)) {
							final rawValue = (extendsRaw : OrderedMap<std.String, Dynamic>).GetOrZero(propertyName);
							final slice = isAnySlice(rawValue) ? asAnySlice(rawValue) : null;
							if (slice != null) {
								final value = Core.Map(slice, function(path:Dynamic):Dynamic {
									if (!isString(path)) {
										return path;
									}
									final pathStr:std.String = path;
									if (startsWithConfigDirTemplate(path) || Tspath.IsRootedDiskPath(pathStr)) {
										return pathStr;
									} else {
										if (relativeDifference == "") {
											final t = new ComparePathsOptions(host.FS().UseCaseSensitiveFileNames(), basePath);
											relativeDifference = Tspath.ConvertToRelativePath(Tspath.GetDirectoryPath(extendedConfigPath), t);
										}
										return Tspath.CombinePaths(relativeDifference, pathStr);
									}
								});
								if (propertyName == "include") {
									result.include = value;
								} else if (propertyName == "exclude") {
									result.exclude = value;
								} else if (propertyName == "files") {
									result.files = value;
								}
							}
						}
					}
				};

				setPropertyValue("include");
				setPropertyValue("exclude");
				setPropertyValue("files");
				if (isOrderedMap(extendsRaw) && (extendsRaw : OrderedMap<std.String, Dynamic>).Has("compileOnSave")) {
					final compileOnSave = (extendsRaw : OrderedMap<std.String, Dynamic>).GetOrZero("compileOnSave");
					if (isBool(compileOnSave)) {
						result.compileOnSave = compileOnSave;
					}
				}
				mergeCompilerOptions(result.options, extendedConfig.options, extendsRaw);
			}
		};

		if (ownConfig.extendedConfigPath != null) {
			// copy the resolution stack so it is never reused between branches in potential diamond-problem scenarios.
			// PORT: Go append may share the backing array; an explicit copy is equivalent here.
			resolutionStack = resolutionStack == null ? [] : resolutionStack.copy();
			resolutionStack.push(resolvedPath);
			final result = new ExtendsResult();
			result.options = new CompilerOptions();
			if (isString(ownConfig.extendedConfigPath)) {
				applyExtendedConfig(result, ownConfig.extendedConfigPath);
			} else if (isSlice(ownConfig.extendedConfigPath)) {
				// PORT: Go `.([]string)`; this slot only ever holds a []string.
				final configPath:Array<std.String> = ownConfig.extendedConfigPath;
				for (extendedConfigPath in configPath) {
					applyExtendedConfig(result, extendedConfigPath);
				}
			}
			if (result.include != null) {
				(ownConfig.raw : OrderedMap<std.String, Dynamic>).Set("include", result.include);
			}
			if (result.exclude != null) {
				(ownConfig.raw : OrderedMap<std.String, Dynamic>).Set("exclude", result.exclude);
			}
			if (result.files != null) {
				(ownConfig.raw : OrderedMap<std.String, Dynamic>).Set("files", result.files);
			}
			if (result.compileOnSave && !(ownConfig.raw : OrderedMap<std.String, Dynamic>).Has("compileOnSave")) {
				(ownConfig.raw : OrderedMap<std.String, Dynamic>).Set("compileOnSave", result.compileOnSave);
			}
			if (sourceFile != null) {
				final keys = result.extendedSourceFiles.Keys();
				if (keys != null) {
					for (extendedSourceFile in keys.keys()) {
						sourceFile.ExtendedSourceFiles = Core.InsertSorted(sourceFile.ExtendedSourceFiles, extendedSourceFile, Strings.Compare);
					}
				}
			}
			ownConfig.options = mergeCompilerOptions(result.options, ownConfig.options, ownConfig.raw);
			// ownConfig.watchOptions = ownConfig.watchOptions && result.watchOptions ?
			//     assignWatchOptions(result, ownConfig.watchOptions) :
			//     ownConfig.watchOptions || result.watchOptions;
		}
		return new Pair<ParsedTsconfig, Null<Array<Diagnostic>>>(ownConfig, errors);
	}

	static inline final defaultIncludeSpec = "**/*";

	// parseJsonConfigFileContentWorker parses the contents of a config file from json or json source file (tsconfig.json).
	// json: The contents of the config file to parse
	// sourceFile: sourceFile corresponding to the Json
	// host: Instance of ParseConfigHost used to enumerate files in folder.
	// basePath: A root directory to resolve relative path entries in the config file to. e.g. outDir
	// resolutionStack: Only present for backwards-compatibility. Should be empty.
	static function parseJsonConfigFileContentWorker(json:Null<OrderedMap<std.String, Dynamic>>, sourceFile:Null<TsConfigSourceFile>,
			host:ParseConfigHost, basePath:std.String, existingOptions:Null<CompilerOptions>, existingOptionsRaw:Null<OrderedMap<std.String, Dynamic>>,
			configFileName:std.String, resolutionStack:Null<Array<Path>>, extraFileExtensions:Null<Array<FileExtensionInfo>>,
			extendedConfigCache:Null<ExtendedConfigCache>):ParsedCommandLine {
		Debug.Assert((json == null && sourceFile != null) || (json != null && sourceFile == null));

		var basePathForFileNames = "";
		if (configFileName != "") {
			basePathForFileNames = Tspath.NormalizePath(directoryOfCombinedPath(configFileName, basePath));
		} else {
			basePathForFileNames = Tspath.NormalizePath(basePath);
		}

		final r = parseConfig(json, sourceFile, host, basePath, configFileName, resolutionStack, extendedConfigCache);
		final parsedConfig = r.a;
		var errors = r.b;
		mergeCompilerOptions(parsedConfig.options, existingOptions, existingOptionsRaw);
		handleOptionConfigDirTemplateSubstitution(parsedConfig.options, basePathForFileNames);
		final rawConfig = parseJsonToStringKey(parsedConfig.raw);
		if (configFileName != "" && parsedConfig.options != null) {
			parsedConfig.options.ConfigFilePath = Tspath.NormalizeSlashes(configFileName);
		}
		final getPropFromRaw = function(prop:std.String, validateElement:(value:Dynamic) -> Bool, elementTypeName:std.String):PropOfRaw {
			final g = rawConfig.Get(prop);
			final value = g.value;
			final exists = g.ok;
			if (exists && value != null) {
				if (isSlice(value)) {
					final result = rawConfig.GetOrZero(prop);
					if (isAnySlice(result)) {
						if (sourceFile == null && !Core.Every(asAnySlice(result), validateElement)) {
							errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Compiler_option_0_requires_a_value_of_type_1, prop, elementTypeName));
						}
					}
					return new PropOfRaw(asAnySlice(result));
				} else if (sourceFile == null) {
					errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Compiler_option_0_requires_a_value_of_type_1, prop, "Array"));
					return new PropOfRaw(null, "not-array");
				}
			}
			return new PropOfRaw(null, "no-prop");
		};
		final referencesOfRaw = getPropFromRaw("references", function(element:Dynamic):Bool {
			return isOrderedMap(element);
		}, "object");
		var fileSpecs = getPropFromRaw("files", function(element:Dynamic):Bool {
			return isString(element);
		}, "string");
		if (fileSpecs.sliceValue != null || fileSpecs.wrongValue == "") {
			var hasZeroOrNoReferences = false;
			if (referencesOfRaw.wrongValue == "no-prop" || referencesOfRaw.wrongValue == "not-array" || Core.len(referencesOfRaw.sliceValue) == 0) {
				hasZeroOrNoReferences = true;
			}
			final hasExtends = rawConfig.GetOrZero("extends");
			if (fileSpecs.sliceValue != null && fileSpecs.sliceValue.length == 0 && hasZeroOrNoReferences && hasExtends == null) {
				if (sourceFile != null) {
					var fileName:std.String;
					if (configFileName != "") {
						fileName = configFileName;
					} else {
						fileName = "tsconfig.json";
					}
					final diagnosticMessage = Diagnostics.The_files_list_in_config_file_0_is_empty;
					final nodeValue = ForEachTsConfigPropArray(sourceFile.SourceFile, "files", function(property:PropertyAssignment):Null<Node> {
						return property.Initializer;
					});
					errors = appendDiag(errors, CreateDiagnosticForNodeInSourceFile(sourceFile.SourceFile, nodeValue, diagnosticMessage, fileName));
				} else {
					errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.The_files_list_in_config_file_0_is_empty, configFileName));
				}
			}
		}
		var includeSpecs = getPropFromRaw("include", function(element:Dynamic):Bool {
			return isString(element);
		}, "string");
		var excludeSpecs = getPropFromRaw("exclude", function(element:Dynamic):Bool {
			return isString(element);
		}, "string");
		var isDefaultIncludeSpec = false;
		if (excludeSpecs.wrongValue == "no-prop" && parsedConfig.options != null) {
			final outDir = parsedConfig.options.OutDir;
			final declarationDir = parsedConfig.options.DeclarationDir;
			if (outDir != "" || declarationDir != "") {
				final values:Array<Dynamic> = [];
				if (outDir != "") {
					values.push(outDir);
				}
				if (declarationDir != "") {
					values.push(declarationDir);
				}
				excludeSpecs = new PropOfRaw(values);
			}
		}
		if (fileSpecs.sliceValue == null && includeSpecs.sliceValue == null) {
			includeSpecs = new PropOfRaw(([defaultIncludeSpec] : Array<Dynamic>));
			isDefaultIncludeSpec = true;
		}
		var validatedIncludeSpecs:Null<Array<std.String>> = null;
		var validatedIncludeSpecsBeforeSubstitution:Null<Array<std.String>> = null;
		var validatedExcludeSpecs:Null<Array<std.String>> = null;
		var validatedFilesSpec:Null<Array<std.String>> = null;
		var validatedFilesSpecBeforeSubstitution:Null<Array<std.String>> = null;
		// The exclude spec list is converted into a regular expression, which allows us to quickly
		// test whether a file or directory should be excluded before recursively traversing the
		// file system.
		if (includeSpecs.sliceValue != null) {
			final r = validateSpecs(includeSpecs.sliceValue, true /*disallowTrailingRecursion*/, tsconfigToSourceFile(sourceFile), "include");
			validatedIncludeSpecsBeforeSubstitution = r.a;
			errors = appendDiags(errors, r.b);
			if ((validatedIncludeSpecs = getSubstitutedStringArrayWithConfigDirTemplate(validatedIncludeSpecsBeforeSubstitution, basePathForFileNames)) == null) {
				validatedIncludeSpecs = validatedIncludeSpecsBeforeSubstitution;
			}
		}
		if (excludeSpecs.sliceValue != null) {
			final r = validateSpecs(excludeSpecs.sliceValue, false /*disallowTrailingRecursion*/, tsconfigToSourceFile(sourceFile), "exclude");
			validatedExcludeSpecs = r.a;
			errors = appendDiags(errors, r.b);
			final validatedExcludeSpecsWithSubstitution = getSubstitutedStringArrayWithConfigDirTemplate(validatedExcludeSpecs, basePathForFileNames);
			if (validatedExcludeSpecsWithSubstitution != null) {
				validatedExcludeSpecs = validatedExcludeSpecsWithSubstitution;
			}
		}
		if (fileSpecs.sliceValue != null) {
			final fileSpecs = Core.Filter(fileSpecs.sliceValue, function(spec:Dynamic):Bool {
				return isString(spec);
			});
			for (spec in fileSpecs) {
				if (isString(spec)) {
					if (validatedFilesSpecBeforeSubstitution == null)
						validatedFilesSpecBeforeSubstitution = [];
					validatedFilesSpecBeforeSubstitution.push(spec);
				}
			}
			if ((validatedFilesSpec = getSubstitutedStringArrayWithConfigDirTemplate(validatedFilesSpecBeforeSubstitution, basePathForFileNames)) == null) {
				validatedFilesSpec = validatedFilesSpecBeforeSubstitution;
			}
		}
		// PORT: the []any fields hold a Go typed nil when the slice is nil (anySliceToAny).
		final configFileSpecs = new ConfigFileSpecs(anySliceToAny(fileSpecs.sliceValue), anySliceToAny(includeSpecs.sliceValue),
			anySliceToAny(excludeSpecs.sliceValue), validatedFilesSpec, validatedIncludeSpecs, validatedExcludeSpecs, validatedFilesSpecBeforeSubstitution,
			validatedIncludeSpecsBeforeSubstitution, isDefaultIncludeSpec);

		if (sourceFile != null) {
			sourceFile.configFileSpecs = configFileSpecs;
		}

		final getFileNames = function(basePath:std.String):Pair<Array<std.String>, Int> {
			final parsedConfigOptions = parsedConfig.options;
			final r = getFileNamesFromConfigSpecs(configFileSpecs, basePath, parsedConfigOptions, host.FS(), extraFileExtensions);
			final fileNames = r.a;
			final literalFileNamesLen = r.b;
			if (shouldReportNoInputFiles(fileNames, canJsonReportNoInputFiles(rawConfig), resolutionStack)) {
				var includeSpecs:Dynamic = configFileSpecs.includeSpecs;
				var excludeSpecs:Dynamic = configFileSpecs.excludeSpecs;
				if (includeSpecs == null) {
					includeSpecs = ([] : Array<std.String>);
				}
				if (excludeSpecs == null) {
					excludeSpecs = ([] : Array<std.String>);
				}
				// PORT: core.StringifyJson (Go json.Marshal) → ts.json.Json.MarshalOrdered (Go-compatible output).
				errors = appendDiag(errors,
					Ast.NewCompilerDiagnostic(Diagnostics.No_inputs_were_found_in_config_file_0_Specified_include_paths_were_1_and_exclude_paths_were_2,
						configFileName, Json.MarshalOrdered(includeSpecs), Json.MarshalOrdered(excludeSpecs)));
			}
			return new Pair<Array<std.String>, Int>(fileNames, literalFileNamesLen);
		};

		final getProjectReferences = function(basePath:std.String):Null<Array<ProjectReference>> {
			var projectReferences:Null<Array<ProjectReference>> = null;
			final newReferencesOfRaw = getPropFromRaw("references", function(element:Dynamic):Bool {
				return isOrderedMap(element);
			}, "object");
			if (newReferencesOfRaw.sliceValue != null) {
				projectReferences = [];
				for (reference in newReferencesOfRaw.sliceValue) {
					final refs = parseProjectReference(reference);
					if (refs != null) {
						for (ref in refs) {
							if (ref.Path == "") {
								if (sourceFile == null) {
									errors = appendDiag(errors, Ast.NewCompilerDiagnostic(Diagnostics.Compiler_option_0_requires_a_value_of_type_1, "reference.path", "string"));
								}
							} else {
								final pr = new ProjectReference();
								pr.Path = Tspath.GetNormalizedAbsolutePath(ref.Path, basePath);
								pr.OriginalPath = ref.Path;
								pr.Circular = ref.Circular;
								projectReferences.push(pr);
							}
						}
					}
				}
			}
			return projectReferences;
		};

		final fn = getFileNames(basePathForFileNames);
		final fileNames = fn.a;
		final literalFileNamesLen = fn.b;
		final result = new ParsedCommandLine();
		final parsedOptions = new ParsedOptions();
		parsedOptions.CompilerOptions = parsedConfig.options;
		parsedOptions.TypeAcquisition = parsedConfig.typeAcquisition;
		// WatchOptions:      nil,
		parsedOptions.FileNames = fileNames;
		parsedOptions.ProjectReferences = getProjectReferences(basePathForFileNames);
		result.ParsedConfig = parsedOptions;
		result.ConfigFile = sourceFile;
		result.Raw = parsedConfig.raw;
		result.Errors = errors;

		result.extraFileExtensions = extraFileExtensions;
		result.comparePathsOptions = new ComparePathsOptions(host.FS().UseCaseSensitiveFileNames(), basePathForFileNames);
		result.literalFileNamesLen = literalFileNamesLen;
		return result;
	}

	static function canJsonReportNoInputFiles(rawConfig:OrderedMap<std.String, Dynamic>):Bool {
		final filesExists = rawConfig.Has("files");
		final referencesExists = rawConfig.Has("references");
		return !filesExists && !referencesExists;
	}

	static function shouldReportNoInputFiles(fileNames:Null<Array<std.String>>, canJsonReportNoInputFiles:Bool, resolutionStack:Null<Array<Path>>):Bool {
		return Core.len(fileNames) == 0 && canJsonReportNoInputFiles && Core.len(resolutionStack) == 0;
	}

	static function validateSpecs(specs:Dynamic, disallowTrailingRecursion:Bool, jsonSourceFile:Null<SourceFile>,
			specKey:std.String):Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>> {
		final createDiagnostic = function(message:Message, spec:std.String):Diagnostic {
			final element = GetTsConfigPropArrayElementValue(jsonSourceFile, specKey, spec);
			var node:Null<Node> = null;
			if (element != null) {
				node = element.AsNode();
			}
			return CreateDiagnosticForNodeInSourceFileOrCompilerDiagnostic(jsonSourceFile, node, message, spec);
		};
		var errors:Null<Array<Diagnostic>> = null;
		var finalSpecs:Null<Array<std.String>> = null;
		final arr:Null<Array<Dynamic>> = asAnySlice(specs);
		if (arr != null) {
			for (spec in arr) {
				if (!isString(spec)) {
					continue;
				}
				final diag = specToDiagnostic(spec, disallowTrailingRecursion);
				if (diag != null) {
					errors = appendDiag(errors, createDiagnostic(diag, spec));
				} else {
					if (finalSpecs == null)
						finalSpecs = [];
					finalSpecs.push(spec);
				}
			}
		}
		return new Pair<Null<Array<std.String>>, Null<Array<Diagnostic>>>(finalSpecs, errors);
	}

	static function specToDiagnostic(spec:std.String, disallowTrailingRecursion:Bool):Null<Message> {
		if (disallowTrailingRecursion && invalidTrailingRecursion(spec)) {
			return Diagnostics.File_specification_cannot_end_in_a_recursive_directory_wildcard_Asterisk_Asterisk_Colon_0;
		}
		if (invalidDotDotAfterRecursiveWildcard(spec)) {
			return Diagnostics.File_specification_cannot_contain_a_parent_directory_that_appears_after_a_recursive_directory_wildcard_Asterisk_Asterisk_Colon_0;
		}
		return null;
	}

	static function invalidTrailingRecursion(spec:std.String):Bool {
		// Matches **, /**, **/, and /**/, but not a**b.
		// Strip optional trailing slash, then check if it ends with /** or is just **
		final s = Strings.TrimSuffix(spec, "/");
		return s == "**" || StringTools.endsWith(s, "/**");
	}

	static function invalidDotDotAfterRecursiveWildcard(s:std.String):Bool {
		// We used to use the regex /(^|\/)\*\*\/(.*\/)?\.\.($|\/)/ to check for this case, but
		// in v8, that has polynomial performance because the recursive wildcard match - **/ -
		// can be matched in many arbitrary positions when multiple are present, resulting
		// in bad backtracking (and we don't care which is matched - just that some /.. segment
		// comes after some **/ segment).
		var wildcardIndex:Int;
		if (StringTools.startsWith(s, "**/")) {
			wildcardIndex = 0;
		} else {
			wildcardIndex = s.indexOf("/**/");
		}
		if (wildcardIndex == -1) {
			return false;
		}
		var lastDotIndex:Int;
		if (StringTools.endsWith(s, "/..")) {
			lastDotIndex = s.length;
		} else {
			lastDotIndex = s.lastIndexOf("/../");
		}
		return lastDotIndex > wildcardIndex;
	}

	public static function GetTsConfigPropArrayElementValue(tsConfigSourceFile:Null<SourceFile>, propKey:std.String,
			elementValue:std.String):Null<StringLiteral> {
		final callback = GetCallbackForFindingPropertyAssignmentByValue(elementValue);
		return ForEachTsConfigPropArray(tsConfigSourceFile, propKey, function(property:PropertyAssignment):Null<StringLiteral> {
			final value = callback(property);
			if (value != null) {
				return value.AsStringLiteral();
			}
			return null;
		});
	}

	public static function ForEachTsConfigPropArray<T>(tsConfigSourceFile:Null<SourceFile>, propKey:std.String,
			callback:(property:PropertyAssignment) -> Null<T>):Null<T> {
		if (tsConfigSourceFile != null) {
			return ForEachPropertyAssignment(getTsConfigObjectLiteralExpression(tsConfigSourceFile), propKey, callback);
		}
		return null;
	}

	public static function CreateDiagnosticAtReferenceSyntax(config:ParsedCommandLine, index:Int, message:Message, ...args:Any):Null<Diagnostic> {
		final args = args.toArray();
		return ForEachTsConfigPropArray(config.ConfigFile.SourceFile, "references", function(property:PropertyAssignment):Null<Diagnostic> {
			if (Ast.IsArrayLiteralExpression(property.Initializer)) {
				final value = property.Initializer.Elements();
				if (Core.len(value) > index) {
					return CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, value[index], message, ...args);
				}
			}
			return null;
		});
	}

	public static function GetCallbackForFindingPropertyAssignmentByValue(value:std.String):(property:PropertyAssignment) -> Null<Node> {
		return function(property:PropertyAssignment):Null<Node> {
			if (Ast.IsArrayLiteralExpression(property.Initializer)) {
				return Core.Find(property.Initializer.Elements(), function(element:Node):Bool {
					return Ast.IsStringLiteral(element) && element.Text() == value;
				});
			}
			return null;
		};
	}

	public static function GetOptionsSyntaxByArrayElementValue(objectLiteral:Null<ObjectLiteralExpression>, propKey:std.String,
			elementValue:std.String):Null<Node> {
		return ForEachPropertyAssignment(objectLiteral, propKey, GetCallbackForFindingPropertyAssignmentByValue(elementValue));
	}

	public static function ForEachPropertyAssignment<T>(objectLiteral:Null<ObjectLiteralExpression>, key:std.String,
			callback:(property:PropertyAssignment) -> Null<T>, ...key2:std.String):Null<T> {
		if (objectLiteral != null) {
			final properties = objectLiteral.Properties.Nodes;
			for (property in (properties == null ? [] : properties)) {
				if (!Ast.IsPropertyAssignment(property)) {
					continue;
				}
				final r = Ast.TryGetTextOfPropertyName(property.Name());
				if (r.ok) {
					final propName = r.value;
					if (propName == key || (key2.length > 0 && key2[0] == propName)) {
						return callback(property.AsPropertyAssignment());
					}
				}
			}
		}
		return null;
	}

	static function getTsConfigObjectLiteralExpression(tsConfigSourceFile:Null<SourceFile>):Null<ObjectLiteralExpression> {
		if (tsConfigSourceFile != null && tsConfigSourceFile.Statements != null && Core.len(tsConfigSourceFile.Statements.Nodes) > 0) {
			final expression = tsConfigSourceFile.Statements.Nodes[0].Expression();
			if (Ast.IsObjectLiteralExpression(expression)) {
				return expression.AsObjectLiteralExpression();
			}
		}
		return null;
	}

	static function getSubstitutedPathWithConfigDirTemplate(value:std.String, basePath:std.String):std.String {
		// PORT: strings.Replace(value, configDirTemplate, "./", 1)
		final i = value.indexOf(configDirTemplate);
		final replaced = i < 0 ? value : value.substring(0, i) + "./" + value.substring(i + configDirTemplate.length);
		return Tspath.GetNormalizedAbsolutePath(replaced, basePath);
	}

	static function getSubstitutedStringArrayWithConfigDirTemplate(list:Null<Array<std.String>>, basePath:std.String):Null<Array<std.String>> {
		var result:Null<Array<std.String>> = null;
		if (list != null) {
			for (i in 0...list.length) {
				final element = list[i];
				if (startsWithConfigDirTemplate(element)) {
					if (result == null) {
						result = Slices.Clone(list);
					}
					result[i] = getSubstitutedPathWithConfigDirTemplate(element, basePath);
				}
			}
		}
		if (result != null) {
			return result;
		}
		return null;
	}

	static function handleOptionConfigDirTemplateSubstitution(compilerOptions:Null<CompilerOptions>, basePath:std.String):Void {
		if (compilerOptions == null) {
			return;
		}

		// !!! don't hardcode this; use options declarations?

		var paths:Null<OrderedMap<std.String, Array<std.String>>> = null;
		for (k => v in compilerOptions.Paths.Entries()) {
			final substitution = getSubstitutedStringArrayWithConfigDirTemplate(v, basePath);
			if (substitution != null) {
				if (paths == null) {
					paths = compilerOptions.Paths.Clone();
					compilerOptions.Paths = paths;
				}
				paths.Set(k, substitution);
			}
		}

		final rootDirs = getSubstitutedStringArrayWithConfigDirTemplate(compilerOptions.RootDirs, basePath);
		if (rootDirs != null) {
			compilerOptions.RootDirs = rootDirs;
		}
		final typeRoots = getSubstitutedStringArrayWithConfigDirTemplate(compilerOptions.TypeRoots, basePath);
		if (typeRoots != null) {
			compilerOptions.TypeRoots = typeRoots;
		}
		if (startsWithConfigDirTemplate(compilerOptions.GenerateCpuProfile)) {
			compilerOptions.GenerateCpuProfile = getSubstitutedPathWithConfigDirTemplate(compilerOptions.GenerateCpuProfile, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.GenerateTrace)) {
			compilerOptions.GenerateTrace = getSubstitutedPathWithConfigDirTemplate(compilerOptions.GenerateTrace, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.OutFile)) {
			compilerOptions.OutFile = getSubstitutedPathWithConfigDirTemplate(compilerOptions.OutFile, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.OutDir)) {
			compilerOptions.OutDir = getSubstitutedPathWithConfigDirTemplate(compilerOptions.OutDir, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.RootDir)) {
			compilerOptions.RootDir = getSubstitutedPathWithConfigDirTemplate(compilerOptions.RootDir, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.TsBuildInfoFile)) {
			compilerOptions.TsBuildInfoFile = getSubstitutedPathWithConfigDirTemplate(compilerOptions.TsBuildInfoFile, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.BaseUrl)) {
			compilerOptions.BaseUrl = getSubstitutedPathWithConfigDirTemplate(compilerOptions.BaseUrl, basePath);
		}
		if (startsWithConfigDirTemplate(compilerOptions.DeclarationDir)) {
			compilerOptions.DeclarationDir = getSubstitutedPathWithConfigDirTemplate(compilerOptions.DeclarationDir, basePath);
		}
	}

	// hasFileWithHigherPriorityExtension determines whether a literal or wildcard file has already been included that has a higher extension priority.
	// file is the path to the file.
	static function hasFileWithHigherPriorityExtension(file:std.String, extensions:Array<Array<std.String>>, hasFile:(fileName:std.String) -> Bool):Bool {
		var extensionGroup:Null<Array<std.String>> = null;
		for (group in extensions) {
			if (Tspath.FileExtensionIsOneOf(file, group)) {
				extensionGroup = Slices.Concat(extensionGroup, group);
			}
		}
		if (Core.len(extensionGroup) == 0) {
			return false;
		}
		for (ext in extensionGroup) {
			// d.ts files match with .ts extension and with case sensitive sorting the file order for same files with ts tsx and dts extension is
			// d.ts, .ts, .tsx in that order so we need to handle tsx and dts of same same name case here and in remove files with same extensions
			// So dont match .d.ts files with .ts extension
			if (Tspath.FileExtensionIs(file, ext) && (ext != Tspath.ExtensionTs || !Tspath.FileExtensionIs(file, Tspath.ExtensionDts))) {
				return false;
			}
			if (hasFile(Tspath.ChangeExtension(file, ext))) {
				if (ext == Tspath.ExtensionDts && (Tspath.FileExtensionIs(file, Tspath.ExtensionJs) || Tspath.FileExtensionIs(file, Tspath.ExtensionJsx))) {
					// LEGACY BEHAVIOR: An off-by-one bug somewhere in the extension priority system for wildcard module loading allowed declaration
					// files to be loaded alongside their js(x) counterparts. We regard this as generally undesirable, but retain the behavior to
					// prevent breakage.
					continue;
				}
				return true;
			}
		}
		return false;
	}

	// Removes files included via wildcard expansion with a lower extension priority that have already been included.
	// file is the path to the file.
	static function removeWildcardFilesWithLowerPriorityExtension(file:std.String, wildcardFiles:OrderedMap<std.String, std.String>,
			extensions:Array<Array<std.String>>, keyMapper:(value:std.String) -> std.String):Void {
		var extensionGroup:Null<Array<std.String>> = null;
		for (group in extensions) {
			if (Tspath.FileExtensionIsOneOf(file, group)) {
				extensionGroup = Slices.Concat(extensionGroup, group);
			}
		}
		if (extensionGroup == null) {
			return;
		}
		var i = extensionGroup.length - 1;
		while (i >= 0) {
			final ext = extensionGroup[i];
			if (Tspath.FileExtensionIs(file, ext)) {
				return;
			}
			final lowerPriorityPath = keyMapper(Tspath.ChangeExtension(file, ext));
			wildcardFiles.Delete(lowerPriorityPath);
			i--;
		}
	}

	// getFileNamesFromConfigSpecs gets the file names from the provided config file specs that contain, files, include, exclude and
	// other properties needed to resolve the file names
	// configFileSpecs is the config file specs extracted with file names to include, wildcards to include/exclude and other details
	// basePath is the base path for any relative file specifications.
	// options is the Compiler options.
	// host is the host used to resolve files and directories.
	// extraFileExtensions optionally file extra file extension information from host
	static function getFileNamesFromConfigSpecs(configFileSpecs:ConfigFileSpecs, basePath:std.String, // considering this is the current directory
			options:CompilerOptions, host:FS, extraFileExtensions:Null<Array<FileExtensionInfo>>):Pair<Array<std.String>, Int> {
		extraFileExtensions = [];
		basePath = Tspath.NormalizePath(basePath);
		final keyMappper = function(value:std.String):std.String {
			return Tspath.GetCanonicalFileName(value, host.UseCaseSensitiveFileNames());
		};
		// Literal file names (provided via the "files" array in tsconfig.json) are stored in a
		// file map with a possibly case insensitive key. We use this map later when when including
		// wildcard paths.
		final literalFileMap = new OrderedMap<std.String, std.String>("");
		// Wildcard paths (provided via the "includes" array in tsconfig.json) are stored in a
		// file map with a possibly case insensitive key. We use this map to store paths matched
		// via wildcard, and to handle extension priority.
		final wildcardFileMap = new OrderedMap<std.String, std.String>("");
		// Wildcard paths of json files (provided via the "includes" array in tsconfig.json) are stored in a
		// file map with a possibly case insensitive key. We use this map to store paths matched
		// via wildcard of *.json kind
		final wildCardJsonFileMap = new OrderedMap<std.String, std.String>("");
		final validatedFilesSpec = configFileSpecs.validatedFilesSpec;
		final validatedIncludeSpecs = configFileSpecs.validatedIncludeSpecs;
		final validatedExcludeSpecs = configFileSpecs.validatedExcludeSpecs;
		// Rather than re-query this for each file and filespec, we query the supported extensions
		// once and store it on the expansion context.
		final supportedExtensions = GetSupportedExtensions(options, extraFileExtensions);
		final supportedExtensionsWithJsonIfResolveJsonModule = GetSupportedExtensionsWithJsonIfResolveJsonModule(options, supportedExtensions);
		// Literal files are always included verbatim. An "include" or "exclude" specification cannot
		// remove a literal file.
		if (validatedFilesSpec != null) {
			for (fileName in validatedFilesSpec) {
				final file = Tspath.GetNormalizedAbsolutePath(fileName, basePath);
				literalFileMap.Set(keyMappper(fileName), file);
			}
		}

		var jsonOnlyIncludeMatchers:Null<SpecMatcher> = null;
		if (Core.len(validatedIncludeSpecs) > 0) {
			final files = Vfsmatch.ReadDirectory(host, basePath, basePath, Core.Flatten(supportedExtensionsWithJsonIfResolveJsonModule), validatedExcludeSpecs,
				validatedIncludeSpecs, Vfsmatch.UnlimitedDepth);
			if (files != null) {
				for (file in files) {
					if (Tspath.FileExtensionIs(file, Tspath.ExtensionJson)) {
						if (jsonOnlyIncludeMatchers == null) {
							final includes = Core.Filter(validatedIncludeSpecs, function(include:std.String):Bool {
								return StringTools.endsWith(include, Tspath.ExtensionJson);
							});
							jsonOnlyIncludeMatchers = Vfsmatch.NewSpecMatcher(includes, basePath, UsageFiles, host.UseCaseSensitiveFileNames());
						}
						var includeIndex:Int = -1;
						if (jsonOnlyIncludeMatchers != null) {
							includeIndex = jsonOnlyIncludeMatchers.MatchIndex(file);
						}
						if (includeIndex != -1) {
							final key = keyMappper(file);
							if (!literalFileMap.Has(key) && !wildCardJsonFileMap.Has(key)) {
								wildCardJsonFileMap.Set(key, file);
							}
						}
						continue;
					}
					// If we have already included a literal or wildcard path with a
					// higher priority extension, we should skip this file.
					//
					// This handles cases where we may encounter both <file>.ts and
					// <file>.d.ts (or <file>.js if "allowJs" is enabled) in the same
					// directory when they are compilation outputs.
					if (hasFileWithHigherPriorityExtension(file, supportedExtensions, function(fileName:std.String):Bool {
						final canonicalFileName = keyMappper(fileName);
						return literalFileMap.Has(canonicalFileName) || wildcardFileMap.Has(canonicalFileName);
					})) {
						continue;
					}
					// We may have included a wildcard path with a lower priority
					// extension due to the user-defined order of entries in the
					// "include" array. If there is a lower priority extension in the
					// same directory, we should remove it.
					removeWildcardFilesWithLowerPriorityExtension(file, wildcardFileMap, supportedExtensions, keyMappper);
					final key = keyMappper(file);
					if (!literalFileMap.Has(key) && !wildcardFileMap.Has(key)) {
						wildcardFileMap.Set(key, file);
					}
				}
			}
		}
		final files:Array<std.String> = [];
		for (file in literalFileMap.Values()) {
			files.push(file);
		}
		for (file in wildcardFileMap.Values()) {
			files.push(file);
		}
		for (file in wildCardJsonFileMap.Values()) {
			files.push(file);
		}
		return new Pair<Array<std.String>, Int>(files, literalFileMap.Size());
	}

	public static function GetSupportedExtensions(compilerOptions:CompilerOptions, extraFileExtensions:Null<Array<FileExtensionInfo>>):Array<Array<std.String>> {
		final needJSExtensions = compilerOptions.GetAllowJS();
		if (Core.len(extraFileExtensions) == 0) {
			if (needJSExtensions) {
				return Tspath.AllSupportedExtensions;
			} else {
				return Tspath.SupportedTSExtensions;
			}
		}
		var builtins:Array<Array<std.String>>;
		if (needJSExtensions) {
			builtins = Tspath.AllSupportedExtensions;
		} else {
			builtins = Tspath.SupportedTSExtensions;
		}
		final flatBuiltins = Core.Flatten(builtins);
		var result:Null<Array<Array<std.String>>> = null;
		for (x in extraFileExtensions) {
			if (x.ScriptKind == ScriptKindDeferred
				|| (needJSExtensions && (x.ScriptKind == ScriptKindJS || x.ScriptKind == ScriptKindJSX)) && !Slices.Contains(flatBuiltins, x.Extension)) {
				if (result == null)
					result = [];
				result.push([x.Extension]);
			}
		}
		final extensions = Slices.Concat(builtins, result);
		return extensions;
	}

	public static function GetSupportedExtensionsWithJsonIfResolveJsonModule(compilerOptions:Null<CompilerOptions>,
			supportedExtensions:Array<Array<std.String>>):Array<Array<std.String>> {
		if (compilerOptions == null || !compilerOptions.GetResolveJsonModule()) {
			return supportedExtensions;
		}
		if (Core.Same(supportedExtensions, Tspath.AllSupportedExtensions)) {
			return Tspath.AllSupportedExtensionsWithJson;
		}
		if (Core.Same(supportedExtensions, Tspath.SupportedTSExtensions)) {
			return Tspath.SupportedTSExtensionsWithJson;
		}
		return Slices.Concat(supportedExtensions, [[Tspath.ExtensionJson]]);
	}

	// Reads the config file and reports errors.
	// PORT: (*ParsedCommandLine, []*ast.Diagnostic) → Pair.
	public static function GetParsedCommandLineOfConfigFile(configFileName:std.String, options:Null<CompilerOptions>,
			optionsRaw:Null<OrderedMap<std.String, Dynamic>>, sys:ParseConfigHost,
			extendedConfigCache:Null<ExtendedConfigCache>):Pair<Null<ParsedCommandLine>, Null<Array<Diagnostic>>> {
		configFileName = Tspath.GetNormalizedAbsolutePath(configFileName, sys.GetCurrentDirectory());
		return GetParsedCommandLineOfConfigFilePath(configFileName, Tspath.ToPath(configFileName, sys.GetCurrentDirectory(), sys.FS().UseCaseSensitiveFileNames()),
			options, optionsRaw, sys, extendedConfigCache);
	}

	public static function GetParsedCommandLineOfConfigFilePath(configFileName:std.String, path:Path, options:Null<CompilerOptions>,
			optionsRaw:Null<OrderedMap<std.String, Dynamic>>, sys:ParseConfigHost,
			extendedConfigCache:Null<ExtendedConfigCache>):Pair<Null<ParsedCommandLine>, Null<Array<Diagnostic>>> {
		var errors:Null<Array<Diagnostic>> = [];
		final fs = sys.FS();
		final r = tryReadFile(configFileName, fs.ReadFile, errors);
		final configFileText = r.a;
		errors = r.b;
		if (Core.len(errors) > 0) {
			// these are unrecoverable errors--exit to report them as diagnostics
			return new Pair<Null<ParsedCommandLine>, Null<Array<Diagnostic>>>(null, errors);
		}

		final tsConfigSourceFile = NewTsconfigSourceFileFromFilePath(configFileName, path, configFileText);
		// tsConfigSourceFile.resolvedPath = tsConfigSourceFile.FileName()
		// tsConfigSourceFile.originalFileName = tsConfigSourceFile.FileName()
		return new Pair<Null<ParsedCommandLine>, Null<Array<Diagnostic>>>(ParseJsonSourceFileConfigFileContent(tsConfigSourceFile, sys,
			Tspath.GetDirectoryPath(configFileName), options, optionsRaw, configFileName, null, null, extendedConfigCache), null);
	}

	// --- wildcarddirectories.go ---

	// PORT: map[string]bool → StringMap<Bool> (Go map iteration order is random; the result does
	// not depend on it).
	static function getWildcardDirectories(include:Null<Array<std.String>>, exclude:Null<Array<std.String>>,
			comparePathsOptions:ComparePathsOptions):Null<StringMap<Bool>> {
		// We watch a directory recursively if it contains a wildcard anywhere in a directory segment
		// of the pattern:
		//
		//  /a/b/**/d   - Watch /a/b recursively to catch changes to any d in any subfolder recursively
		//  /a/b/*/d    - Watch /a/b recursively to catch any d in any immediate subfolder, even if a new subfolder is added
		//  /a/b        - Watch /a/b recursively to catch changes to anything in any recursive subfoler
		//
		// We watch a directory without recursion if it contains a wildcard in the file segment of
		// the pattern:
		//
		//  /a/b/*      - Watch /a/b directly to catch any new file
		//  /a/b/a?z    - Watch /a/b directly to catch any new file matching a?z

		if (Core.len(include) == 0) {
			return null;
		}

		final excludeMatcher = Vfsmatch.NewSpecMatcher(exclude, comparePathsOptions.CurrentDirectory, UsageExclude,
			comparePathsOptions.UseCaseSensitiveFileNames);

		final wildcardDirectories = new StringMap<Bool>();
		final wildCardKeyToPath = new StringMap<std.String>();

		var recursiveKeys:Null<Array<std.String>> = null;

		for (file in include) {
			final spec = Tspath.NormalizePath(Tspath.CombinePaths(comparePathsOptions.CurrentDirectory, file));
			if (excludeMatcher != null && excludeMatcher.MatchString(spec)) {
				continue;
			}

			final match = getWildcardDirectoryFromSpec(spec, comparePathsOptions.UseCaseSensitiveFileNames);
			if (match != null) {
				final key = match.Key;
				final path = match.Path;
				final recursive = match.Recursive;

				final existsPath = wildCardKeyToPath.exists(key);
				final existingPath = existsPath ? wildCardKeyToPath.get(key) : "";
				var existingRecursive = false;

				if (existsPath) {
					existingRecursive = wildcardDirectories.get(existingPath) == true;
				}

				if (!existsPath || (!existingRecursive && recursive)) {
					var pathToUse = path;
					if (existsPath) {
						pathToUse = existingPath;
					}
					wildcardDirectories.set(pathToUse, recursive);

					if (!existsPath) {
						wildCardKeyToPath.set(key, path);
					}

					if (recursive) {
						if (recursiveKeys == null)
							recursiveKeys = [];
						recursiveKeys.push(key);
					}
				}
			}

			// Remove any subpaths under an existing recursively watched directory
			// PORT: Go deletes while ranging over the map; the keys are snapshotted first (the
			// result does not depend on the iteration order).
			final paths = [for (p in wildcardDirectories.keys()) p];
			for (path in paths) {
				if (recursiveKeys != null) {
					for (recursiveKey in recursiveKeys) {
						final key = toCanonicalKey(path, comparePathsOptions.UseCaseSensitiveFileNames);
						if (key != recursiveKey && Tspath.ContainsPath(recursiveKey, key, comparePathsOptions)) {
							wildcardDirectories.remove(path);
						}
					}
				}
			}
		}

		return wildcardDirectories;
	}

	static function toCanonicalKey(path:std.String, useCaseSensitiveFileNames:Bool):std.String {
		if (useCaseSensitiveFileNames) {
			return path;
		}
		return Strings.ToLower(path);
	}

	static function getWildcardDirectoryFromSpec(spec:std.String, useCaseSensitiveFileNames:Bool):Null<WildcardDirectoryMatch> {
		// Find the first occurrence of a wildcard character
		final firstWildcard = Strings.IndexAny(spec, "*?");
		if (firstWildcard != -1) {
			// Find the last directory separator before the wildcard
			final lastSepBeforeWildcard = spec.substring(0, firstWildcard).lastIndexOf("/");
			if (lastSepBeforeWildcard != -1) {
				final path = spec.substring(0, lastSepBeforeWildcard);
				final lastDirectorySeparatorIndex = spec.lastIndexOf("/");

				// Determine if this should be watched recursively:
				// recursive if the wildcard appears in a directory segment (not just the final file segment)
				final recursive = firstWildcard < lastDirectorySeparatorIndex;

				return new WildcardDirectoryMatch(toCanonicalKey(path, useCaseSensitiveFileNames), path, recursive);
			}
		}

		final lastSepIndex = spec.lastIndexOf("/");
		if (lastSepIndex != -1) {
			final lastSegment = spec.substring(lastSepIndex + 1);
			if (Vfsmatch.IsImplicitGlob(lastSegment)) {
				final path = Tspath.RemoveTrailingDirectorySeparator(spec);
				return new WildcardDirectoryMatch(toCanonicalKey(path, useCaseSensitiveFileNames), path, true);
			}
		}

		return null;
	}

	// --- PORT: reflection over core.CompilerOptions ---

	// The exported fields of core.CompilerOptions in Go declaration order, with their json names.
	// Go code that walks the struct with reflect (mergeCompilerOptions, serializeCompilerOptions,
	// ForEachCompilerOptionValue) walks this table; values are read and written with
	// Reflect.field / Reflect.setField on the exact Go field names.
	static var compilerOptionsFields(get, never):Array<CompilerOptionsField>;
	static var _compilerOptionsFields:Array<CompilerOptionsField> = null;

	static function get_compilerOptionsFields():Array<CompilerOptionsField> {
		if (_compilerOptionsFields == null) {
			_compilerOptionsFields = [
			new CompilerOptionsField("AllowJs", "allowJs", FieldTristate),
			new CompilerOptionsField("AllowArbitraryExtensions", "allowArbitraryExtensions", FieldTristate),
			new CompilerOptionsField("AllowImportingTsExtensions", "allowImportingTsExtensions", FieldTristate),
			new CompilerOptionsField("AllowNonTsExtensions", "allowNonTsExtensions", FieldTristate),
			new CompilerOptionsField("AllowUmdGlobalAccess", "allowUmdGlobalAccess", FieldTristate),
			new CompilerOptionsField("AllowUnreachableCode", "allowUnreachableCode", FieldTristate),
			new CompilerOptionsField("AllowUnusedLabels", "allowUnusedLabels", FieldTristate),
			new CompilerOptionsField("AssumeChangesOnlyAffectDirectDependencies", "assumeChangesOnlyAffectDirectDependencies", FieldTristate),
			new CompilerOptionsField("CheckJs", "checkJs", FieldTristate),
			new CompilerOptionsField("CustomConditions", "customConditions", FieldStrings),
			new CompilerOptionsField("Composite", "composite", FieldTristate),
			new CompilerOptionsField("EmitDeclarationOnly", "emitDeclarationOnly", FieldTristate),
			new CompilerOptionsField("EmitBOM", "emitBOM", FieldTristate),
			new CompilerOptionsField("EmitDecoratorMetadata", "emitDecoratorMetadata", FieldTristate),
			new CompilerOptionsField("Declaration", "declaration", FieldTristate),
			new CompilerOptionsField("DeclarationDir", "declarationDir", FieldString),
			new CompilerOptionsField("DeclarationMap", "declarationMap", FieldTristate),
			new CompilerOptionsField("DeduplicatePackages", "deduplicatePackages", FieldTristate),
			new CompilerOptionsField("DisableSizeLimit", "disableSizeLimit", FieldTristate),
			new CompilerOptionsField("DisableSourceOfProjectReferenceRedirect", "disableSourceOfProjectReferenceRedirect", FieldTristate),
			new CompilerOptionsField("DisableSolutionSearching", "disableSolutionSearching", FieldTristate),
			new CompilerOptionsField("DisableReferencedProjectLoad", "disableReferencedProjectLoad", FieldTristate),
			new CompilerOptionsField("ErasableSyntaxOnly", "erasableSyntaxOnly", FieldTristate),
			new CompilerOptionsField("ExactOptionalPropertyTypes", "exactOptionalPropertyTypes", FieldTristate),
			new CompilerOptionsField("ExperimentalDecorators", "experimentalDecorators", FieldTristate),
			new CompilerOptionsField("ForceConsistentCasingInFileNames", "forceConsistentCasingInFileNames", FieldTristate),
			new CompilerOptionsField("IsolatedModules", "isolatedModules", FieldTristate),
			new CompilerOptionsField("IsolatedDeclarations", "isolatedDeclarations", FieldTristate),
			new CompilerOptionsField("IgnoreConfig", "ignoreConfig", FieldTristate),
			new CompilerOptionsField("IgnoreDeprecations", "ignoreDeprecations", FieldString),
			new CompilerOptionsField("ImportHelpers", "importHelpers", FieldTristate),
			new CompilerOptionsField("InlineSourceMap", "inlineSourceMap", FieldTristate),
			new CompilerOptionsField("InlineSources", "inlineSources", FieldTristate),
			new CompilerOptionsField("Init", "init", FieldTristate),
			new CompilerOptionsField("Incremental", "incremental", FieldTristate),
			new CompilerOptionsField("Jsx", "jsx", FieldEnum),
			new CompilerOptionsField("JsxFactory", "jsxFactory", FieldString),
			new CompilerOptionsField("JsxFragmentFactory", "jsxFragmentFactory", FieldString),
			new CompilerOptionsField("JsxImportSource", "jsxImportSource", FieldString),
			new CompilerOptionsField("Lib", "lib", FieldStrings),
			new CompilerOptionsField("LibReplacement", "libReplacement", FieldTristate),
			new CompilerOptionsField("Locale", "locale", FieldString),
			new CompilerOptionsField("MapRoot", "mapRoot", FieldString),
			new CompilerOptionsField("Module", "module", FieldEnum),
			new CompilerOptionsField("ModuleResolution", "moduleResolution", FieldEnum),
			new CompilerOptionsField("ModuleSuffixes", "moduleSuffixes", FieldStrings),
			new CompilerOptionsField("ModuleDetection", "moduleDetection", FieldEnum),
			new CompilerOptionsField("NewLine", "newLine", FieldEnum),
			new CompilerOptionsField("NoEmit", "noEmit", FieldTristate),
			new CompilerOptionsField("NoCheck", "noCheck", FieldTristate),
			new CompilerOptionsField("NoErrorTruncation", "noErrorTruncation", FieldTristate),
			new CompilerOptionsField("NoFallthroughCasesInSwitch", "noFallthroughCasesInSwitch", FieldTristate),
			new CompilerOptionsField("NoImplicitAny", "noImplicitAny", FieldTristate),
			new CompilerOptionsField("NoImplicitThis", "noImplicitThis", FieldTristate),
			new CompilerOptionsField("NoImplicitReturns", "noImplicitReturns", FieldTristate),
			new CompilerOptionsField("NoEmitHelpers", "noEmitHelpers", FieldTristate),
			new CompilerOptionsField("NoLib", "noLib", FieldTristate),
			new CompilerOptionsField("NoPropertyAccessFromIndexSignature", "noPropertyAccessFromIndexSignature", FieldTristate),
			new CompilerOptionsField("NoUncheckedIndexedAccess", "noUncheckedIndexedAccess", FieldTristate),
			new CompilerOptionsField("NoEmitOnError", "noEmitOnError", FieldTristate),
			new CompilerOptionsField("NoUnusedLocals", "noUnusedLocals", FieldTristate),
			new CompilerOptionsField("NoUnusedParameters", "noUnusedParameters", FieldTristate),
			new CompilerOptionsField("NoResolve", "noResolve", FieldTristate),
			new CompilerOptionsField("NoImplicitOverride", "noImplicitOverride", FieldTristate),
			new CompilerOptionsField("NoUncheckedSideEffectImports", "noUncheckedSideEffectImports", FieldTristate),
			new CompilerOptionsField("OutDir", "outDir", FieldString),
			new CompilerOptionsField("Paths", "paths", FieldPaths),
			new CompilerOptionsField("PreserveConstEnums", "preserveConstEnums", FieldTristate),
			new CompilerOptionsField("PreserveSymlinks", "preserveSymlinks", FieldTristate),
			new CompilerOptionsField("Project", "project", FieldString),
			new CompilerOptionsField("ResolveJsonModule", "resolveJsonModule", FieldTristate),
			new CompilerOptionsField("ResolvePackageJsonExports", "resolvePackageJsonExports", FieldTristate),
			new CompilerOptionsField("ResolvePackageJsonImports", "resolvePackageJsonImports", FieldTristate),
			new CompilerOptionsField("RemoveComments", "removeComments", FieldTristate),
			new CompilerOptionsField("RewriteRelativeImportExtensions", "rewriteRelativeImportExtensions", FieldTristate),
			new CompilerOptionsField("ReactNamespace", "reactNamespace", FieldString),
			new CompilerOptionsField("RootDir", "rootDir", FieldString),
			new CompilerOptionsField("RootDirs", "rootDirs", FieldStrings),
			new CompilerOptionsField("SkipLibCheck", "skipLibCheck", FieldTristate),
			new CompilerOptionsField("StableTypeOrdering", "stableTypeOrdering", FieldTristate),
			new CompilerOptionsField("Strict", "strict", FieldTristate),
			new CompilerOptionsField("StrictBindCallApply", "strictBindCallApply", FieldTristate),
			new CompilerOptionsField("StrictBuiltinIteratorReturn", "strictBuiltinIteratorReturn", FieldTristate),
			new CompilerOptionsField("StrictFunctionTypes", "strictFunctionTypes", FieldTristate),
			new CompilerOptionsField("StrictNullChecks", "strictNullChecks", FieldTristate),
			new CompilerOptionsField("StrictPropertyInitialization", "strictPropertyInitialization", FieldTristate),
			new CompilerOptionsField("StripInternal", "stripInternal", FieldTristate),
			new CompilerOptionsField("SkipDefaultLibCheck", "skipDefaultLibCheck", FieldTristate),
			new CompilerOptionsField("SourceMap", "sourceMap", FieldTristate),
			new CompilerOptionsField("SourceRoot", "sourceRoot", FieldString),
			new CompilerOptionsField("SuppressOutputPathCheck", "suppressOutputPathCheck", FieldTristate),
			new CompilerOptionsField("Target", "target", FieldEnum),
			new CompilerOptionsField("TraceResolution", "traceResolution", FieldTristate),
			new CompilerOptionsField("TsBuildInfoFile", "tsBuildInfoFile", FieldString),
			new CompilerOptionsField("TypeRoots", "typeRoots", FieldStrings),
			new CompilerOptionsField("Types", "types", FieldStrings),
			new CompilerOptionsField("UseDefineForClassFields", "useDefineForClassFields", FieldTristate),
			new CompilerOptionsField("UseUnknownInCatchVariables", "useUnknownInCatchVariables", FieldTristate),
			new CompilerOptionsField("VerbatimModuleSyntax", "verbatimModuleSyntax", FieldTristate),
			new CompilerOptionsField("MaxNodeModuleJsDepth", "maxNodeModuleJsDepth", FieldIntPtr),
			new CompilerOptionsField("AllowSyntheticDefaultImports", "allowSyntheticDefaultImports", FieldTristate),
			new CompilerOptionsField("AlwaysStrict", "alwaysStrict", FieldTristate),
			new CompilerOptionsField("BaseUrl", "baseUrl", FieldString),
			new CompilerOptionsField("DownlevelIteration", "downlevelIteration", FieldTristate),
			new CompilerOptionsField("ESModuleInterop", "esModuleInterop", FieldTristate),
			new CompilerOptionsField("OutFile", "outFile", FieldString),
			new CompilerOptionsField("ConfigFilePath", "configFilePath", FieldString),
			new CompilerOptionsField("NoDtsResolution", "noDtsResolution", FieldTristate),
			new CompilerOptionsField("PathsBasePath", "pathsBasePath", FieldString),
			new CompilerOptionsField("Diagnostics", "diagnostics", FieldTristate),
			new CompilerOptionsField("ExtendedDiagnostics", "extendedDiagnostics", FieldTristate),
			new CompilerOptionsField("GenerateCpuProfile", "generateCpuProfile", FieldString),
			new CompilerOptionsField("GenerateTrace", "generateTrace", FieldString),
			new CompilerOptionsField("ListEmittedFiles", "listEmittedFiles", FieldTristate),
			new CompilerOptionsField("ListFiles", "listFiles", FieldTristate),
			new CompilerOptionsField("ExplainFiles", "explainFiles", FieldTristate),
			new CompilerOptionsField("ListFilesOnly", "listFilesOnly", FieldTristate),
			new CompilerOptionsField("NoEmitForJsFiles", "noEmitForJsFiles", FieldTristate),
			new CompilerOptionsField("PreserveWatchOutput", "preserveWatchOutput", FieldTristate),
			new CompilerOptionsField("Pretty", "pretty", FieldTristate),
			new CompilerOptionsField("Version", "version", FieldTristate),
			new CompilerOptionsField("Watch", "watch", FieldTristate),
			new CompilerOptionsField("ShowConfig", "showConfig", FieldTristate),
			new CompilerOptionsField("Build", "build", FieldTristate),
			new CompilerOptionsField("Help", "help", FieldTristate),
			new CompilerOptionsField("All", "all", FieldTristate),
			new CompilerOptionsField("PprofDir", "pprofDir", FieldString),
			new CompilerOptionsField("SingleThreaded", "singleThreaded", FieldTristate),
			new CompilerOptionsField("Quiet", "quiet", FieldTristate),
			new CompilerOptionsField("Checkers", "checkers", FieldIntPtr),
			];
		}
		return _compilerOptionsFields;
	}
}

// PORT: Go field type of a core.CompilerOptions field (see compilerOptionsFields).
enum abstract CompilerOptionsFieldKind(Int) {
	var FieldTristate = 0; // core.Tristate
	var FieldString = 1; // string
	var FieldStrings = 2; // []string
	var FieldEnum = 3; // int32 enums (ModuleKind, ...)
	var FieldIntPtr = 4; // *int
	var FieldPaths = 5; // *collections.OrderedMap[string, []string]
}

// PORT: one exported field of core.CompilerOptions (Go reflect.StructField + reflect.Value access).
@:allow(ts.tsoptions)
class CompilerOptionsField {
	public final Name:std.String; // Go field name
	public final JsonName:std.String; // json tag name
	public final Kind:CompilerOptionsFieldKind;

	public function new(Name:std.String, JsonName:std.String, Kind:CompilerOptionsFieldKind) {
		this.Name = Name;
		this.JsonName = JsonName;
		this.Kind = Kind;
	}

	public function Get(o:CompilerOptions):Dynamic {
		return Reflect.field(o, this.Name);
	}

	public function Set(o:CompilerOptions, v:Dynamic):Void {
		Reflect.setField(o, this.Name, v);
	}

	// Go reflect.Zero(field.Type)
	public function Zero():Dynamic {
		switch (this.Kind) {
			case FieldTristate, FieldEnum:
				return 0;
			case FieldString:
				return "";
			default:
				return null;
		}
	}

	// Go reflect.Value.IsZero
	public function IsZero(v:Dynamic):Bool {
		switch (this.Kind) {
			case FieldTristate, FieldEnum:
				return v == null || (v : Int) == 0;
			case FieldString:
				return v == null || (v : std.String) == "";
			default:
				return v == null;
		}
	}

	// Go reflect.DeepEqual of two values of this field.
	public function DeepEqual(a:Dynamic, b:Dynamic):Bool {
		switch (this.Kind) {
			case FieldStrings:
				if (a == null || b == null) {
					return a == null && b == null;
				}
				final sa:Array<std.String> = a;
				final sb:Array<std.String> = b;
				if (sa.length != sb.length) {
					return false;
				}
				for (i in 0...sa.length) {
					if (sa[i] != sb[i]) {
						return false;
					}
				}
				return true;
			case FieldPaths:
				if (a == null || b == null) {
					return a == null && b == null;
				}
				final ma:OrderedMap<std.String, Array<std.String>> = a;
				final mb:OrderedMap<std.String, Array<std.String>> = b;
				if (ma.Size() != mb.Size()) {
					return false;
				}
				final ka = Slices.Collect(ma.Keys());
				final kb = Slices.Collect(mb.Keys());
				final strings = new CompilerOptionsField("", "", FieldStrings);
				if (!strings.DeepEqual(ka, kb)) {
					return false;
				}
				for (k => va in ma.Entries()) {
					if (!strings.DeepEqual(va, mb.GetOrZero(k))) {
						return false;
					}
				}
				return true;
			default:
				return a == b;
		}
	}
}
