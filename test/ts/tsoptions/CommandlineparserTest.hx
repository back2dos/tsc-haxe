package ts.tsoptions;

import ts.tsoptions.TsoptionsTestUtil.StringWriter;
import ts.tsoptions.ExportTest.TestCommandLineParser;

// Port of commandlineparser_test.go.
class CommandlineparserTest {
	static function tempDir():String {
		// PORT: t.TempDir() → an existing scratch directory (the tests only read from it).
		final dir = Sys.getCwd() + "bin/tsoptions/tmp";
		if (!sys.FileSystem.exists(dir))
			sys.FileSystem.createDirectory(dir);
		return Tspath.NormalizeSlashes(dir);
	}

	public static function run() {
		T.run("TestCommandLineParseResult", () -> {
			final parseCommandLineSubScenarios:Array<SubScenarioInput> = [
				// --lib es6 0.ts
				new SubScenarioInput("Parse single option of library flag", ["--lib", "es6", "0.ts"]),
				new SubScenarioInput("Handles may only be used with --build flags", ["--build", "--clean", "--dry", "--force", "--verbose"]),
				// --declarations --allowTS
				new SubScenarioInput("Handles did you mean for misspelt flags", ["--declarations", "--allowTS"]),
				// --lib es5,es2015.symbol.wellknown 0.ts
				new SubScenarioInput("Parse multiple options of library flags", ["--lib", "es5,es2015.symbol.wellknown", "0.ts"]),
				// --lib es5,invalidOption 0.ts
				new SubScenarioInput("Parse invalid option of library flags", ["--lib", "es5,invalidOption", "0.ts"]),
				// 0.ts --jsx
				new SubScenarioInput("Parse empty options of --jsx", ["0.ts", "--jsx"]),
				// 0.ts --
				new SubScenarioInput("Parse empty options of --module", ["0.ts", "--module"]),
				// 0.ts --newLine
				new SubScenarioInput("Parse empty options of --newLine", ["0.ts", "--newLine"]),
				// 0.ts --target
				new SubScenarioInput("Parse empty options of --target", ["0.ts", "--target"]),
				// 0.ts --moduleResolution
				new SubScenarioInput("Parse empty options of --moduleResolution", ["0.ts", "--moduleResolution"]),
				// 0.ts --lib
				new SubScenarioInput("Parse empty options of --lib", ["0.ts", "--lib"]),
				// 0.ts --lib
				// This test is an error because the empty string is falsey
				new SubScenarioInput("Parse empty string of --lib", ["0.ts", "--lib", ""]),
				// 0.ts --lib
				new SubScenarioInput("Parse immediately following command line argument of --lib", ["0.ts", "--lib", "--sourcemap"]),
				// --lib es5, es7 0.ts
				new SubScenarioInput("Parse --lib option with extra comma", ["--lib", "es5,", "es7", "0.ts"]),
				// --lib es5, es7 0.ts
				new SubScenarioInput("Parse --lib option with trailing white-space", ["--lib", "es5, ", "es7", "0.ts"]),
				// --lib es5,es2015.symbol.wellknown --target es5 0.ts
				new SubScenarioInput("Parse multiple compiler flags with input files at the end", ["--lib", "es5,es2015.symbol.wellknown", "--target", "es5", "0.ts"]),
				// --module commonjs --target es5 0.ts --lib es5,es2015.symbol.wellknown
				new SubScenarioInput("Parse multiple compiler flags with input files in the middle",
					["--module", "commonjs", "--target", "es5", "0.ts", "--lib", "es5,es2015.symbol.wellknown"]),
				// --module commonjs --target es5 --lib es5 0.ts --library es2015.array,es2015.symbol.wellknown
				new SubScenarioInput("Parse multiple library compiler flags ",
					["--module", "commonjs", "--target", "es5", "--lib", "es5", "0.ts", "--lib", "es2015.core, es2015.symbol.wellknown "]),
				new SubScenarioInput("Parse explicit boolean flag value", ["--strictNullChecks", "false", "0.ts"]),
				new SubScenarioInput("Parse non boolean argument after boolean flag", ["--noImplicitAny", "t", "0.ts"]),
				new SubScenarioInput("Parse implicit boolean flag value", ["--strictNullChecks"]),
				new SubScenarioInput("parse --incremental", ["--incremental", "0.ts"]),
				new SubScenarioInput("parse --tsBuildInfoFile", ["--tsBuildInfoFile", "build.tsbuildinfo", "0.ts"]),
				new SubScenarioInput("allows tsconfig only option to be set to null", ["--composite", "null", "-tsBuildInfoFile", "null", "0.ts"]),

				// ****** Watch Options ******
				new SubScenarioInput("parse --watchFile", ["--watchFile", "UseFsEvents", "0.ts"]),
				new SubScenarioInput("parse --watchDirectory", ["--watchDirectory", "FixedPollingInterval", "0.ts"]),
				new SubScenarioInput("parse --fallbackPolling", ["--fallbackPolling", "PriorityInterval", "0.ts"]),
				new SubScenarioInput("parse --synchronousWatchDirectory", ["--synchronousWatchDirectory", "0.ts"]),
				new SubScenarioInput("errors on missing argument to --fallbackPolling", ["0.ts", "--fallbackPolling"]),
				new SubScenarioInput("parse --excludeDirectories", ["--excludeDirectories", "**/temp", "0.ts"]),
				new SubScenarioInput("errors on invalid excludeDirectories", ["--excludeDirectories", "**/../*", "0.ts"]),
				new SubScenarioInput("parse --excludeFiles", ["--excludeFiles", "**/temp/*.ts", "0.ts"]),
				new SubScenarioInput("errors on invalid excludeFiles", ["--excludeFiles", "**/../*", "0.ts"]),
			];

			for (testCase in parseCommandLineSubScenarios) {
				testCase.createSubScenario("parseCommandLine").assertParseResult();
			}
		});

		T.run("TestResponseFileDoesNotPanic", () -> {
			// Passing `@` with an empty or relative filename should not panic.
			// It should produce a diagnostic error instead.
			final cwd = tempDir();
			T.run("TestResponseFileDoesNotPanic/empty response file", () -> {
				final parsed = ExportTest.ParseCommandLineTestWorker(null, ["@"], Osvfs.FS(), cwd);
				T.isTrue(parsed.Errors.length > 0, "expected an error for empty response file name");
			});

			T.run("TestResponseFileDoesNotPanic/relative response file", () -> {
				final parsed = ExportTest.ParseCommandLineTestWorker(null, ["@blah"], Osvfs.FS(), cwd);
				T.isTrue(parsed.Errors.length > 0, "expected an error for non-existent response file");
			});
		});

		T.run("TestParseCommandLineTypeRootsRelativePath", () -> {
			final host = Tsoptionstest.NewVFSParseConfigHost(["/home/project/bug.ts" => "let x = 1;"], "/home/project", true);

			final cmdLine = Tsoptions.ParseCommandLine(["--typeRoots", "t", "bug.ts"], host);

			final typeRoots = cmdLine.CompilerOptions().TypeRoots;
			T.isTrue(typeRoots != null, "typeRoots should not be nil");
			T.eq(1, typeRoots.length);
			T.isTrue(Tspath.IsRootedDiskPath(typeRoots[0]), "typeRoots entry should be an absolute path, got: " + typeRoots[0]);
			T.isTrue(StringTools.endsWith(typeRoots[0], "/t"), "typeRoots entry should end with '/t', got: " + typeRoots[0]);
		});

		T.run("TestCustomConditionsNullOverride", () -> {
			final files = [
				"/project/tsconfig.json" => '{
  "compilerOptions": {
    "customConditions": ["condition1", "condition2"]
  }
}',
				"/project/index.ts" => 'console.log("Hello, World!");',
			];

			final host = Tsoptionstest.NewVFSParseConfigHost(files, "/project", true);

			// Parse command line with --customConditions null
			final cmdLine = Tsoptions.ParseCommandLine(["--project", "/project", "--customConditions", "null"], host);

			// Check that the raw options contain null for customConditions
			if (Std.isOfType(cmdLine.Raw, OrderedMap)) {
				final rawMap:OrderedMap<String, Dynamic> = cmdLine.Raw;
				final r = rawMap.Get("customConditions");
				T.isTrue(r.ok, "customConditions should exist in raw options");
				T.isTrue(r.value == null, "customConditions should be nil in raw options, got: " + Std.string(r.value));
			} else {
				T.fail("Raw options should be an OrderedMap");
				return;
			}

			// Now parse the config file with the command line options
			// Wrap command line options in "compilerOptions" key to match tsconfig.json structure
			final wrappedRaw = new OrderedMap<String, Dynamic>();
			wrappedRaw.Set("compilerOptions", (cmdLine.Raw : OrderedMap<String, Dynamic>));
			final r = Tsoptions.GetParsedCommandLineOfConfigFile("/project/tsconfig.json", cmdLine.CompilerOptions(), wrappedRaw, host, null);
			final parsedConfig = r.a;
			final errors = r.b;

			T.isTrue(Core.len(errors) == 0, "Should not have errors: " + Std.string(errors));

			// Check that customConditions is nil (overridden by command line)
			final customConditions = parsedConfig.CompilerOptions().CustomConditions;
			T.isTrue(customConditions == null, "customConditions should be nil after override, got: " + Std.string(customConditions));
		});

		T.run("TestParseCommandLineVerifyNull", () -> {
			// run test for boolean
			new SubScenarioInput("allows setting option type boolean to false", ["--composite", "false", "0.ts"]).createSubScenario("parseCommandLine")
				.assertParseResult();

			final verifyNullSubScenarios:Array<VerifyNull> = [
				new VerifyNull("option of type boolean", "composite", "true"),
				new VerifyNull("option of type object", "paths"),
				new VerifyNull("option of type list", "rootDirs", "abc,xyz"),
				createVerifyNullForNonNullIncluded("option of type string", CommandLineOptionTypeString, "hello"),
				createVerifyNullForNonNullIncluded("option of type number", CommandLineOptionTypeNumber, "10"),
				// todo: make the following work for tests -- currently it is difficult to do extra options of enum type
				// createVerifyNullForNonNullIncluded("option of type custom map", CommandLineOptionTypeEnum, "node"),
			];

			for (verifyNullCase in verifyNullSubScenarios) {
				createSubScenario("parseCommandLine", verifyNullCase.subScenario + " allows setting it to null", ["--" + verifyNullCase.optionName, "null", "0.ts"],
					verifyNullCase.optDecls).assertParseResult();

				if (verifyNullCase.nonNullValue != "") {
					createSubScenario("parseCommandLine", verifyNullCase.subScenario + " errors if non null value is passed",
						["--" + verifyNullCase.optionName, verifyNullCase.nonNullValue, "0.ts"], verifyNullCase.optDecls).assertParseResult();
				}

				createSubScenario("parseCommandLine", verifyNullCase.subScenario + " errors if its followed by another option",
					["0.ts", "--strictNullChecks", "--" + verifyNullCase.optionName], verifyNullCase.optDecls).assertParseResult();

				createSubScenario("parseCommandLine", verifyNullCase.subScenario + " errors if its last option", ["0.ts", "--" + verifyNullCase.optionName],
					verifyNullCase.optDecls).assertParseResult();
			}
		});

		T.run("TestParseBuildCommandLine", () -> {
			final parseCommandLineSubScenarios:Array<SubScenarioInput> = [
				new SubScenarioInput("parse build without any options ", []),
				new SubScenarioInput("Parse multiple options", ["--verbose", "--force", "tests"]),
				new SubScenarioInput("Parse option with invalid option", ["--verbose", "--invalidOption"]),
				new SubScenarioInput("Parse multiple flags with input projects at the end", ["--force", "--verbose", "src", "tests"]),
				new SubScenarioInput("Parse multiple flags with input projects in the middle", ["--force", "src", "tests", "--verbose"]),
				new SubScenarioInput("Parse multiple flags with input projects in the beginning", ["src", "tests", "--force", "--verbose"]),
				new SubScenarioInput("parse build with --incremental", ["--incremental", "tests"]),
				new SubScenarioInput("parse build with --locale en-us", ["--locale", "en-us", "src"]),
				new SubScenarioInput("parse build with --tsBuildInfoFile", ["--tsBuildInfoFile", "build.tsbuildinfo", "tests"]),
				new SubScenarioInput("reports other common may not be used with --build flags", ["--strict"]),
				new SubScenarioInput("--clean and --force together is invalid", ["--clean", "--force"]),
				new SubScenarioInput("--clean and --verbose together is invalid", ["--clean", "--verbose"]),
				new SubScenarioInput("--clean and --watch together is invalid", ["--clean", "--watch"]),
				new SubScenarioInput("--watch and --dry together is invalid", ["--watch", "--dry"]),
				new SubScenarioInput("parse --watchFile", ["--watchFile", "UseFsEvents", "--verbose"]),
				new SubScenarioInput("parse --watchDirectory", ["--watchDirectory", "FixedPollingInterval", "--verbose"]),
				new SubScenarioInput("parse --fallbackPolling", ["--fallbackPolling", "PriorityInterval", "--verbose"]),
				new SubScenarioInput("parse --synchronousWatchDirectory", ["--synchronousWatchDirectory", "--verbose"]),
				new SubScenarioInput("errors on missing argument", ["--verbose", "--fallbackPolling"]),
				new SubScenarioInput("errors on invalid excludeDirectories", ["--excludeDirectories", "**/../*"]),
				new SubScenarioInput("parse --excludeFiles", ["--excludeFiles", "**/temp/*.ts"]),
				new SubScenarioInput("errors on invalid excludeFiles", ["--excludeFiles", "**/../*"]),
			];

			for (testCase in parseCommandLineSubScenarios) {
				testCase.createSubScenario("parseBuildOptions").assertBuildParseResult();
			}

			final extraScenarios:Array<SubScenarioInput> = [
				new SubScenarioInput("parse --builders", ["--builders", "2"]),
				new SubScenarioInput("--singleThreaded and --builders together", ["--singleThreaded", "--builders", "2"]),
				new SubScenarioInput("reports error when --builders is 0", ["--builders", "0"]),
				new SubScenarioInput("reports error when --builders is negative", ["--builders", "-1"]),
				new SubScenarioInput("reports error when --builders is invalid type", ["--builders", "invalid"]),
			];

			for (testCase in extraScenarios) {
				testCase.createSubScenario("parseBuildOptions").assertBuildParseResultWithTsBaseline(null);
			}
		});

		T.run("TestAffectsBuildInfo", () -> {
			T.run("TestAffectsBuildInfo/should have affectsBuildInfo true for every option with affectsSemanticDiagnostics", () -> {
				for (option in Tsoptions.OptionsDeclarations) {
					if (option.AffectsSemanticDiagnostics) {
						// semantic diagnostics affect the build info, so ensure they're included
						T.isTrue(option.AffectsBuildInfo, option.Name);
					}
				}
			});
		});
	}

	static function createVerifyNullForNonNullIncluded(subScenario:String, kind:CommandLineOptionKind, nonNullValue:String):VerifyNull {
		final o = new CommandLineOption();
		o.Name = "optionName";
		o.Kind = kind;
		o.IsTSConfigOnly = true;
		o.Category = Diagnostics.Backwards_Compatibility;
		o.Description = Diagnostics.Enable_project_compilation;
		o.DefaultValueDescription = null;
		return new VerifyNull(subScenario, "optionName", nonNullValue, Slices.Concat(Tsoptions.OptionsDeclarations, [o]));
	}

	public static function parseExistingCompilerBaseline(baseline:String):TestCommandLineParser_ {
		final rest = TsoptionsTestUtil.cut(baseline, "CompilerOptions::\n").b;
		final c1 = TsoptionsTestUtil.cut(rest, "\nWatchOptions::\n");
		final compilerOptions = c1.a;
		final watchFound = c1.c;
		final c2 = TsoptionsTestUtil.cut(c1.b, "\nFileNames::\n");
		final watchOptions = c2.a;
		final c3 = TsoptionsTestUtil.cut(c2.b, "\nErrors::\n");
		final fileNames = c3.a;
		final errors = c3.b;

		final r = TsoptionsTestUtil.unmarshalCompilerOptions(compilerOptions);
		T.isTrue(r.err == null, "unmarshal compiler options: " + Std.string(r.err));

		if (watchFound && watchOptions != "") {
			final e2 = Jsontext.Parse(watchOptions).err;
			T.isTrue(e2 == null, "unmarshal watch options: " + Std.string(e2));
		}

		final result = new TestCommandLineParser_();
		result.options = r.value;
		result.fileNames = fileNames;
		result.errors = errors;
		return result;
	}

	public static function formatNewBaseline(commandLine:Array<String>, opts:String, fileNames:String, errors:String):String {
		final formatted = new StringBuf();
		formatted.add("Args::\n");
		formatted.add("[");
		for (i in 0...commandLine.length) {
			if (i > 0) {
				formatted.add(", ");
			}
			formatted.add('"');
			formatted.add(commandLine[i]);
			formatted.add('"');
		}
		formatted.add("]");
		formatted.add("\n\nCompilerOptions::\n");
		formatted.add(opts);
		// todo: watch options not implemented
		// formatted.WriteString("WatchOptions::\n")
		formatted.add("\n\nFileNames::\n");
		formatted.add(fileNames);
		formatted.add("\n\nErrors::\n");
		formatted.add(errors);
		return formatted.toString();
	}

	public static function parseExistingCompilerBaselineBuild(baseline:String):TestCommandLineParserBuild {
		final rest = TsoptionsTestUtil.cut(baseline, "buildOptions::\n").b;
		final c1 = TsoptionsTestUtil.cut(rest, "\nWatchOptions::\n");
		final buildOptions = c1.a;
		final watchFound = c1.c;
		final c2 = TsoptionsTestUtil.cut(c1.b, "\nProjects::\n");
		final watchOptions = c2.a;
		final c3 = TsoptionsTestUtil.cut(c2.b, "\nErrors::\n");
		final projects = c3.a;
		final errors = c3.b;

		final r = TsoptionsTestUtil.unmarshalBuildOptions(buildOptions);
		T.isTrue(r.err == null, "unmarshal build options: " + Std.string(r.err));

		final r2 = TsoptionsTestUtil.unmarshalCompilerOptions(buildOptions);
		T.isTrue(r2.err == null, "unmarshal compiler options: " + Std.string(r2.err));

		if (watchFound && watchOptions != "") {
			final e2 = Jsontext.Parse(watchOptions).err;
			T.isTrue(e2 == null, "unmarshal watch options: " + Std.string(e2));
		}

		final result = new TestCommandLineParserBuild();
		result.options = r.value;
		result.compilerOptions = r2.value;
		result.projects = projects;
		result.errors = errors;
		return result;
	}

	public static function formatNewBaselineBuild(commandLine:Array<String>, opts:String, compilerOpts:String, projects:String, errors:String):String {
		final formatted = new StringBuf();
		formatted.add("Args::\n");
		formatted.add("[");
		for (i in 0...commandLine.length) {
			if (i > 0) {
				formatted.add(", ");
			}
			formatted.add('"');
			formatted.add(commandLine[i]);
			formatted.add('"');
		}
		formatted.add("]");
		formatted.add("\n\nbuildOptions::\n");
		formatted.add(opts);
		formatted.add("\n\ncompilerOptions::\n");
		formatted.add(compilerOpts);
		// todo: watch options not implemented
		// formatted.WriteString("WatchOptions::\n")
		formatted.add("\n\nProjects::\n");
		formatted.add(projects);
		formatted.add("\n\nErrors::\n");
		formatted.add(errors);
		return formatted.toString();
	}

	public static function createSubScenario(scenarioKind:String, subScenarioName:String, commandline:Array<String>,
			?opts:Null<Array<CommandLineOption>>):CommandLineSubScenario {
		subScenarioName = scenarioKind + "/" + subScenarioName;
		final baselineFileName = "tests/baselines/reference/config/commandLineParsing/" + subScenarioName + ".js";

		final result = new CommandLineSubScenario(TsoptionsTestUtil.TypeScriptSubmodulePath() + "/" + baselineFileName, subScenarioName, commandline, null);
		if (opts != null) {
			result.optDecls = opts;
		}
		return result;
	}

	public static function tempDirFor():String {
		return tempDir();
	}
}

class SubScenarioInput {
	public var name:String;
	public var commandLineArgs:Array<String>;

	public function new(name:String, commandLineArgs:Array<String>) {
		this.name = name;
		this.commandLineArgs = commandLineArgs;
	}

	public function createSubScenario(scenarioKind:String):CommandLineSubScenario {
		return CommandlineparserTest.createSubScenario(scenarioKind, this.name, this.commandLineArgs);
	}
}

// PORT: filefixture.Fixture → the path of the TypeScript baseline file.
class CommandLineSubScenario {
	public var baseline:String;
	public var testName:String;
	public var commandLine:Array<String>;
	public var optDecls:Null<Array<CommandLineOption>>;

	public function new(baseline:String, testName:String, commandLine:Array<String>, optDecls:Null<Array<CommandLineOption>>) {
		this.baseline = baseline;
		this.testName = testName;
		this.commandLine = commandLine;
		this.optDecls = optDecls;
	}

	public function assertParseResult():Void {
		final f = this;
		T.run(f.testName, () -> {
			final originalBaseline = TsoptionsTestUtil.readFile(f.baseline);
			if (originalBaseline == null) {
				T.fail("missing TS baseline " + f.baseline);
				return;
			}
			final tsBaseline = CommandlineparserTest.parseExistingCompilerBaseline(originalBaseline);

			// f.workerDiagnostic is either defined or set to default pointer in `createSubScenario`
			final parsed = ExportTest.ParseCommandLineTestWorker(f.optDecls, f.commandLine, Osvfs.FS(), CommandlineparserTest.tempDirFor());

			final newBaselineFileNames = parsed.FileNames.join(",");
			T.eq(tsBaseline.fileNames, newBaselineFileNames);

			final o = Json.MarshalOrdered(parsed.Options);
			final r = TsoptionsTestUtil.unmarshalCompilerOptions(o);
			T.isTrue(r.err == null, Std.string(r.err));
			final diff = TsoptionsTestUtil.compilerOptionsDiff(tsBaseline.options, r.value);
			T.isTrue(diff == "", f.testName + ": compiler options differ: " + diff);

			final e = Jsontext.Parse(o).err;
			T.isTrue(e == null, Std.string(e));

			// !!! useful for debugging but will not pass due to `none` as enum options
			// assert.DeepEqual(t, tsBaseline.watchoptions, newParsedWatchOptions)

			final formattedErrors = new StringWriter();
			final fo = new FormattingOptions();
			fo.NewLine = "\n";
			Diagnosticwriter.WriteFormatDiagnostics(formattedErrors, Diagnosticwriter.FromASTDiagnostics(parsed.Errors), fo);
			final newBaselineErrors = formattedErrors.toString();

			// !!!
			// useful for debugging--compares the new errors with the old errors. currently will NOT pass because of unimplemented options, not completely identical enum options, etc
			// assert.Equal(t, tsBaseline.errors, newBaselineErrors)

			TsoptionsTestUtil.baselineRun(f.testName + ".js", CommandlineparserTest.formatNewBaseline(f.commandLine, o, newBaselineFileNames, newBaselineErrors),
				"tsoptions/commandLineParsing");
		});
	}

	public function assertBuildParseResult():Void {
		final f = this;
		f.assertBuildParseResultWithTsBaseline(function():TestCommandLineParserBuild {
			final originalBaseline = TsoptionsTestUtil.readFile(f.baseline);
			if (originalBaseline == null) {
				T.fail("missing TS baseline " + f.baseline);
				return null;
			}
			return CommandlineparserTest.parseExistingCompilerBaselineBuild(originalBaseline);
		});
	}

	public function assertBuildParseResultWithTsBaseline(getTsBaseline:Null<() -> TestCommandLineParserBuild>):Void {
		final f = this;
		T.run(f.testName, () -> {
			var tsBaseline:TestCommandLineParserBuild = null;
			if (getTsBaseline != null) {
				tsBaseline = getTsBaseline();
				if (tsBaseline == null)
					return;
			}

			// f.workerDiagnostic is either defined or set to default pointer in `createSubScenario`
			final parsed = Tsoptions.ParseBuildCommandLine(f.commandLine,
				new VfsParseConfigHost(Osvfs.FS(), Tspath.NormalizeSlashes(TsoptionsTestUtil.TypeScriptSubmodulePath())));

			final newBaselineProjects = parsed.Projects.join(",");
			if (getTsBaseline != null) {
				T.eq(tsBaseline.projects, newBaselineProjects);
			}

			final o = Json.MarshalOrdered(TsoptionsTestUtil.buildOptionsJson(parsed.BuildOptions));
			final r = TsoptionsTestUtil.unmarshalBuildOptions(o);
			T.isTrue(r.err == null, Std.string(r.err));
			if (getTsBaseline != null) {
				final diff = TsoptionsTestUtil.buildOptionsDiff(tsBaseline.options, r.value);
				T.isTrue(diff == "", f.testName + ": build options differ: " + diff);
			}

			final compilerOpts = Json.MarshalOrdered(TsoptionsTestUtil.compilerOptionsJson(parsed.CompilerOptions));
			final r2 = TsoptionsTestUtil.unmarshalCompilerOptions(compilerOpts);
			T.isTrue(r2.err == null, Std.string(r2.err));
			if (getTsBaseline != null) {
				final diff = TsoptionsTestUtil.compilerOptionsDiff(tsBaseline.compilerOptions, r2.value);
				T.isTrue(diff == "", f.testName + ": compiler options differ: " + diff);
			}

			final e = Jsontext.Parse(o).err;
			T.isTrue(e == null, Std.string(e));

			// !!! useful for debugging but will not pass due to `none` as enum options
			// assert.DeepEqual(t, tsBaseline.watchoptions, newParsedWatchOptions)

			final formattedErrors = new StringWriter();
			final fo = new FormattingOptions();
			fo.NewLine = "\n";
			Diagnosticwriter.WriteFormatDiagnostics(formattedErrors, Diagnosticwriter.FromASTDiagnostics(parsed.Errors), fo);
			final newBaselineErrors = formattedErrors.toString();

			// !!!
			// useful for debugging--compares the new errors with the old errors. currently will NOT pass because of unimplemented options, not completely identical enum options, etc
			// assert.Equal(t, tsBaseline.errors, newBaselineErrors)

			TsoptionsTestUtil.baselineRun(f.testName + ".js",
				CommandlineparserTest.formatNewBaselineBuild(f.commandLine, o, compilerOpts, newBaselineProjects, newBaselineErrors), "tsoptions/commandLineParsing");
		});
	}
}

class VerifyNull {
	public var subScenario:String;
	public var optionName:String;
	public var nonNullValue:String;
	public var optDecls:Null<Array<CommandLineOption>>;

	public function new(subScenario:String, optionName:String, nonNullValue:String = "", ?optDecls:Array<CommandLineOption>) {
		this.subScenario = subScenario;
		this.optionName = optionName;
		this.nonNullValue = nonNullValue;
		this.optDecls = optDecls;
	}
}

// PORT: Go test type TestCommandLineParser (package tsoptions_test) clashes with the exported
// tsoptions.TestCommandLineParser (export_test.go) in one Haxe package; renamed with `_`.
class TestCommandLineParser_ {
	public var options:CompilerOptions = null;
	public var watchoptions:WatchOptions = null;
	public var fileNames:String = "";
	public var errors:String = "";

	public function new() {}
}

class TestCommandLineParserBuild {
	public var options:BuildOptions = null;
	public var compilerOptions:CompilerOptions = null;
	public var watchoptions:WatchOptions = null;
	public var projects:String = "";
	public var errors:String = "";

	public function new() {}
}
