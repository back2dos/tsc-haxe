package ts.testutil.harnessutil;

import go.Testing.T;
import ts.diagnostics.Diagnostics.Message;

// Port of internal/testutil/harnessutil/harnessutil.go: the package-level funcs and vars (and
// NewOutputRecorderFS of recorderfs.go) are statics of this class; the types follow below.
// sourcemap_recorder.go: types in SourcemapRecorder.hx.
class Harnessutil {
	// Posix-style path to additional test libraries
	static inline final testLibFolder = "/.lib";

	public static inline final FakeTSVersion = "FakeTSVersion";

	// PORT: gate-only addition (not in Go). When true, an exception thrown by Program.Emit in
	// compileFilesWithHost is caught: the emit result is empty and the message is kept in
	// LastEmitCrash. Used by the checker gate while the transformers are unported.
	public static var TolerateEmitCrash:Bool = false;
	public static var LastEmitCrash:Null<String> = null;

	public static function CompileFiles(t:T, inputFiles:Array<TestFile>, otherFiles:Array<TestFile>, testConfig:TestConfiguration,
			tsconfig:ParsedCommandLine, currentDirectory:String, symlinks:StringMap<String>):CompilationResult {
		var compilerOptions:CompilerOptions = null;
		if (tsconfig != null) {
			compilerOptions = tsconfig.ParsedConfig.CompilerOptions.Clone();
		}
		if (compilerOptions == null) {
			compilerOptions = new CompilerOptions();
		}
		// Set default options for tests
		if (compilerOptions.NewLine == NewLineKindNone) {
			compilerOptions.NewLine = NewLineKindCRLF;
		}
		if (compilerOptions.SkipDefaultLibCheck == TSUnknown) {
			compilerOptions.SkipDefaultLibCheck = TSTrue;
		}
		compilerOptions.NoErrorTruncation = TSTrue;
		final harnessOptions = new HarnessOptions();
		harnessOptions.UseCaseSensitiveFileNames = true;
		harnessOptions.CurrentDirectory = currentDirectory;

		// Parse harness and compiler options from the test configuration
		if (testConfig != null) {
			SetOptionsFromTestConfig(t, testConfig, compilerOptions, harnessOptions, currentDirectory, false /*allowUnknownOptions*/);
		}

		return CompileFilesEx(t, inputFiles, otherFiles, harnessOptions, compilerOptions, currentDirectory, symlinks, tsconfig);
	}

	public static function CompileFilesEx(t:T, inputFiles:Array<TestFile>, otherFiles:Array<TestFile>, harnessOptions:HarnessOptions,
			compilerOptions:CompilerOptions, currentDirectory:String, symlinks:StringMap<String>, tsconfig:ParsedCommandLine):CompilationResult {
		var programFileNames:Array<String> = null;
		for (file in inputFiles) {
			final fileName = Tspath.GetNormalizedAbsolutePath(file.UnitName, currentDirectory);

			if (!Tspath.FileExtensionIs(fileName, Tspath.ExtensionJson) && !Tspath.FileExtensionIs(fileName, Tspath.ExtensionTsBuildInfo)) {
				if (programFileNames == null)
					programFileNames = [];
				programFileNames.push(fileName);
			}
		}

		// !!! Note: lib files are not going to be in `built/local`.
		// In addition, not all files that used to be in `built/local` are going to exist.
		// Files from built\local that are requested by test "@includeBuiltFiles" to be in the context.
		// Treat them as library files, so include them in build, but not in baselines.
		// if harnessOptions.includeBuiltFile != "" {
		// 	programFileNames = append(programFileNames, tspath.CombinePaths(builtFolder, harnessOptions.includeBuiltFile))
		// }

		// Performance optimization; avoid copying in the /.lib folder if the test doesn't need it.
		var includeLibDir = Core.Some(inputFiles, function(file:TestFile) return file.Content.indexOf(testLibFolder + "/") >= 0);

		// Files from testdata\lib that are requested by "@libFiles"
		if (Core.len(harnessOptions.LibFiles) > 0) {
			for (libFile in harnessOptions.LibFiles) {
				if (libFile == "lib.d.ts" && compilerOptions.NoLib != TSTrue) {
					// We used to override lib with a custom lib.d.ts for some reason. Skip this unless it becomes necessary.
					continue;
				}
				if (programFileNames == null)
					programFileNames = [];
				programFileNames.push(Tspath.CombinePaths(testLibFolder, libFile));
				includeLibDir = true;
			}
		}

		if (includeLibDir) {
			// repo.SkipIfNoTypeScriptSubmodule(t)
		}

		// !!!
		// ts.assign(options, ts.convertToOptionsWithAbsolutePaths(options, path => ts.getNormalizedAbsolutePath(path, currentDirectory)));
		if (compilerOptions.OutDir != "") {
			compilerOptions.OutDir = Tspath.GetNormalizedAbsolutePath(compilerOptions.OutDir, currentDirectory);
		}
		if (compilerOptions.Project != "") {
			compilerOptions.Project = Tspath.GetNormalizedAbsolutePath(compilerOptions.Project, currentDirectory);
		}
		if (compilerOptions.RootDir != "") {
			compilerOptions.RootDir = Tspath.GetNormalizedAbsolutePath(compilerOptions.RootDir, currentDirectory);
		}
		if (compilerOptions.TsBuildInfoFile != "") {
			compilerOptions.TsBuildInfoFile = Tspath.GetNormalizedAbsolutePath(compilerOptions.TsBuildInfoFile, currentDirectory);
		}
		if (compilerOptions.BaseUrl != "") {
			compilerOptions.BaseUrl = Tspath.GetNormalizedAbsolutePath(compilerOptions.BaseUrl, currentDirectory);
		}
		if (compilerOptions.DeclarationDir != "") {
			compilerOptions.DeclarationDir = Tspath.GetNormalizedAbsolutePath(compilerOptions.DeclarationDir, currentDirectory);
		}
		if (compilerOptions.RootDirs != null) {
			for (i in 0...compilerOptions.RootDirs.length) {
				compilerOptions.RootDirs[i] = Tspath.GetNormalizedAbsolutePath(compilerOptions.RootDirs[i], currentDirectory);
			}
		}
		if (compilerOptions.TypeRoots != null) {
			for (i in 0...compilerOptions.TypeRoots.length) {
				compilerOptions.TypeRoots[i] = Tspath.GetNormalizedAbsolutePath(compilerOptions.TypeRoots[i], currentDirectory);
			}
		}

		// Create fake FS for testing
		final testfs = new Map<String, MapFile>();
		for (file in inputFiles) {
			final fileName = Tspath.GetNormalizedAbsolutePath(file.UnitName, currentDirectory);
			testfs.set(fileName, new MapFile(go.Utf8.StringToBytes(file.Content)));
		}
		for (file in otherFiles) {
			final fileName = Tspath.GetNormalizedAbsolutePath(file.UnitName, currentDirectory);
			testfs.set(fileName, new MapFile(go.Utf8.StringToBytes(file.Content)));
		}
		if (symlinks != null) {
			for (src => target in symlinks) {
				final srcFileName = Tspath.GetNormalizedAbsolutePath(src, currentDirectory);
				final targetFileName = Tspath.GetNormalizedAbsolutePath(target, currentDirectory);
				testfs.set(srcFileName, Vfstest.Symlink(targetFileName));
			}
		}

		if (includeLibDir) {
			for (k => v in testLibFolderMap()) {
				testfs.set(k, v);
			}
		}

		var fs = Vfstest.FromMap(testfs, harnessOptions.UseCaseSensitiveFileNames);
		fs = Bundled.WrapFS(fs);
		fs = NewOutputRecorderFS(fs);

		final host = createCompilerHost(fs, Bundled.LibPath(), currentDirectory);
		var configFile:TsConfigSourceFile = null;
		var errors:Array<Diagnostic> = null;
		if (tsconfig != null) {
			configFile = tsconfig.ConfigFile;
			errors = tsconfig.Errors;
		}
		final config = new ParsedCommandLine();
		config.ParsedConfig = new ParsedOptions();
		config.ParsedConfig.CompilerOptions = compilerOptions;
		config.ParsedConfig.FileNames = programFileNames;
		config.ConfigFile = configFile;
		config.Errors = errors;
		final result = compileFilesWithHost(host, config, harnessOptions);
		result.Symlinks = symlinks;
		result.Trace = host.tracer.String();
		result.Repeat = function(testConfig:TestConfiguration):CompilationResult {
			final newHarnessOptions = harnessOptions.copy();
			final newCompilerOptions = compilerOptions.Clone();
			SetOptionsFromTestConfig(t, testConfig, newCompilerOptions, newHarnessOptions, currentDirectory, false /*allowUnknownOptions*/);
			return CompileFilesEx(t, inputFiles, otherFiles, newHarnessOptions, newCompilerOptions, currentDirectory, symlinks, tsconfig);
		};
		return result;
	}

	// PORT: sync.OnceValue → lazy field. Reads <submodule>/tests/lib with sys.FileSystem.
	static var testLibFolderMapValue:Map<String, MapFile> = null;

	static function testLibFolderMap():Map<String, MapFile> {
		if (testLibFolderMapValue == null) {
			final testfs = new Map<String, MapFile>();
			final libDir = Repo.TypeScriptSubmodulePath() + "/tests/lib";
			function walk(dir:String, rel:String) {
				final names = sys.FileSystem.readDirectory(dir);
				names.sort(go.Strings.Compare);
				for (name in names) {
					final full = dir + "/" + name;
					final relPath = rel == "" ? name : rel + "/" + name;
					if (sys.FileSystem.isDirectory(full)) {
						walk(full, relPath);
					} else {
						testfs.set(testLibFolder + "/" + relPath, new MapFile(go.Utf8.StringToBytes(sys.io.File.getContent(full))));
					}
				}
			}
			walk(libDir, "");
			testLibFolderMapValue = testfs;
		}
		return testLibFolderMapValue;
	}

	public static function SetOptionsFromTestConfig(t:T, testConfig:TestConfiguration, compilerOptions:CompilerOptions, harnessOptions:HarnessOptions,
			currentDirectory:String, allowUnknownOptions:Bool):Void {
		// PORT: Go map iteration order is random; the options are independent of each other.
		for (name => value in testConfig) {
			if (name == "typescriptversion") {
				continue;
			}

			final commandLineOption = getCommandLineOption(name);
			if (commandLineOption != null) {
				final parsedValue = getOptionValue(t, commandLineOption, value, currentDirectory);
				final errors = Tsoptions.ParseCompilerOptions(commandLineOption.Name, parsedValue, compilerOptions);
				if (Core.len(errors) > 0) {
					t.Fatalf("Error parsing value '%s' for compiler option '%s'.", value, commandLineOption.Name);
				}
				continue;
			}
			final harnessOption = getHarnessOption(name);
			if (harnessOption != null) {
				final parsedValue = getOptionValue(t, harnessOption, value, currentDirectory);
				parseHarnessOption(t, harnessOption.Name, parsedValue, harnessOptions);
				continue;
			}
			if (!allowUnknownOptions) {
				t.Fatalf("Unknown compiler option '%s'.", name);
			}
		}
	}

	static var compilerOptions(get, never):Array<CommandLineOption>;
	static var compilerOptionsValue:Array<CommandLineOption> = null;

	static function get_compilerOptions():Array<CommandLineOption> {
		if (compilerOptionsValue == null) {
			compilerOptionsValue = Core.Concatenate(Tsoptions.OptionsDeclarations, [
				newOption("allowNonTsExtensions", CommandLineOptionTypeBoolean),
				newOption("noErrorTruncation", CommandLineOptionTypeBoolean),
				newOption("suppressOutputPathCheck", CommandLineOptionTypeBoolean),
				newOption("noCheck", CommandLineOptionTypeBoolean),
			]);
		}
		return compilerOptionsValue;
	}

	static function newOption(name:String, kind:CommandLineOptionKind):CommandLineOption {
		final o = new CommandLineOption();
		o.Name = name;
		o.Kind = kind;
		return o;
	}

	static var harnessCommandLineOptions(get, never):Array<CommandLineOption>;
	static var harnessCommandLineOptionsValue:Array<CommandLineOption> = null;

	static function get_harnessCommandLineOptions():Array<CommandLineOption> {
		if (harnessCommandLineOptionsValue == null) {
			harnessCommandLineOptionsValue = [
				newOption("useCaseSensitiveFileNames", CommandLineOptionTypeBoolean),
				newOption("baselineFile", CommandLineOptionTypeString),
				newOption("includeBuiltFile", CommandLineOptionTypeString),
				newOption("fileName", CommandLineOptionTypeString),
				newOption("libFiles", CommandLineOptionTypeList),
				newOption("noImplicitReferences", CommandLineOptionTypeBoolean),
				newOption("currentDirectory", CommandLineOptionTypeString),
				newOption("symlink", CommandLineOptionTypeString),
				newOption("link", CommandLineOptionTypeString),
				newOption("noTypesAndSymbols", CommandLineOptionTypeBoolean),
				// Emitted js baseline will print full paths for every output file
				newOption("fullEmitPaths", CommandLineOptionTypeBoolean),
				// used to enable error collection in `transpile` baselines
				newOption("reportDiagnostics", CommandLineOptionTypeBoolean),
				// Adds suggestion diagnostics to error baselines
				newOption("captureSuggestions", CommandLineOptionTypeBoolean),
			];
		}
		return harnessCommandLineOptionsValue;
	}

	static function getHarnessOption(name:String):CommandLineOption {
		return Core.Find(harnessCommandLineOptions, function(option:CommandLineOption) return Strings.EqualFold(option.Name, name));
	}

	static function parseHarnessOption(t:T, key:String, value:Dynamic, harnessOptions:HarnessOptions):Void {
		switch (key) {
			case "useCaseSensitiveFileNames":
				harnessOptions.UseCaseSensitiveFileNames = (value : Bool);
			case "baselineFile":
				harnessOptions.BaselineFile = (value : String);
			case "includeBuiltFile":
				harnessOptions.IncludeBuiltFile = (value : String);
			case "fileName":
				harnessOptions.FileName = (value : String);
			case "libFiles":
				harnessOptions.LibFiles = [];
				for (v in (value : Array<Dynamic>)) {
					harnessOptions.LibFiles.push((v : String));
				}
			case "noImplicitReferences":
				harnessOptions.NoImplicitReferences = (value : Bool);
			case "currentDirectory":
				harnessOptions.CurrentDirectory = (value : String);
			case "symlink":
				harnessOptions.Symlink = (value : String);
			case "link":
				harnessOptions.Link = (value : String);
			case "noTypesAndSymbols":
				harnessOptions.NoTypesAndSymbols = (value : Bool);
			case "fullEmitPaths":
				harnessOptions.FullEmitPaths = (value : Bool);
			case "reportDiagnostics":
				harnessOptions.ReportDiagnostics = (value : Bool);
			case "captureSuggestions":
				harnessOptions.CaptureSuggestions = (value : Bool);
			case "typescriptVersion":
				harnessOptions.TypescriptVersion = (value : String);
			default:
				t.Fatalf("Unknown harness option '%s'.", key);
		}
	}

	static function getOptionValue(t:T, option:CommandLineOption, value:String, cwd:String):Dynamic {
		switch (option.Kind) {
			case CommandLineOptionTypeString:
				if (option.IsFilePath) {
					return Tspath.GetNormalizedAbsolutePath(value, cwd);
				}
				return value;
			case CommandLineOptionTypeNumber:
				final numVal = atoi(value);
				if (numVal == null) {
					t.Fatalf("Value for option '%s' must be a number, got: %v", option.Name, value);
				}
				return numVal;
			case CommandLineOptionTypeBoolean:
				switch (value.toLowerCase()) {
					case "true":
						return true;
					case "false":
						return false;
					default:
						t.Fatalf("Value for option '%s' must be a boolean, got: %v", option.Name, value);
				}
			case CommandLineOptionTypeEnum:
				final r = option.EnumMap().Get(value.toLowerCase());
				if (!r.ok) {
					t.Fatalf("Value for option '%s' must be one of %s, got: %v", option.Name, [for (k in option.EnumMap().Keys()) k].join(","), value);
				}
				return r.value;
			case CommandLineOptionTypeList | CommandLineOptionTypeListOrElement:
				final r = Tsoptions.ParseListTypeOption(option, value);
				final listVal = r.a, errors = r.b;
				if (option.Elements().IsFilePath) {
					return Core.Map(listVal, function(item:Dynamic):Dynamic {
						return Tspath.GetNormalizedAbsolutePath((item : String), cwd);
					});
				}
				if (Core.len(errors) > 0) {
					t.Fatalf("Unknown value '%s' for compiler option '%s'", value, option.Name);
				}
				return listVal;
			case CommandLineOptionTypeObject:
				t.Fatalf("Object type options like '%s' are not supported", option.Name);
			default:
		}
		return null;
	}

	// PORT: strconv.Atoi (decimal, optional sign; no overflow handling beyond Int).
	static function atoi(s:String):Null<Int> {
		if (s.length == 0)
			return null;
		var i = 0;
		var neg = false;
		if (s.charAt(0) == "+" || s.charAt(0) == "-") {
			neg = s.charAt(0) == "-";
			i = 1;
			if (s.length == 1)
				return null;
		}
		var n = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c < "0".code || c > "9".code)
				return null;
			n = n * 10 + (c - "0".code);
			i++;
		}
		return neg ? -n : n;
	}

	// PORT: SyncMap[SourceFileCacheKey, *ast.SourceFile] → StringMap with the key encoded by GetSourceFileCacheKey.
	static final sourceFileCache = new StringMap<SourceFile>();

	// PORT: gate-only addition (not in Go): drops the cached source files whose file name does not
	// satisfy keep (the Go cache lives for the whole test binary; the gate bounds memory with this).
	public static function ClearSourceFileCache(keep:(fileName:String) -> Bool):Void {
		final drop:Array<String> = [];
		for (k => v in sourceFileCache) {
			if (!keep(v.FileName()))
				drop.push(k);
		}
		for (k in drop)
			sourceFileCache.remove(k);
	}

	// PORT: struct key → String (PORTING.md §4a).
	public static function GetSourceFileCacheKey(opts:SourceFileParseOptions, text:String, scriptKind:ScriptKind):String {
		return opts.FileName + "\x00" + (opts.Path : String) + "\x00" + (opts.ExternalModuleIndicatorOptions.JSX ? "1" : "0")
			+ (opts.ExternalModuleIndicatorOptions.Force ? "1" : "0") + "\x00" + (scriptKind : Int) + "\x00" + text;
	}

	public static function NewTracerForBaselining(opts:ComparePathsOptions, builder:go.Strings.Builder):TracerForBaselining {
		final t = new TracerForBaselining();
		t.opts = opts;
		t.packageJsonCache = new StringMap();
		t.builder = builder;
		return t;
	}

	static function createCompilerHost(fs:FS, defaultLibraryPath:String, currentDirectory:String):CachedCompilerHost {
		final tracer = NewTracerForBaselining(new ComparePathsOptions(fs.UseCaseSensitiveFileNames(), currentDirectory), new go.Strings.Builder());
		final h = new CachedCompilerHost();
		h.CompilerHost = Compiler.NewCompilerHost(currentDirectory, fs, defaultLibraryPath, null, function(msg:Message, args:Array<Any>) {
			tracer.Trace(msg, ...args);
		});
		h.tracer = tracer;
		return h;
	}

	static function compileFilesWithHost(host:CompilerHost, config:ParsedCommandLine, harnessOptions:HarnessOptions):CompilationResult {
		// !!!
		// if (compilerOptions.project || !rootFiles || rootFiles.length === 0) {
		// 	const project = readProject(host.parseConfigHost, compilerOptions.project, compilerOptions);
		// 	if (project) {
		// 		if (project.errors && project.errors.length > 0) {
		// 			return new CompilationResult(host, compilerOptions, /*program*/ undefined, /*result*/ undefined, project.errors);
		// 		}
		// 		if (project.config) {
		// 			rootFiles = project.config.fileNames;
		// 			compilerOptions = project.config.options;
		// 		}
		// 	}
		// 	delete compilerOptions.project;
		// }
		final ctx = Context.Background();
		var preErrors:Array<Diagnostic> = [];
		final preCompilerOptions = config.CompilerOptions().Clone();
		preCompilerOptions.TraceResolution = TSFalse;
		final preConfig = new ParsedCommandLine();
		preConfig.ParsedConfig = new ParsedOptions();
		preConfig.ParsedConfig.CompilerOptions = preCompilerOptions;
		preConfig.ParsedConfig.FileNames = config.FileNames();
		preConfig.ConfigFile = config.ConfigFile;
		preConfig.Errors = config.Errors;
		final preProgram = createProgram(host, preConfig);
		appendAll(preErrors, preProgram.GetConfigFileParsingDiagnostics());
		appendAll(preErrors, preProgram.GetProgramDiagnostics());
		appendAll(preErrors, preProgram.GetSyntacticDiagnostics(ctx, null));
		appendAll(preErrors, preProgram.GetSemanticDiagnostics(ctx, null));
		appendAll(preErrors, preProgram.GetGlobalDiagnostics(ctx));
		if (preProgram.Options().GetEmitDeclarations()) {
			appendAll(preErrors, preProgram.GetDeclarationDiagnostics(ctx, null));
		}
		if (harnessOptions.CaptureSuggestions) {
			appendAll(preErrors, preProgram.GetSuggestionDiagnostics(ctx, null));
		}
		preErrors = Compiler.SortAndDeduplicateDiagnostics(preErrors);

		final postProgram = createProgram(host, config);
		var emitResult:EmitResult;
		if (TolerateEmitCrash) {
			// PORT: gate-only (see TolerateEmitCrash).
			emitResult = try postProgram.Emit(ctx, new EmitOptions()) catch (e:Dynamic) {
				LastEmitCrash = Std.string(e);
				new EmitResult();
			}
		} else {
			emitResult = postProgram.Emit(ctx, new EmitOptions());
		}
		var postErrors:Array<Diagnostic> = [];
		appendAll(postErrors, postProgram.GetConfigFileParsingDiagnostics());
		appendAll(postErrors, postProgram.GetProgramDiagnostics());
		appendAll(postErrors, postProgram.GetSyntacticDiagnostics(ctx, null));
		appendAll(postErrors, postProgram.GetSemanticDiagnostics(ctx, null));
		appendAll(postErrors, postProgram.GetGlobalDiagnostics(ctx));
		if (postProgram.Options().GetEmitDeclarations()) {
			appendAll(postErrors, postProgram.GetDeclarationDiagnostics(ctx, null));
		}
		if (harnessOptions.CaptureSuggestions) {
			appendAll(postErrors, postProgram.GetSuggestionDiagnostics(ctx, null));
		}
		postErrors = Compiler.SortAndDeduplicateDiagnostics(postErrors);

		var errors = postErrors;
		if (Core.len(postErrors) != Core.len(preErrors)) {
			var longerErrors = postErrors;
			var shorterErrors = preErrors;
			if (Core.len(preErrors) > Core.len(postErrors)) {
				longerErrors = preErrors;
				shorterErrors = postErrors;
			}
			var diag = Ast.NewCompilerDiagnostic(Diagnostics.NewAdHocMessage(Fmt.Sprintf("Pre-emit (%d) and post-emit (%d) diagnostic counts do not match! This can indicate that a semantic _error_ was added by the emit resolver - such an error may not be reflected on the command line or in the editor, but may be captured in a baseline here!",
				[Core.len(preErrors), Core.len(postErrors)])));
			diag = diag.AddRelatedInfo(Ast.NewCompilerDiagnostic(Diagnostics.NewAdHocMessage("The excess diagnostics are:")));
			if (longerErrors != null) {
				for (d in longerErrors) {
					var matched = false;
					if (shorterErrors != null) {
						for (d2 in shorterErrors) {
							final comparison = Ast.CompareDiagnostics(d, d2);
							if (comparison == 0) {
								matched = true;
								break;
							}
						}
					}
					if (!matched) {
						diag = diag.AddRelatedInfo(d);
					}
				}
			}
			// PORT: errors = shorterErrors; errors = append(errors, diag) — copy: shorterErrors is owned here.
			errors = shorterErrors == null ? [] : shorterErrors.copy();
			errors.push(diag);
		}

		return newCompilationResult(host, config.CompilerOptions(), postProgram, emitResult, errors, harnessOptions);
	}

	// PORT: `s = append(s, other...)` for a slice owned by the caller (non-null).
	static function appendAll<X>(s:Array<X>, other:Null<Array<X>>):Void {
		if (other != null)
			for (x in other)
				s.push(x);
	}

	static function newCompilationResult(host:CompilerHost, options:CompilerOptions, program:ProgramLike, result:EmitResult, diagnostics:Array<Diagnostic>,
			harnessOptions:HarnessOptions):CompilationResult {
		if (program != null) {
			options = program.Options();
		}

		final c = new CompilationResult();
		c.Diagnostics = diagnostics;
		c.Result = result;
		c.Program = program;
		c.Options = options;
		c.HarnessOptions = harnessOptions;
		c.Host = host;

		final fs = Std.downcast(host.FS(), OutputRecorderFS);
		if (fs != null && program != null) {
			// Corsa, unlike Strada, can use multiple threads for emit. As a result, the order of outputs is non-deterministic.
			// To make the order deterministic, we sort the outputs by the order of the inputs.
			final js = new OrderedMap<String, TestFile>(), dts = new OrderedMap<String, TestFile>(), maps = new OrderedMap<String, TestFile>();
			for (document in fs.Outputs()) {
				if (Tspath.HasJSFileExtension(document.UnitName) || Tspath.HasJSONFileExtension(document.UnitName)) {
					js.Set(document.UnitName, document);
				} else if (Tspath.IsDeclarationFileName(document.UnitName)) {
					dts.Set(document.UnitName, document);
				} else if (Tspath.FileExtensionIs(document.UnitName, ".map")) {
					maps.Set(document.UnitName, document);
				}
			}

			// using the order from the inputs, populate the outputs
			for (sourceFile in program.GetSourceFiles()) {
				final input = new TestFile(sourceFile.FileName(), sourceFile.Text());
				c.inputs.push(input);
				if (!Tspath.IsDeclarationFileName(sourceFile.FileName())) {
					final extname = Outputpaths.GetOutputExtension(sourceFile.FileName(), options.Jsx);
					final outputs = new CompilationOutput();
					outputs.Inputs = [input];
					outputs.JS = js.GetOrZero(c.getOutputPath(sourceFile.FileName(), extname));
					outputs.DTS = dts.GetOrZero(c.getOutputPath(sourceFile.FileName(), Tspath.GetDeclarationEmitExtensionForPath(sourceFile.FileName())));
					outputs.Map = maps.GetOrZero(c.getOutputPath(sourceFile.FileName(), extname + ".map"));
					c.inputsAndOutputs.Set(sourceFile.FileName(), outputs);
					if (outputs.JS != null) {
						c.inputsAndOutputs.Set(outputs.JS.UnitName, outputs);
						c.JS.Set(outputs.JS.UnitName, outputs.JS);
						js.Delete(outputs.JS.UnitName);
						c.outputs.push(outputs.JS);
					}
					if (outputs.DTS != null) {
						c.inputsAndOutputs.Set(outputs.DTS.UnitName, outputs);
						c.DTS.Set(outputs.DTS.UnitName, outputs.DTS);
						dts.Delete(outputs.DTS.UnitName);
						c.outputs.push(outputs.DTS);
					}
					if (outputs.Map != null) {
						c.inputsAndOutputs.Set(outputs.Map.UnitName, outputs);
						c.Maps.Set(outputs.Map.UnitName, outputs.Map);
						maps.Delete(outputs.Map.UnitName);
						c.outputs.push(outputs.Map);
					}
				}
			}

			// add any unhandled outputs, ordered by unit name
			for (document in sortedTestFiles(js)) {
				c.JS.Set(document.UnitName, document);
			}
			for (document in sortedTestFiles(dts)) {
				c.DTS.Set(document.UnitName, document);
			}
			for (document in sortedTestFiles(maps)) {
				c.Maps.Set(document.UnitName, document);
			}
		}

		return c;
	}

	// PORT: slices.SortedFunc(m.Values(), compareTestFiles)
	static function sortedTestFiles(m:OrderedMap<String, TestFile>):Array<TestFile> {
		final values = [for (v in m.Values()) v];
		Slices.SortFunc(values, compareTestFiles);
		return values;
	}

	static function compareTestFiles(a:TestFile, b:TestFile):Int {
		return Strings.Compare(a.UnitName, b.UnitName);
	}

	static function getTestBuildInfoReader(host:CompilerHost):TestBuildInfoReader {
		return new TestBuildInfoReader(Incremental.NewBuildInfoReader(host));
	}

	static function createProgram(host:CompilerHost, config:ParsedCommandLine):ProgramLike {
		var singleThreaded = TSUnknown;
		if (Testutil.TestProgramIsSingleThreaded()) {
			singleThreaded = TSTrue;
		}

		final programOptions = new ProgramOptions();
		programOptions.Config = config;
		programOptions.Host = host;
		programOptions.SingleThreaded = singleThreaded;
		final program = Compiler.NewProgram(programOptions);
		if (config.CompilerOptions().Incremental.IsTrue()) {
			final oldProgram = Incremental.ReadBuildInfoProgram(config, getTestBuildInfoReader(host), host);
			final incrementalProgram = Incremental.NewProgram(program, oldProgram, Incremental.CreateHost(host), false);
			return incrementalProgram;
		}
		return program;
	}

	// PORT: EnumerateFiles/listFiles take a Go regexp; here a predicate on the path. The folder is
	// resolved against repo.TestDataPath() like Go.
	public static function EnumerateFiles(folder:String, testRegex:Null<(String) -> Bool>, recursive:Bool):Array<String> {
		final files = listFiles(folder, testRegex, recursive);
		return Core.Map(files, Tspath.NormalizeSlashes);
	}

	static function listFiles(path:String, spec:Null<(String) -> Bool>, recursive:Bool):Array<String> {
		return listFilesWorker(spec, recursive, path);
	}

	static function listFilesWorker(spec:Null<(String) -> Bool>, recursive:Bool, folder:String):Array<String> {
		folder = Tspath.GetNormalizedAbsolutePath(folder, Repo.TestDataPath());
		final entries = sys.FileSystem.readDirectory(folder);
		entries.sort(Strings.Compare); // os.ReadDir returns the entries sorted by filename
		var paths:Array<String> = null;
		for (entry in entries) {
			final path = Tspath.NormalizePath(folder + "/" + entry);
			if (!sys.FileSystem.isDirectory(folder + "/" + entry)) {
				if (spec == null || spec(path)) {
					if (paths == null)
						paths = [];
					paths.push(path);
				}
			} else if (recursive) {
				final subPaths = listFilesWorker(spec, recursive, path);
				if (subPaths != null) {
					if (paths == null)
						paths = [];
					for (p in subPaths)
						paths.push(p);
				}
			}
		}
		return paths;
	}

	static function getFileBasedTestConfigurationDescription(config:TestConfiguration):String {
		final output = new StringBuf();
		final keys = [for (k in config.keys()) k];
		Slices.SortFunc(keys, Strings.Compare);
		for (i in 0...keys.length) {
			final key = keys[i];
			if (i > 0) {
				output.add(",");
			}
			output.add(key + "=" + config.get(key).toLowerCase());
		}
		return output.toString();
	}

	public static function GetFileBasedTestConfigurations(t:T, settings:StringMap<String>, varyByOptions:StringMap<Bool>):Array<NamedTestConfiguration> {
		final optionEntries:Array<Array<String>> = []; // Each element slice has the option name as the first element, and the values as the rest
		var variationCount = 1;
		final nonVaryingOptions = new StringMap<String>();
		for (option => value in settings) {
			if (varyByOptions.exists(option)) {
				final entries = splitOptionValues(t, value, option);
				if (Core.len(entries) > 1) {
					variationCount *= entries.length;
					if (variationCount > 25) {
						t.Fatal("Provided test options exceeded the maximum number of variations");
					}
					optionEntries.push([option].concat(entries));
				} else if (Core.len(entries) == 1) {
					nonVaryingOptions.set(option, entries[0]);
				}
			} else {
				// Variation is not supported for the option
				nonVaryingOptions.set(option, value);
			}
		}

		var configurations:Array<NamedTestConfiguration> = null;
		if (optionEntries.length > 0) {
			// Merge varying and non-varying options
			final varyingConfigurations = computeFileBasedTestConfigurationVariations(variationCount, optionEntries);
			for (varyingConfig in varyingConfigurations) {
				final description = getFileBasedTestConfigurationDescription(varyingConfig);
				for (k => v in nonVaryingOptions)
					varyingConfig.set(k, v);
				if (configurations == null)
					configurations = [];
				configurations.push(new NamedTestConfiguration(description, varyingConfig));
			}
		} else if (nonVaryingOptions.keys().hasNext()) {
			// Only non-varying options
			configurations = [new NamedTestConfiguration("", nonVaryingOptions)];
		}
		return configurations;
	}

	// Splits a string value into an array of strings, each corresponding to a unique value for the given option.
	// Also handles the `*` value, which includes all possible values for the option, and exclusions using `-` or `!`.
	// ```
	//
	//	splitOptionValues("esnext, es2015, es6", "target") => ["esnext", "es2015"]
	//	splitOptionValues("*", "strict") => ["true", "false"]
	//	splitOptionValues("*, -true", "strict") => ["false"]
	//
	// ```
	static function splitOptionValues(t:T, value:String, option:String):Array<String> {
		if (value.length == 0) {
			return null;
		}

		var star = false;
		final includes:Array<String> = [];
		final excludes:Array<String> = [];
		for (s0 in value.split(",")) {
			final s = Strings.TrimSpace(s0);
			if (s.length == 0) {
				continue;
			}
			if (s == "*") {
				star = true;
			} else if (StringTools.startsWith(s, "-") || StringTools.startsWith(s, "!")) {
				excludes.push(s.substring(1));
			} else {
				includes.push(s);
			}
		}

		if (includes.length == 0 && !star && excludes.length == 0) {
			return null;
		}

		// Dedupe the variations by their normalized values
		// PORT: map[tsoptions.CompilerOptionsValue]string → OrderedMap keyed by optionValueKey (Go map order is random).
		final variations = new OrderedMap<String, String>("");

		// add (and deduplicate) all included entries
		for (include in includes) {
			final value = getValueOfOptionString(t, option, include);
			final key = optionValueKey(value);
			if (!variations.Has(key)) {
				variations.Set(key, include);
			}
		}

		final allValues = getAllValuesForOption(option);
		if (star && Core.len(allValues) > 0) {
			// add all entries
			for (include in allValues) {
				final value = getValueOfOptionString(t, option, include);
				final key = optionValueKey(value);
				if (!variations.Has(key)) {
					variations.Set(key, include);
				}
			}
		}

		// remove all excluded entries
		for (exclude in excludes) {
			final r = tryGetValueOfOptionString(option, exclude);
			if (!r.ok) {
				// The excluded value is not recognized (e.g., a removed option like "es3").
				// Just skip it since there's nothing to remove.
				continue;
			}
			variations.Delete(optionValueKey(r.value));
		}

		if (variations.Size() == 0) {
			throw Fmt.Sprintf("Variations in test option '@%s' resulted in an empty set.", [option]);
		}
		return [for (v in variations.Values()) v];
	}

	// PORT: a CompilerOptionsValue used as a Go map key → String.
	static function optionValueKey(v:Dynamic):String {
		if (Std.isOfType(v, Bool))
			return "b:" + Std.string(v);
		if (Std.isOfType(v, Int))
			return "i:" + Std.string(v);
		return "s:" + Std.string(v);
	}

	static function getValueOfOptionString(t:T, option:String, value:String):Dynamic {
		final r = tryGetValueOfOptionString(option, value);
		if (!r.ok) {
			t.Fatalf("Unknown value '%s' for option '%s'", value, option);
		}
		return r.value;
	}

	static function tryGetValueOfOptionString(option:String, value:String):ValueOk<Dynamic> {
		final optionDecl = getCommandLineOption(option);
		if (optionDecl == null) {
			return new ValueOk<Dynamic>(null, false);
		}
		switch (optionDecl.Kind) {
			case CommandLineOptionTypeEnum:
				final r = optionDecl.EnumMap().Get(value.toLowerCase());
				if (!r.ok) {
					return new ValueOk<Dynamic>(null, false);
				}
				return new ValueOk<Dynamic>(r.value, true);
			case CommandLineOptionTypeBoolean:
				switch (value.toLowerCase()) {
					case "true":
						return new ValueOk<Dynamic>(true, true);
					case "false":
						return new ValueOk<Dynamic>(false, true);
					default:
				}
				return new ValueOk<Dynamic>(null, false);
			default:
		}
		return new ValueOk<Dynamic>(value, true);
	}

	static function getCommandLineOption(option:String):CommandLineOption {
		return Core.Find(compilerOptions, function(optionDecl:CommandLineOption) return Strings.EqualFold(optionDecl.Name, option));
	}

	static function getAllValuesForOption(option:String):Array<String> {
		final optionDecl = getCommandLineOption(option);
		if (optionDecl == null) {
			return null;
		}
		switch (optionDecl.Kind) {
			case CommandLineOptionTypeEnum:
				return [for (k in optionDecl.EnumMap().Keys()) k];
			case CommandLineOptionTypeBoolean:
				return ["true", "false"];
			default:
		}
		return null;
	}

	static function computeFileBasedTestConfigurationVariations(variationCount:Int, optionEntries:Array<Array<String>>):Array<TestConfiguration> {
		final configurations:Array<TestConfiguration> = [];
		computeFileBasedTestConfigurationVariationsWorker(configurations, optionEntries, 0, new StringMap<String>());
		return configurations;
	}

	static function computeFileBasedTestConfigurationVariationsWorker(configurations:Array<TestConfiguration>, optionEntries:Array<Array<String>>,
			index:Int, variationState:TestConfiguration):Void {
		if (index >= optionEntries.length) {
			configurations.push(variationState.copy());
			return;
		}

		final optionKey = optionEntries[index][0];
		final entries = optionEntries[index].slice(1);
		for (entry in entries) {
			// set or overwrite the variation, then compute the next variation
			variationState.set(optionKey, entry);
			computeFileBasedTestConfigurationVariationsWorker(configurations, optionEntries, index + 1, variationState);
		}
	}

	public static function GetConfigNameFromFileName(filename:String):String {
		final basenameLower = Tspath.GetBaseFileName(filename).toLowerCase();
		if (basenameLower == "tsconfig.json" || basenameLower == "jsconfig.json") {
			return basenameLower;
		}
		return "";
	}

	public static function SkipUnsupportedCompilerOptions(t:T, options:CompilerOptions):Void {
		t.Helper();
		switch (options.Module) {
			case ModuleKindAMD | ModuleKindUMD | ModuleKindSystem:
				t.Skipf("unsupported module kind %s", options.Module.String());
			default:
		}
		switch (options.ModuleResolution) {
			case ModuleResolutionKindNode10 | ModuleResolutionKindClassic:
				t.Skipf("unsupported module resolution kind %d", (options.ModuleResolution : Int));
			default:
		}
		if (options.ESModuleInterop.IsFalse()) {
			t.Skipf("esModuleInterop=false is unsupported");
		}
		if (options.AllowSyntheticDefaultImports.IsFalse()) {
			t.Skipf("allowSyntheticDefaultImports=false is unsupported");
		}
		if (options.BaseUrl != "") {
			t.Skipf("unsupported baseUrl %s", options.BaseUrl);
		}
		if (options.OutFile != "") {
			t.Skipf("unsupported outFile %s", options.OutFile);
		}
		switch (options.Target) {
			case ScriptTargetES5:
				t.Skipf("unsupported target %s", options.Target.String());
			default:
		}
		if (options.AlwaysStrict.IsFalse()) {
			t.Skipf("alwaysStrict=false is unsupported");
		}
	}

	// --- recorderfs.go ---

	public static function NewOutputRecorderFS(fs:FS):FS {
		return new OutputRecorderFS(fs);
	}
}

class TestFile {
	public var UnitName:String = "";
	public var Content:String = "";

	public function new(UnitName:String = "", Content:String = "") {
		this.UnitName = UnitName;
		this.Content = Content;
	}
}

// This maps a compiler setting to its string value, after splitting by commas,
// handling inclusions and exclusions, and deduplicating.
// For example, if a test file contains:
//
//	// @target: esnext, es2015
//
// Then the map will map "target" to "esnext", and another map will map "target" to "es2015".
typedef TestConfiguration = StringMap<String>;

class NamedTestConfiguration {
	public var Name:String = "";
	public var Config:TestConfiguration = null;

	public function new(Name:String = "", Config:TestConfiguration = null) {
		this.Name = Name;
		this.Config = Config;
	}
}

class HarnessOptions {
	public var UseCaseSensitiveFileNames:Bool = false;
	public var BaselineFile:String = "";
	public var IncludeBuiltFile:String = "";
	public var FileName:String = "";
	public var LibFiles:Array<String> = null;
	public var NoImplicitReferences:Bool = false;
	public var CurrentDirectory:String = "";
	public var Symlink:String = "";
	public var Link:String = "";
	public var NoTypesAndSymbols:Bool = false;
	public var FullEmitPaths:Bool = false;
	public var ReportDiagnostics:Bool = false;
	public var CaptureSuggestions:Bool = false;
	public var TypescriptVersion:String = "";

	public function new() {}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():HarnessOptions {
		final r = new HarnessOptions();
		r.UseCaseSensitiveFileNames = UseCaseSensitiveFileNames;
		r.BaselineFile = BaselineFile;
		r.IncludeBuiltFile = IncludeBuiltFile;
		r.FileName = FileName;
		r.LibFiles = LibFiles;
		r.NoImplicitReferences = NoImplicitReferences;
		r.CurrentDirectory = CurrentDirectory;
		r.Symlink = Symlink;
		r.Link = Link;
		r.NoTypesAndSymbols = NoTypesAndSymbols;
		r.FullEmitPaths = FullEmitPaths;
		r.ReportDiagnostics = ReportDiagnostics;
		r.CaptureSuggestions = CaptureSuggestions;
		r.TypescriptVersion = TypescriptVersion;
		return r;
	}
}

// Go type cachedCompilerHost: embeds compiler.CompilerHost (forwarded) and overrides GetSourceFile.
@:allow(ts.testutil.harnessutil)
class CachedCompilerHost implements CompilerHost {
	public var CompilerHost:CompilerHost = null;
	var tracer:TracerForBaselining = null;

	public function new() {}

	public function FS():FS {
		return CompilerHost.FS();
	}

	public function DefaultLibraryPath():String {
		return CompilerHost.DefaultLibraryPath();
	}

	public function GetCurrentDirectory():String {
		return CompilerHost.GetCurrentDirectory();
	}

	public function Trace(msg:Message, ...args:Any):Void {
		CompilerHost.Trace(msg, ...args);
	}

	public function GetResolvedProjectReference(fileName:String, path:Path):ParsedCommandLine {
		return CompilerHost.GetResolvedProjectReference(fileName, path);
	}

	public function GetSourceFile(opts:SourceFileParseOptions):SourceFile {
		final r = this.FS().ReadFile(opts.FileName);
		final text = r.value, ok = r.ok;
		if (!ok) {
			return null;
		}

		final scriptKind = Core.GetScriptKindFromFileName(opts.FileName);
		if (scriptKind == ScriptKindUnknown) {
			throw "Unknown script kind for file  " + opts.FileName;
		}

		final key = Harnessutil.GetSourceFileCacheKey(opts, text, scriptKind);

		final cached = @:privateAccess Harnessutil.sourceFileCache.get(key);
		if (cached != null) {
			return cached;
		}

		final sourceFile = Parser.ParseSourceFile(opts, text, scriptKind);
		@:privateAccess Harnessutil.sourceFileCache.set(key, sourceFile);
		return sourceFile;
	}
}

@:allow(ts.testutil.harnessutil)
class TracerForBaselining {
	var opts:ComparePathsOptions = null;
	var packageJsonCache:StringMap<Bool> = null;
	var builder:go.Strings.Builder = null;

	public function new() {}

	public function Trace(msg:Message, ...args:Any):Void {
		this.TraceWithWriter(this.builder, msg.Localize(Locale.Default, args.toArray()), true);
	}

	// PORT: io.Writer → strings.Builder (the only writer used).
	public function TraceWithWriter(w:go.Strings.Builder, msg:String, usePackageJsonCache:Bool):Void {
		w.WriteString(this.sanitizeTrace(msg, usePackageJsonCache) + "\n");
	}

	function sanitizeTrace(msg:String, usePackageJsonCache:Bool):String {
		// Version
		final str = Strings.Replace(msg, "'" + Core.Version() + "'", "'" + Harnessutil.FakeTSVersion + "'", 1);
		if (str != msg) {
			return str;
		}
		// caching of fs in trace to be replaces with non caching version
		if (StringTools.endsWith(msg, "' does not exist according to earlier cached lookups.")) {
			final str = msg.substring(0, msg.length - "' does not exist according to earlier cached lookups.".length);
			final file = Strings.TrimPrefix(str, "File '");
			if (usePackageJsonCache) {
				final filePath:String = Tspath.ToPath(file, this.opts.CurrentDirectory, this.opts.UseCaseSensitiveFileNames);
				if (this.packageJsonCache.exists(filePath)) {
					return msg;
				} else {
					this.packageJsonCache.set(filePath, false);
				}
			}
			return Fmt.Sprintf("File '%s' does not exist.", [file]);
		}
		if (StringTools.endsWith(msg, "' exists according to earlier cached lookups.")) {
			final str = msg.substring(0, msg.length - "' exists according to earlier cached lookups.".length);
			final file = Strings.TrimPrefix(str, "File '");
			if (usePackageJsonCache) {
				final filePath:String = Tspath.ToPath(file, this.opts.CurrentDirectory, this.opts.UseCaseSensitiveFileNames);
				if (this.packageJsonCache.exists(filePath)) {
					return msg;
				} else {
					this.packageJsonCache.set(filePath, true);
				}
			}
			return Fmt.Sprintf("Found 'package.json' at '%s'.", [file]);
		}
		if (usePackageJsonCache) {
			if (StringTools.endsWith(msg, "' does not exist.")) {
				final str = msg.substring(0, msg.length - "' does not exist.".length);
				final file = Strings.TrimPrefix(str, "File '");
				final filePath:String = Tspath.ToPath(file, this.opts.CurrentDirectory, this.opts.UseCaseSensitiveFileNames);
				if (!this.packageJsonCache.exists(filePath)) {
					this.packageJsonCache.set(filePath, false);
					return msg;
				} else {
					return Fmt.Sprintf("File '%s' does not exist according to earlier cached lookups.", [file]);
				}
			}
			if (StringTools.startsWith(msg, "Found 'package.json' at '")) {
				final str = msg.substring("Found 'package.json' at '".length);
				final file = Strings.TrimSuffix(str, "'.");
				final filePath:String = Tspath.ToPath(file, this.opts.CurrentDirectory, this.opts.UseCaseSensitiveFileNames);
				if (!this.packageJsonCache.exists(filePath)) {
					this.packageJsonCache.set(filePath, true);
					return msg;
				} else {
					return Fmt.Sprintf("File '%s' exists according to earlier cached lookups.", [file]);
				}
			}
		}
		return msg;
	}

	public function String():String {
		return this.builder.String();
	}

	public function Reset():Void {
		this.packageJsonCache = new StringMap();
	}
}

@:allow(ts.testutil.harnessutil)
class CompilationResult {
	public var Diagnostics:Array<Diagnostic> = null;
	public var Result:EmitResult = null;
	public var Program:ProgramLike = null;
	public var Options:CompilerOptions = null;
	public var HarnessOptions:HarnessOptions = null;
	public var JS:OrderedMap<String, TestFile> = new OrderedMap<String, TestFile>();
	public var DTS:OrderedMap<String, TestFile> = new OrderedMap<String, TestFile>();
	public var Maps:OrderedMap<String, TestFile> = new OrderedMap<String, TestFile>();
	public var Symlinks:StringMap<String> = null;
	public var Repeat:(TestConfiguration) -> CompilationResult = null;
	var outputs:Array<TestFile> = [];
	var inputs:Array<TestFile> = [];
	var inputsAndOutputs:OrderedMap<String, CompilationOutput> = new OrderedMap<String, CompilationOutput>();
	public var Trace:String = "";
	public var Host:CompilerHost = null;

	public function new() {}

	function getOutputPath(path:String, ext:String):String {
		path = Tspath.ResolvePath(this.Host.GetCurrentDirectory(), path);
		var outDir:String;
		if (ext == ".d.ts" || ext == ".d.mts" || ext == ".d.cts" || (StringTools.endsWith(ext, ".ts") && ext.indexOf(".d.") >= 0)) {
			outDir = this.Options.DeclarationDir;
			if (outDir == "") {
				outDir = this.Options.OutDir;
			}
		} else {
			outDir = this.Options.OutDir;
		}
		if (outDir != "") {
			final common = this.Program.CommonSourceDirectory();
			if (common != "") {
				path = Tspath.GetRelativePathFromDirectory(common, path, new ComparePathsOptions(this.Host.FS().UseCaseSensitiveFileNames(), this.Host.GetCurrentDirectory()));
				path = Tspath.CombinePaths(Tspath.ResolvePath(this.Host.GetCurrentDirectory(), this.Options.OutDir), path);
			}
		}
		return Tspath.ChangeExtension(path, ext);
	}

	public function FS():FS {
		return this.Host.FS();
	}

	public function GetNumberOfJSFiles(includeJson:Bool):Int {
		if (includeJson) {
			return this.JS.Size();
		}
		var count = 0;
		for (file in this.JS.Values()) {
			if (!Tspath.FileExtensionIs(file.UnitName, Tspath.ExtensionJson)) {
				count++;
			}
		}
		return count;
	}

	public function Inputs():Array<TestFile> {
		return this.inputs;
	}

	public function Outputs():Array<TestFile> {
		return this.outputs;
	}

	public function GetInputsAndOutputsForFile(path:String):CompilationOutput {
		return this.inputsAndOutputs.GetOrZero(Tspath.ResolvePath(this.Host.GetCurrentDirectory(), path));
	}

	public function GetInputsForFile(path:String):Array<TestFile> {
		final outputs = this.GetInputsAndOutputsForFile(path);
		if (outputs != null) {
			return outputs.Inputs;
		}
		return null;
	}

	public function GetOutput(path:String, kind:String /*"js" | "dts" | "map"*/):TestFile {
		final outputs = this.GetInputsAndOutputsForFile(path);
		if (outputs != null) {
			switch (kind) {
				case "js":
					return outputs.JS;
				case "dts":
					return outputs.DTS;
				case "map":
					return outputs.Map;
				default:
			}
		}
		return null;
	}

	public function GetSourceMapRecord():String {
		if (this.Result == null || Core.len(this.Result.SourceMaps) == 0) {
			return "";
		}

		final sourceMapRecorder = new WriterAggregator();
		for (sourceMapData in this.Result.SourceMaps) {
			var prevSourceFile:SourceFile = null;
			var currentFile:TestFile;

			if (Tspath.IsDeclarationFileName(sourceMapData.GeneratedFile)) {
				currentFile = this.DTS.GetOrZero(sourceMapData.GeneratedFile);
			} else {
				currentFile = this.JS.GetOrZero(sourceMapData.GeneratedFile);
			}

			final sourceMapSpanWriter = SourceMapSpanWriter.newSourceMapSpanWriter(sourceMapRecorder, sourceMapData.SourceMap, currentFile);
			final mapper = ts.sourcemap.Sourcemap.DecodeMappings(sourceMapData.SourceMap.Mappings);
			for (decodedSourceMapping in mapper.Values()) {
				var currentSourceFile:SourceFile = null;
				if (decodedSourceMapping.IsSourceMapping()) {
					currentSourceFile = this.Program.GetSourceFile(sourceMapData.InputSourceFileNames[decodedSourceMapping.SourceIndex]);
				}
				if (currentSourceFile != prevSourceFile) {
					if (currentSourceFile != null) {
						sourceMapSpanWriter.recordNewSourceFileSpan(decodedSourceMapping, currentSourceFile.Text());
					}
					prevSourceFile = currentSourceFile;
				} else {
					sourceMapSpanWriter.recordSourceMapSpan(decodedSourceMapping);
				}
			}
			sourceMapSpanWriter.close();
		}
		return sourceMapRecorder.String();
	}
}

class CompilationOutput {
	public var Inputs:Array<TestFile> = null;
	public var JS:TestFile = null;
	public var DTS:TestFile = null;
	public var Map:TestFile = null;

	public function new() {}
}

class TestBuildInfoReader implements ts.execute.incremental.Incremental.BuildInfoReader {
	var inner:ts.execute.incremental.Incremental.BuildInfoReader = null;

	public function new(inner:ts.execute.incremental.Incremental.BuildInfoReader) {
		this.inner = inner;
	}

	public function ReadBuildInfo(config:ParsedCommandLine):ts.execute.incremental.BuildInfo {
		final r = this.inner.ReadBuildInfo(config);
		if (r == null) {
			return null;
		}
		r.Version = Core.Version();
		return r;
	}
}
