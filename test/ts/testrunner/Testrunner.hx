package ts.testrunner;

// Port of internal/testrunner: package-level funcs and vars of test_case_parser.go, runner.go and
// compiler_runner.go (the types are in TestCaseParser.hx, Runner.hx and CompilerRunner.hx).
// PORT: the Go regexps are hand-written matchers (PORTING.md §7 prefers a hand loop); each one
// names its Go pattern.
@:allow(ts.testrunner)
class Testrunner {
	// --- test_case_parser.go ---

	// Go: lineDelimiter = regexp.MustCompile("\r?\n"), Split(code, -1).
	static function splitLines(code:String):Array<String> {
		final result:Array<String> = [];
		var start = 0;
		for (i in 0...code.length) {
			if (StringTools.fastCodeAt(code, i) == "\n".code) {
				var end = i;
				if (end > start && StringTools.fastCodeAt(code, end - 1) == "\r".code)
					end--;
				result.push(code.substring(start, end));
				start = i + 1;
			}
		}
		result.push(code.substring(start));
		return result;
	}

	static inline function isGoSpace(c:Int):Bool {
		return c == "\t".code || c == "\n".code || c == 0x0C || c == "\r".code || c == " ".code;
	}

	static inline function isWordChar(c:Int):Bool {
		return (c >= "0".code && c <= "9".code) || (c >= "A".code && c <= "Z".code) || (c >= "a".code && c <= "z".code) || c == "_".code;
	}

	// Regex for parsing options in the format "@Alpha: Value of any sort"
	// Go: optionRegex = regexp.MustCompile(`(?m)^\/{2}\s*@(\w+)\s*:\s*([^\r\n]*)`).
	// Matches at position `start` (which must be a `^` position); returns [end, name, value] or null.
	static function matchOptionAt(s:String, start:Int):Null<Array<Dynamic>> {
		var i = start;
		if (i + 2 > s.length || StringTools.fastCodeAt(s, i) != "/".code || StringTools.fastCodeAt(s, i + 1) != "/".code)
			return null;
		i += 2;
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		if (i >= s.length || StringTools.fastCodeAt(s, i) != "@".code)
			return null;
		i++;
		final nameStart = i;
		while (i < s.length && isWordChar(StringTools.fastCodeAt(s, i)))
			i++;
		if (i == nameStart)
			return null;
		final name = s.substring(nameStart, i);
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		if (i >= s.length || StringTools.fastCodeAt(s, i) != ":".code)
			return null;
		i++;
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		final valueStart = i;
		while (i < s.length && StringTools.fastCodeAt(s, i) != "\r".code && StringTools.fastCodeAt(s, i) != "\n".code)
			i++;
		return [i, name, s.substring(valueStart, i)];
	}

	// optionRegex.FindStringSubmatch(line): [match, name, value] or null.
	static function findOptionSubmatch(line:String):Null<Array<String>> {
		var i = 0;
		while (i <= line.length) {
			if (i == 0 || StringTools.fastCodeAt(line, i - 1) == "\n".code) {
				final m = matchOptionAt(line, i);
				if (m != null)
					return [line.substring(i, m[0]), m[1], m[2]];
			}
			i++;
		}
		return null;
	}

	// File-specific directives used by fourslash tests
	static final fourslashDirectives = ["emitthisfile"];

	// Given a test file containing // @FileName directives,
	// return an array of named units of code to be added to an existing compiler instance.
	static function makeUnitsFromTest(code:String, fileName:String):TestCaseContent {
		final r = ParseTestFilesAndSymlinks(code, fileName, function(filename:String, content:String, fileOptions:StringMap<String>):Pair<TestUnit, Error> {
			return new Pair(new TestUnit(content, filename), null);
		});
		var testUnits = r.units;
		final symlinks = r.symlinks;
		var currentDirectory = r.currentDir;

		if (currentDirectory == "") {
			currentDirectory = srcFolder;
		}

		// unit tests always list files explicitly
		final allFiles = new Map<String, String>();
		for (data in testUnits) {
			allFiles.set(Tspath.GetNormalizedAbsolutePath(data.name, currentDirectory), data.content);
		}
		final parseConfigHost = Tsoptionstest.NewVFSParseConfigHost(allFiles, currentDirectory, true /*useCaseSensitiveFileNames*/);

		// check if project has tsconfig.json in the list of files
		var tsConfig:ParsedCommandLine = null;
		var tsConfigFileUnitData:TestUnit = null;
		for (i in 0...testUnits.length) {
			final data = testUnits[i];
			if (Harnessutil.GetConfigNameFromFileName(data.name) != "") {
				final configFileName = Tspath.GetNormalizedAbsolutePath(data.name, currentDirectory);
				final path = Tspath.ToPath(data.name, parseConfigHost.GetCurrentDirectory(), parseConfigHost.Vfs.UseCaseSensitiveFileNames());
				final opts = new SourceFileParseOptions();
				opts.FileName = configFileName;
				opts.Path = path;
				final configJson = Parser.ParseSourceFile(opts, data.content, ScriptKindJSON);
				final tsConfigSourceFile = new TsConfigSourceFile(configJson);
				final configDir = Tspath.GetDirectoryPath(configFileName);
				tsConfig = Tsoptions.ParseJsonSourceFileConfigFileContent(tsConfigSourceFile, parseConfigHost, configDir, null, /*existingOptions*/
					null, /*existingOptionsRaw*/ configFileName, null, /*resolutionStack*/ null, /*extraFileExtensions*/ null /*extendedConfigCache*/);
				tsConfigFileUnitData = data;

				// delete tsconfig file entry from the list
				testUnits = testUnits.slice(0, i).concat(testUnits.slice(i + 1));
				break;
			}
		}

		final c = new TestCaseContent();
		c.testUnitData = testUnits;
		c.tsConfig = tsConfig;
		c.tsConfigFileUnitData = tsConfigFileUnitData;
		c.symlinks = symlinks;
		return c;
	}

	// Given a test file containing // @FileName and // @symlink directives,
	// return an array of named units of code to be added to an existing compiler instance,
	// along with a map of symlinks and the current directory.
	public static function ParseTestFilesAndSymlinks<X>(code:String, fileName:String,
			parseFile:(filename:String, content:String, fileOptions:StringMap<String>) -> Pair<X, Error>):ParseTestFilesResult<X> {
		return ParseTestFilesAndSymlinksWithOptions(code, fileName, parseFile, new ParseTestFilesOptions());
	}

	public static function ParseTestFilesAndSymlinksWithOptions<X>(code:String, fileName:String,
			parseFile:(filename:String, content:String, fileOptions:StringMap<String>) -> Pair<X, Error>,
			options:ParseTestFilesOptions):ParseTestFilesResult<X> {
		// List of all the subfiles we've parsed out
		final testUnits:Array<X> = [];

		final lines = splitLines(code);

		// Stuff related to the subfile we're parsing
		var currentFileContent = new go.Strings.Builder();
		var currentFileName = "";
		var seenContentLine = false;
		var hasSeenFile = false;
		if (options.AllowImplicitFirstFile) {
			// For fourslash tests, initialize currentFileName to the fileName parameter
			// so content before the first @Filename directive goes into an implicit first file
			currentFileName = fileName;
		}
		var currentDirectory = "";
		var parseError:Error = null;
		var currentFileOptions = new StringMap<String>();
		final symlinks = new StringMap<String>();
		final globalOptions = new StringMap<String>();

		for (line in lines) {
			final ok = parseSymlinkFromTest(line, symlinks);
			if (ok) {
				continue;
			}
			final testMetaData = findOptionSubmatch(line);
			if (testMetaData != null) {
				// Comment line, check for global/file @options and record them
				final metaDataName = testMetaData[1].toLowerCase();
				final metaDataValue = Strings.TrimSpace(testMetaData[2]);
				if (metaDataName == "currentdirectory") {
					currentDirectory = metaDataValue;
				}
				if (metaDataName != "filename") {
					if (metaDataName == "symlink" && currentFileName != "") {
						for (link0 in metaDataValue.split(",")) {
							final link = Strings.TrimSpace(link0);
							if (link != "") {
								symlinks.set(link, currentFileName);
							}
						}
					} else if (fourslashDirectives.indexOf(metaDataName) >= 0) {
						// File-specific option
						currentFileOptions.set(metaDataName, metaDataValue);
					} else {
						// Global option
						if (globalOptions.exists(metaDataName) && globalOptions.get(metaDataName) != metaDataValue) {
							// !!! This would break existing submodule tests
							// panic("Duplicate global option: " + metaDataName)
						}
						globalOptions.set(metaDataName, metaDataValue);
					}
					continue;
				}

				// New metadata statement after having collected some code to go with the previous metadata
				if (currentFileName != "") {
					// Store result file - always save for regular tests, but skip empty implicit first file for fourslash
					final shouldSaveFile = !options.AllowImplicitFirstFile || currentFileContent.Len() != 0 || hasSeenFile;
					if (shouldSaveFile) {
						hasSeenFile = true;
						final r = parseFile(currentFileName, currentFileContent.String(), currentFileOptions);
						if (r.b != null) {
							parseError = r.b;
							break;
						}
						testUnits.push(r.a);
					}

					// Reset local data
					currentFileContent = new go.Strings.Builder();
					seenContentLine = false;
					currentFileName = metaDataValue;
					currentFileOptions = new StringMap<String>();
				} else {
					// First metadata marker in the file
					final hasContentBeforeFirstFilename = currentFileContent.Len() != 0
						&& Scanner.SkipTrivia(currentFileContent.String(), 0) != currentFileContent.Len();
					if (hasContentBeforeFirstFilename && !options.AllowImplicitFirstFile) {
						throw "Non-comment test content appears before the first '// @Filename' directive";
					}

					// If we have content before the first @Filename and AllowImplicitFirstFile is true,
					// we need to save it as an implicit first file before starting the new file
					if (hasContentBeforeFirstFilename && options.AllowImplicitFirstFile && currentFileName != "") {
						// Store the implicit first file
						hasSeenFile = true;
						final r = parseFile(currentFileName, currentFileContent.String(), currentFileOptions);
						if (r.b != null) {
							parseError = r.b;
							break;
						}
						testUnits.push(r.a);
					}

					// Reset for the new file
					currentFileContent = new go.Strings.Builder();
					seenContentLine = false;
					currentFileName = Strings.TrimSpace(testMetaData[2]);
					currentFileOptions = new StringMap<String>();
				}
			} else {
				// Subfile content line
				// Append to the current subfile content, inserting a newline if needed
				// For fourslash tests, use seenContentLine to preserve leading blank lines
				// (matching TS fourslash's //// content markers). For compiler tests, use
				// Len() != 0 which drops leading blanks (matching TS's harness behavior).
				if (options.AllowImplicitFirstFile) {
					if (seenContentLine) {
						currentFileContent.WriteString("\n");
					}
					seenContentLine = true;
				} else {
					if (currentFileContent.Len() != 0) {
						currentFileContent.WriteString("\n");
					}
				}
				currentFileContent.WriteString(line);
			}
		}

		// normalize the fileName for the single file case
		if (testUnits.length == 0 && currentFileName.length == 0) {
			currentFileName = Tspath.GetBaseFileName(fileName);
		}

		// if there are no parse errors so far, parse the rest of the file
		if (parseError == null) {
			// EOF, push whatever remains
			final r = parseFile(currentFileName, currentFileContent.String(), currentFileOptions);

			parseError = r.b;
			testUnits.push(r.a);
		}

		return new ParseTestFilesResult(testUnits, symlinks, currentDirectory, globalOptions, parseError);
	}

	static function extractCompilerSettings(content:String):RawCompilerSettings {
		final opts = new StringMap<String>();

		// optionRegex.FindAllStringSubmatch(content, -1)
		var i = 0;
		while (i <= content.length) {
			if (i == 0 || StringTools.fastCodeAt(content, i - 1) == "\n".code) {
				final m = matchOptionAt(content, i);
				if (m != null) {
					opts.set((m[1] : String).toLowerCase(), Strings.TrimSuffix(Strings.TrimSpace(m[2]), ";"));
					i = m[0];
					if (i == content.length)
						break;
					continue;
				}
			}
			i++;
		}

		return opts;
	}

	// Regex for parsing @link option
	// Go: linkRegex = regexp.MustCompile(`(?m)^\/{2}\s*@link\s*:\s*([^\r\n]*)\s*->\s*([^\r\n]*)`).
	static function parseSymlinkFromTest(line:String, symlinks:StringMap<String>):Bool {
		final linkMetaData = findLinkSubmatch(line);
		if (linkMetaData == null) {
			return false;
		}

		symlinks.set(Strings.TrimSpace(linkMetaData[2]), Strings.TrimSpace(linkMetaData[1]));
		return true;
	}

	// linkRegex.FindStringSubmatch(line) for a line without "\n": [match, group1, group2] or null.
	// PORT: hand matcher; `\s*` after the colon is taken greedily and group 1 backtracks to the last
	// `\s*->` on the line (leftmost-first semantics). Lines with a lone "\r" before the arrow are not handled.
	static function findLinkSubmatch(s:String):Null<Array<String>> {
		var i = 0;
		if (s.length < 2 || StringTools.fastCodeAt(s, 0) != "/".code || StringTools.fastCodeAt(s, 1) != "/".code)
			return null;
		i = 2;
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		if (s.substr(i, 5) != "@link")
			return null;
		i += 5;
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		if (i >= s.length || StringTools.fastCodeAt(s, i) != ":".code)
			return null;
		i++;
		while (i < s.length && isGoSpace(StringTools.fastCodeAt(s, i)))
			i++;
		final g1Start = i;
		var g1MaxEnd = i;
		while (g1MaxEnd < s.length && StringTools.fastCodeAt(s, g1MaxEnd) != "\r".code && StringTools.fastCodeAt(s, g1MaxEnd) != "\n".code)
			g1MaxEnd++;
		var k = g1MaxEnd;
		while (k >= g1Start) {
			var j = k;
			while (j < s.length && isGoSpace(StringTools.fastCodeAt(s, j)))
				j++;
			if (j + 2 <= s.length && StringTools.fastCodeAt(s, j) == "-".code && StringTools.fastCodeAt(s, j + 1) == ">".code) {
				j += 2;
				while (j < s.length && isGoSpace(StringTools.fastCodeAt(s, j)))
					j++;
				final g2Start = j;
				while (j < s.length && StringTools.fastCodeAt(s, j) != "\r".code && StringTools.fastCodeAt(s, j) != "\n".code)
					j++;
				return [s.substring(0, j), s.substring(g1Start, k), s.substring(g2Start, j)];
			}
			k--;
		}
		return null;
	}

	// --- runner.go ---

	static function runTests(t:T, runners:Array<Runner>):Void {
		for (runner in runners) {
			runner.RunTests(t);
		}
	}

	// --- compiler_runner.go ---

	// Go: compilerBaselineRegex = regexp.MustCompile(`\.tsx?$`)
	static function compilerBaselineRegex(path:String):Bool {
		return StringTools.endsWith(path, ".ts") || StringTools.endsWith(path, ".tsx");
	}

	static inline final requireStr = "require(";

	// Go: referencesRegex = regexp.MustCompile(`reference\spath`)
	static function referencesRegexMatch(s:String):Bool {
		var i = s.indexOf("reference");
		while (i >= 0) {
			final j = i + "reference".length;
			if (j + 5 <= s.length && isGoSpace(StringTools.fastCodeAt(s, j)) && s.substr(j + 1, 4) == "path")
				return true;
			i = s.indexOf("reference", i + 1);
		}
		return false;
	}

	// Posix-style path to sources under test
	static inline final srcFolder = "/.src";

	public static function NewCompilerBaselineRunner(testType:CompilerTestType, isSubmodule:Bool):CompilerBaselineRunner {
		final testSuitName = testType.String();
		var basePath:String;
		if (isSubmodule) {
			basePath = "../_submodules/TypeScript/tests/cases/" + testSuitName;
		} else {
			basePath = "tests/cases/" + testSuitName;
		}
		final r = new CompilerBaselineRunner();
		r.basePath = basePath;
		r.testSuitName = testSuitName;
		r.isSubmodule = isSubmodule;
		return r;
	}

	public static final skippedTests = [
		// Tests that depended on typescript.d.ts in built.
		"APILibCheck.ts",
		"APISample_Watch.ts",
		"APISample_WatchWithDefaults.ts",
		"APISample_WatchWithOwnWatchHost.ts",
		"APISample_compile.ts",
		"APISample_jsdoc.ts",
		"APISample_linter.ts",
		"APISample_parseConfig.ts",
		"APISample_transform.ts",
		"APISample_watcher.ts",

		// These tests contain options that have been completely removed, so fail to parse.
		"preserveUnusedImports.ts",
		"noCrashWithVerbatimModuleSyntaxAndImportsNotUsedAsValues.ts",
		"verbatimModuleSyntaxCompat.ts",
		"verbatimModuleSyntaxCompat2.ts",
		"verbatimModuleSyntaxCompat3.ts",
		"verbatimModuleSyntaxCompat4.ts",
		"preserveValueImports.ts",
		"preserveValueImports_importsNotUsedAsValues.ts",
		"preserveValueImports_errors.ts",
		"preserveValueImports_mixedImports.ts",
		"preserveValueImports_module.ts",
		"importsNotUsedAsValues_error.ts",
		"alwaysStrictNoImplicitUseStrict.ts",
		"nonPrimitiveIndexingWithForInSupressError.ts",
		"parameterInitializerBeforeDestructuringEmit.ts",
		"mappedTypeUnionConstraintInferences.ts",
		"lateBoundConstraintTypeChecksCorrectly.ts",
		"keyofDoesntContainSymbols.ts",
		"isolatedModulesOut.ts",
		"noStrictGenericChecks.ts",
		"noImplicitUseStrict_umd.ts",
		"noImplicitUseStrict_system.ts",
		"noImplicitUseStrict_es6.ts",
		"noImplicitUseStrict_commonjs.ts",
		"noImplicitUseStrict_amd.ts",
		"noImplicitAnyIndexingSuppressed.ts",
		"excessPropertyErrorsSuppressed.ts",
		"moduleNoneDynamicImport.ts",
		"moduleNoneErrors.ts",
		"moduleNoneOutFile.ts",
		"noErrorUsingImportExportModuleAugmentationInDeclarationFile1.ts",
		"noErrorUsingImportExportModuleAugmentationInDeclarationFile2.ts",
		"noErrorUsingImportExportModuleAugmentationInDeclarationFile3.ts",
		"requireOfJsonFileWithModuleEmitNone.ts",
		"requireOfJsonFileWithModuleNodeResolutionEmitNone.ts",
	];

	// Set of compiler options for which we allow variations to be specified in the test file,
	// for instance `// @strict: true, false`.
	static var compilerVaryBy(get, never):StringMap<Bool>;
	static var compilerVaryByValue:StringMap<Bool> = null;

	static function get_compilerVaryBy():StringMap<Bool> {
		if (compilerVaryByValue == null)
			compilerVaryByValue = getCompilerVaryByMap();
		return compilerVaryByValue;
	}

	static function getCompilerVaryByMap():StringMap<Bool> {
		final varyByOptions = Core.Map(Core.Filter(Tsoptions.OptionsDeclarations, function(option:CommandLineOption):Bool {
			return !option.IsCommandLineOnly
				&& (option.Kind == CommandLineOptionTypeBoolean || option.Kind == CommandLineOptionTypeEnum)
				&& (option.AffectsProgramStructure
					|| option.AffectsEmit
					|| option.AffectsModuleResolution
					|| option.AffectsBindDiagnostics
					|| option.AffectsSemanticDiagnostics
					|| option.AffectsSourceFile
					|| option.AffectsDeclarationPath
					|| option.AffectsBuildInfo);
		}), function(option:CommandLineOption) return option.Name);
		// explicit variations that do not match above conditions
		varyByOptions.push("noEmit");
		varyByOptions.push("isolatedModules");
		final varyByMap = new StringMap<Bool>();
		for (option in varyByOptions) {
			varyByMap.set(option.toLowerCase(), true);
		}
		return varyByMap;
	}

	public static function getCompilerFileBasedTest(t:T, filename:String):CompilerFileBasedTest {
		final r = ts.vfs.osvfs.Osvfs.FS().ReadFile(filename);
		if (!r.ok) {
			throw "Could not read test file: " + filename;
		}
		final content = r.value;
		final settings = extractCompilerSettings(content);
		final configurations = Harnessutil.GetFileBasedTestConfigurations(t, settings, compilerVaryBy);
		final r = new CompilerFileBasedTest();
		r.filename = filename;
		r.content = content;
		r.configurations = configurations;
		return r;
	}

	static function newCompilerTest(t:T, testName:String, filename:String, testContent:TestCaseContent,
			namedConfiguration:NamedTestConfiguration):CompilerTest {
		final basename = Tspath.GetBaseFileName(filename);
		var configuredName = basename;
		if (namedConfiguration != null && namedConfiguration.Name != "") {
			final extname = Tspath.GetAnyExtensionFromPath(basename, null, false);
			final extensionlessBasename = basename.substring(0, basename.length - extname.length);
			configuredName = Fmt.Sprintf("%s(%s)%s", [extensionlessBasename, namedConfiguration.Name, extname]);
		}

		var configuration:TestConfiguration = null;
		if (namedConfiguration != null) {
			configuration = namedConfiguration.Config;
		}
		final testCaseContentWithConfig = new TestCaseContentWithConfig();
		testCaseContentWithConfig.testCaseContent = testContent.copy();
		testCaseContentWithConfig.configuration = configuration;

		final harnessConfig = testCaseContentWithConfig.configuration;
		final currentDirectory = Tspath.GetNormalizedAbsolutePath(mapGet(harnessConfig, "currentdirectory"), srcFolder);

		final units = testCaseContentWithConfig.testCaseContent.testUnitData;
		var toBeCompiled:Array<TestFile> = null;
		var otherFiles:Array<TestFile> = null;
		var tsConfig:ParsedCommandLine = null;
		final hasNonDtsFiles = Core.Some(units, function(unit:TestUnit) return !Tspath.FileExtensionIs(unit.name, Tspath.ExtensionDts));
		var tsConfigFiles:Array<TestFile> = null;
		if (testCaseContentWithConfig.testCaseContent.tsConfig != null) {
			tsConfig = testCaseContentWithConfig.testCaseContent.tsConfig;
			tsConfigFiles = [createHarnessTestFile(testCaseContentWithConfig.testCaseContent.tsConfigFileUnitData, currentDirectory)];
			for (unit in units) {
				if (Slices.Contains(tsConfig.ParsedConfig.FileNames, Tspath.GetNormalizedAbsolutePath(unit.name, currentDirectory))) {
					if (toBeCompiled == null)
						toBeCompiled = [];
					toBeCompiled.push(createHarnessTestFile(unit, currentDirectory));
				} else {
					if (otherFiles == null)
						otherFiles = [];
					otherFiles.push(createHarnessTestFile(unit, currentDirectory));
				}
			}
		} else {
			if (harnessConfig != null && harnessConfig.exists("baseurl")) {
				final baseUrl = harnessConfig.get("baseurl");
				if (!Tspath.IsRootedDiskPath(baseUrl)) {
					harnessConfig.set("baseurl", Tspath.GetNormalizedAbsolutePath(baseUrl, currentDirectory));
				}
			}

			final lastUnit = units[units.length - 1];
			// We need to assemble the list of input files for the compiler and other related files on the 'filesystem' (ie in a multi-file test)
			// If the last file in a test uses require or a triple slash reference we'll assume all other files will be brought in via references,
			// otherwise, assume all files are just meant to be in the same compilation session without explicit references to one another.

			if (mapGet(testCaseContentWithConfig.configuration, "noimplicitreferences") != ""
				|| lastUnit.content.indexOf(requireStr) >= 0
				|| referencesRegexMatch(lastUnit.content)) {
				toBeCompiled = [createHarnessTestFile(lastUnit, currentDirectory)];
				for (unit in units.slice(0, units.length - 1)) {
					if (otherFiles == null)
						otherFiles = [];
					otherFiles.push(createHarnessTestFile(unit, currentDirectory));
				}
			} else {
				toBeCompiled = Core.Map(units, function(unit:TestUnit) return createHarnessTestFile(unit, currentDirectory));
			}
		}

		final result = Harnessutil.CompileFiles(t, toBeCompiled == null ? [] : toBeCompiled, otherFiles == null ? [] : otherFiles, harnessConfig, tsConfig,
			currentDirectory, testCaseContentWithConfig.testCaseContent.symlinks);

		final c = new CompilerTest();
		c.testName = testName;
		c.filename = filename;
		c.basename = basename;
		c.configuredName = configuredName;
		c.options = result.Options;
		c.harnessOptions = result.HarnessOptions;
		c.result = result;
		c.tsConfigFiles = tsConfigFiles;
		c.toBeCompiled = toBeCompiled;
		c.otherFiles = otherFiles;
		c.hasNonDtsFiles = hasNonDtsFiles;
		return c;
	}

	// Go: m[key] on a possibly-nil map[string]string ("" when absent).
	static function mapGet(m:StringMap<String>, key:String):String {
		if (m == null)
			return "";
		final v = m.get(key);
		return v == null ? "" : v;
	}

	public static final skippedEmitTests:Map<String, String> = [
		"filesEmittingIntoSameOutput.ts" => "Output order nondeterministic due to collision on filename during parallel emit.",
		"jsFileCompilationWithJsEmitPathSameAsInput.ts" => "Output order nondeterministic due to collision on filename during parallel emit.",
		"grammarErrors.ts" => "Output order nondeterministic due to collision on filename during parallel emit.",
		"jsFileCompilationEmitBlockedCorrectly.ts" => "Output order nondeterministic due to collision on filename during parallel emit.",
		"jsDeclarationsReexportAliasesEsModuleInterop.ts" => "cls.d.ts is missing statements when run concurrently.",
		"jsFileCompilationWithoutJsExtensions.ts" => "No files are emitted.",
		"typeOnlyMerge2.ts" => "Nondeterministic contents when run concurrently.",
		"typeOnlyMerge3.ts" => "Nondeterministic contents when run concurrently.",
	];

	static function createHarnessTestFile(unit:TestUnit, currentDirectory:String):TestFile {
		return new TestFile(Tspath.GetNormalizedAbsolutePath(unit.name, currentDirectory), unit.content);
	}
}
