package ts.tsoptions;

import ts.tsoptions.TsoptionsTestUtil.StringWriter;
import ts.scanner.Scanner;

// Port of tsconfigparsing_test.go.
class TsconfigparsingTest {
	// PORT: the Go test tables (backquoted strings in Go) are generated from tsconfigparsing_test.go
	// with the exact text; Go map literals → Haxe map literals (order does not matter: the file
	// system is printed sorted).
	static final parseConfigFileTextToJsonTests:Array<ParseConfigFileTextToJsonTest> = [
		new ParseConfigFileTextToJsonTest("returns empty config for file with only whitespaces", ["", " "]),
		new ParseConfigFileTextToJsonTest("returns empty config for file with comments only", ["// Comment", "/* Comment*/"]),
		new ParseConfigFileTextToJsonTest("returns empty config when config is empty object", ["{}"]),
		new ParseConfigFileTextToJsonTest("returns config object without comments", ["{ // Excluded files\n            \"exclude\": [\n                // Exclude d.ts\n                \"file.d.ts\"\n            ]\n        }", "{\n            /* Excluded\n                    Files\n            */\n            \"exclude\": [\n                /* multiline comments can be in the middle of a line */\"file.d.ts\"\n            ]\n        }"]),
		new ParseConfigFileTextToJsonTest("keeps string content untouched", ["{\n            \"exclude\": [\n                \"xx//file.d.ts\"\n            ]\n        }", "{\n            \"exclude\": [\n                \"xx/*file.d.ts*/\"\n            ]\n        }"]),
		new ParseConfigFileTextToJsonTest("handles escaped characters in strings correctly", ["{\n            \"exclude\": [\n                \"xx\\\"//files\"\n            ]\n        }", "{\n            \"exclude\": [\n                \"xx\\\\\" // end of line comment\n            ]\n        }"]),
		new ParseConfigFileTextToJsonTest("returns object when users correctly specify library", ["{\n            \"compilerOptions\": {\n                \"lib\": [\"es5\"]\n            }\n        }", "{\n            \"compilerOptions\": {\n                \"lib\": [\"es5\", \"es6\"]\n            }\n        }"]),
	];

	static var parseJsonConfigFileTests(get, never):Array<ParseJsonConfigTestCase>;
	static function get_parseJsonConfigFileTests():Array<ParseJsonConfigTestCase> return [
		new ParseJsonConfigTestCase("ignore dotted files and folders", false, [
			new TestConfig("{}", "tsconfig.json", "/apath", [
				"/apath/test.ts" => "",
				"/apath/.git/a.ts" => "",
				"/apath/.b.ts" => "",
				"/apath/..c.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("allow dotted files and folders when explicitly requested", false, [
			new TestConfig("{\n                    \"files\": [\"/apath/.git/a.ts\", \"/apath/.b.ts\", \"/apath/..c.ts\"]\n                }", "tsconfig.json", "/apath", [
				"/apath/test.ts" => "",
				"/apath/.git/a.ts" => "",
				"/apath/.b.ts" => "",
				"/apath/..c.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("implicitly exclude common package folders", false, [
			new TestConfig("{}", "tsconfig.json", "/", [
				"/node_modules/a.ts" => "",
				"/bower_components/b.ts" => "",
				"/jspm_packages/c.ts" => "",
				"/d.ts" => "",
				"/folder/e.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for empty files list", false, [
			new TestConfig("{\n                \"files\": []\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for empty files list when no references are provided", false, [
			new TestConfig("{\n                \"files\": [],\n                \"references\": []\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for directory with no .ts files", false, [
			new TestConfig("{\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/a.js" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for empty include", false, [
			new TestConfig("{\n                \"include\": []\n            }", "/apath/tsconfig.json", "tests/cases/unittests", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for include with parent directory after recursive wildcard", false, [
			new TestConfig("{\n                \"include\": [\"**/../*.ts\"]\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/main.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("parses tsconfig with compilerOptions, files, include, and exclude", true, [
			new TestConfig("{\n  \"compilerOptions\": {\n    \"outDir\": \"./dist\",\n    \"strict\": true,\n    \"noImplicitAny\": true,\n    \"target\": \"ES2017\",\n    \"module\": \"ESNext\",\n    \"moduleResolution\": \"bundler\",\n    \"moduleDetection\": \"auto\",\n    \"jsx\": \"react\",\n\t\"maxNodeModuleJsDepth\": 1,\n\t\"paths\": {\n      \"jquery\": [\"./vendor/jquery/dist/jquery\"]\n    }\n  },\n  \"files\": [\"/apath/src/index.ts\", \"/apath/src/app.ts\"],\n  \"include\": [\"/apath/src/**/*\"],\n  \"exclude\": [\"/apath/node_modules\", \"/apath/dist\"]\n}", "/apath/tsconfig.json", "/apath", [
				"/apath/src/index.ts" => "",
				"/apath/src/app.ts" => "",
				"/apath/node_modules/module.ts" => "",
				"/apath/dist/output.js" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors when commandline option is in tsconfig", false, [
			new TestConfig("{\n  \"compilerOptions\": {\n    \"help\": true\n  }\n}", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("does not generate errors for empty files list when one or more references are provided", false, [
			new TestConfig("{\n                \"files\": [],\n                \"references\": [{ \"path\": \"/apath\" }]\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("exclude outDir unless overridden", false, [
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"outDir\": \"bin\"\n                }\n            }", "tsconfig.json", "/", [
				"/bin/a.ts" => "",
				"/b.ts" => "",
			]),
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"outDir\": \"bin\"\n                },\n                \"exclude\": [ \"obj\" ]\n            }", "tsconfig.json", "/", [
				"/bin/a.ts" => "",
				"/b.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("exclude declarationDir unless overridden", false, [
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"declarationDir\": \"declarations\"\n                }\n            }", "tsconfig.json", "/", [
				"/declarations/a.d.ts" => "",
				"/a.ts" => "",
			]),
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"declarationDir\": \"declarations\"\n                },\n                \"exclude\": [ \"types\" ]\n            }", "tsconfig.json", "/", [
				"/declarations/a.d.ts" => "",
				"/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors for empty directory", false, [
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"allowJs\": true\n                }\n            }", "/apath/tsconfig.json", "/apath", new Map<String, String>())
		]),
		new ParseJsonConfigTestCase("generates errors for includes with outDir", false, [
			new TestConfig("{\n                \"compilerOptions\": {\n                    \"outDir\": \"./\"\n                },\n                \"include\": [\"**/*\"]\n            }", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors when include is not string", false, [
			new TestConfig("{\n  \"include\": [\n    [\n      \"./**/*.ts\"\n    ]\n  ]\n}", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("generates errors when files is not string", false, [
			new TestConfig("{\n  \"files\": [\n    {\n      \"compilerOptions\": {\n        \"experimentalDecorators\": true,\n        \"allowJs\": true\n      }\n    }\n  ]\n}", "/apath/tsconfig.json", "/apath", [
				"/apath/a.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("with outDir from base tsconfig", false, [
			new TestConfig("{\n  \"extends\": \"./tsconfigWithoutConfigDir.json\"\n}", "tsconfig.json", "/", [
				"/tsconfigWithoutConfigDir.json" => tsconfigWithoutConfigDir,
				"/bin/a.ts" => "",
				"/b.ts" => "",
			]),
			new TestConfig("{\n  \"extends\": \"./tsconfigWithConfigDir.json\"\n}", "tsconfig.json", "/", [
				"/tsconfigWithConfigDir.json" => tsconfigWithConfigDir,
				"/bin/a.ts" => "",
				"/b.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("returns error when tsconfig have excludes", false, [
			new TestConfig("{\n                    \"compilerOptions\": {\n                        \"lib\": [\"es5\"]\n                    },\n                    \"excludes\": [\n                        \"foge.ts\"\n                    ]\n                }", "tsconfig.json", "/apath", [
				"/apath/test.ts" => "",
				"/apath/foge.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("parses tsconfig with extends, files, include and other options", true, [
			new TestConfig("{\n\t\t\t\t\"extends\": \"./tsconfigWithExtends.json\",\n\t\t\t\t\"compilerOptions\": {\n\t\t\t\t    \"outDir\": \"./dist\",\n    \t\t\t\t\"strict\": true,\n    \t\t\t\t\"noImplicitAny\": true,\n\t\t\t\t\t\"baseUrl\": \"\",\n\t\t\t\t},\n\t\t\t}", "tsconfig.json", "/", [
				"/tsconfigWithExtends.json" => tsconfigWithExtends,
				"/src/index.ts" => "",
				"/src/app.ts" => "",
				"/node_modules/module.ts" => "",
				"/dist/output.js" => "",
			])
		]),
		new ParseJsonConfigTestCase("parses tsconfig with extends and configDir", true, [
			new TestConfig("{\n\t\t\t\t\"extends\": \"./tsconfig.base.json\"\n\t\t\t}", "tsconfig.json", "/", [
				"/tsconfig.base.json" => tsconfigWithExtendsAndConfigDir,
				"/src/index.ts" => "",
				"/src/app.ts" => "",
				"/node_modules/module.ts" => "",
				"/dist/output.js" => "",
			])
		]),
		new ParseJsonConfigTestCase("reports error for an unknown option", false, [
			new TestConfig("{\n\t\t\t    \"compilerOptions\": {\n\t\t\t\t\"unknown\": true\n\t\t\t    }\n\t\t\t}", "tsconfig.json", "/", [
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("reports errors for wrong type option and invalid enum value", false, [
			new TestConfig("{\n\t\t\t    \"compilerOptions\": {\n\t\t\t\t\"target\": \"invalid value\",\n\t\t\t\t\"removeComments\": \"should be a boolean\",\n\t\t\t\t\"moduleResolution\": \"invalid value\"\n\t\t\t    }\n\t\t\t}", "tsconfig.json", "/", [
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("reports errors for incorrectly cased option names", true, [
			new TestConfig("{\n\t\t\t    \"compilerOptions\": {\n\t\t\t\t\"sourcemap\": true,\n\t\t\t\t\"declarationmap\": true,\n\t\t\t\t\"nouncheckedindexedaccess\": true,\n\t\t\t\t\"exactoptionalpropertytypes\": true,\n\t\t\t\t\"verbatimmodulesyntax\": true,\n\t\t\t\t\"isolatedmodules\": true,\n\t\t\t\t\"nouncheckedsideeffectimports\": true,\n\t\t\t\t\"moduledetection\": \"force\",\n\t\t\t\t\"skiplibcheck\": true,\n\t\t\t\t\"checkjs\": true\n\t\t\t    }\n\t\t\t}", "tsconfig.json", "/", [
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("handles empty types array", true, [
			new TestConfig("{\n\t\t\t    \"compilerOptions\": {\n\t\t\t\t\t\"types\": []\n\t\t\t\t}\n\t\t\t}", "tsconfig.json", "/", [
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("issue 1267 scenario - extended files not picked up", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-base/backend.json\",\n  \"compilerOptions\": {\n    \"baseUrl\": \"./\",\n    \"outDir\": \"dist\",\n    \"rootDir\": \"src\",\n    \"resolveJsonModule\": true\n  },\n  \"exclude\": [\"node_modules\", \"dist\"],\n  \"include\": [\"src/**/*\"]\n}", "tsconfig.json", "/", [
				"/tsconfig-base/backend.json" => "{\n  \"$schema\": \"https://json.schemastore.org/tsconfig\",\n  \"display\": \"Backend\",\n  \"compilerOptions\": {\n    \"allowJs\": true,\n    \"module\": \"nodenext\",\n    \"removeComments\": true,\n    \"emitDecoratorMetadata\": true,\n    \"experimentalDecorators\": true,\n    \"allowSyntheticDefaultImports\": true,\n    \"target\": \"esnext\",\n    \"lib\": [\"ESNext\"],\n    \"incremental\": false,\n    \"esModuleInterop\": true,\n    \"noImplicitAny\": true,\n    \"moduleResolution\": \"nodenext\",\n    \"types\": [\"node\", \"vitest/globals\"],\n    \"sourceMap\": true,\n    \"strictPropertyInitialization\": false\n  },\n  \"files\": [\n    \"types/ical2json.d.ts\",\n    \"types/express.d.ts\",\n    \"types/multer.d.ts\",\n    \"types/reset.d.ts\",\n    \"types/stripe-custom-typings.d.ts\",\n    \"types/nestjs-modules.d.ts\",\n    \"types/luxon.d.ts\",\n    \"types/nestjs-pino.d.ts\"\n  ],\n  \"ts-node\": {\n    \"files\": true\n  }\n}",
				"/tsconfig-base/types/ical2json.d.ts" => "export {}",
				"/tsconfig-base/types/express.d.ts" => "export {}",
				"/tsconfig-base/types/multer.d.ts" => "export {}",
				"/tsconfig-base/types/reset.d.ts" => "export {}",
				"/tsconfig-base/types/stripe-custom-typings.d.ts" => "export {}",
				"/tsconfig-base/types/nestjs-modules.d.ts" => "export {}",
				"/tsconfig-base/types/luxon.d.ts" => "declare module 'luxon' {\n  interface TSSettings {\n    throwOnInvalid: true\n  }\n}\nexport {}",
				"/tsconfig-base/types/nestjs-pino.d.ts" => "export {}",
				"/src/main.ts" => "export {}",
				"/src/utils.ts" => "export {}",
			])
		]),
		new ParseJsonConfigTestCase("null overrides in extended tsconfig - array fields", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-base.json\",\n  \"compilerOptions\": {\n    \"types\": null,\n    \"lib\": null,\n    \"typeRoots\": null\n  }\n}", "tsconfig.json", "/", [
				"/tsconfig-base.json" => "{\n  \"compilerOptions\": {\n    \"types\": [\"node\", \"@types/jest\"],\n    \"lib\": [\"es2020\", \"dom\"],\n    \"typeRoots\": [\"./types\", \"./node_modules/@types\"]\n  }\n}",
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("null overrides in extended tsconfig - string fields", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-base.json\",\n  \"compilerOptions\": {\n    \"outDir\": null,\n    \"baseUrl\": null,\n    \"rootDir\": null\n  }\n}", "tsconfig.json", "/", [
				"/tsconfig-base.json" => "{\n  \"compilerOptions\": {\n    \"outDir\": \"./dist\",\n    \"baseUrl\": \"./src\",\n    \"rootDir\": \"./src\"\n  }\n}",
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("null overrides in extended tsconfig - mixed field types", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-base.json\",\n  \"compilerOptions\": {\n    \"types\": null,\n    \"outDir\": null,\n    \"strict\": false,\n    \"lib\": [\"es2022\"],\n    \"allowJs\": null\n  }\n}", "tsconfig.json", "/", [
				"/tsconfig-base.json" => "{\n  \"compilerOptions\": {\n    \"types\": [\"node\"],\n    \"lib\": [\"es2020\", \"dom\"],\n    \"outDir\": \"./dist\",\n    \"strict\": true,\n    \"allowJs\": true,\n    \"target\": \"es2020\"\n  }\n}",
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("null overrides with multiple extends levels", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-middle.json\",\n  \"compilerOptions\": {\n    \"types\": null,\n    \"lib\": null\n  }\n}", "tsconfig.json", "/", [
				"/tsconfig-middle.json" => "{\n  \"extends\": \"./tsconfig-base.json\",\n  \"compilerOptions\": {\n    \"types\": [\"jest\"],\n    \"outDir\": \"./build\"\n  }\n}",
				"/tsconfig-base.json" => "{\n  \"compilerOptions\": {\n    \"types\": [\"node\"],\n    \"lib\": [\"es2020\"],\n    \"outDir\": \"./dist\",\n    \"strict\": true\n  }\n}",
				"/app.ts" => "",
			])
		]),
		new ParseJsonConfigTestCase("null overrides in middle level of extends chain", true, [
			new TestConfig("{\n  \"extends\": \"./tsconfig-middle.json\",\n  \"compilerOptions\": {\n    \"outDir\": \"./final\"\n  }\n}", "tsconfig.json", "/", [
				"/tsconfig-middle.json" => "{\n  \"extends\": \"./tsconfig-base.json\",\n  \"compilerOptions\": {\n    \"types\": null,\n    \"lib\": null,\n    \"outDir\": \"./middle\"\n  }\n}",
				"/tsconfig-base.json" => "{\n  \"compilerOptions\": {\n    \"types\": [\"node\"],\n    \"lib\": [\"es2020\"],\n    \"outDir\": \"./base\",\n    \"strict\": true\n  }\n}",
				"/app.ts" => "",
			])
		]),
	];

	static final tsconfigWithExtends = "{\n  \"files\": [\"/src/index.ts\", \"/src/app.ts\"],\n  \"include\": [\"/src/**/*\"],\n  \"exclude\": [],\n  \"ts-node\": {\n    \"compilerOptions\": {\n      \"module\": \"commonjs\"\n    },\n    \"transpileOnly\": true\n  }\n}";
	static final tsconfigWithoutConfigDir = "{\n  \"compilerOptions\": {\n    \"outDir\": \"bin\"\n  }\n}";
	static final tsconfigWithConfigDir = "{\n  \"compilerOptions\": {\n    \"outDir\": \"${configDir}/bin\"\n  }\n}";
	static final tsconfigWithExtendsAndConfigDir = "{\n  \"compilerOptions\": {\n    \"outFile\": \"${configDir}/outFile\",\n    \"outDir\": \"${configDir}/outDir\",\n    \"rootDir\": \"${configDir}/rootDir\",\n    \"tsBuildInfoFile\": \"${configDir}/tsBuildInfoFile\",\n    \"baseUrl\": \"${configDir}/baseUrl\",\n    \"declarationDir\": \"${configDir}/declarationDir\",\n  }\n}";

	public static function run() {
		T.run("TestParseConfigFileTextToJson", () -> {
			for (rec in parseConfigFileTextToJsonTests) {
				T.run("TestParseConfigFileTextToJson/" + rec.title, () -> {
					final baselineContent = new StringWriter();
					for (i in 0...rec.input.length) {
						final jsonText = rec.input[i];
						baselineContent.WriteString("Input::\n");
						baselineContent.WriteString(jsonText);
						baselineContent.WriteString("\n");
						final r = Tsoptions.ParseConfigFileTextToJson("/apath/tsconfig.json", "/apath", jsonText);
						final parsed = r.a;
						final errors = r.b;
						baselineContent.WriteString("Config::\n");
						writeJsonReadableText(baselineContent, parsed);
						baselineContent.WriteString("\n");
						baselineContent.WriteString("Errors::\n");
						final fo = new FormattingOptions();
						fo.NewLine = "\n";
						fo.ComparePathsOptions = new ComparePathsOptions(true, "/");
						Diagnosticwriter.FormatDiagnosticsWithColorAndContext(baselineContent, Diagnosticwriter.FromASTDiagnostics(errors), fo);
						baselineContent.WriteString("\n");
						if (i != rec.input.length - 1) {
							baselineContent.WriteString("\n");
						}
					}
					TsoptionsTestUtil.baselineRunAgainstSubmodule(rec.title + " jsonParse.js", baselineContent.toString(), "config/tsconfigParsing");
				});
			}
		});

		T.run("TestParseJsonConfigFileContent", () -> {
			for (rec in parseJsonConfigFileTests) {
				T.run("TestParseJsonConfigFileContent/" + rec.title + " with json api", () -> {
					baselineParseConfigWith(rec.title + " with json api.js", rec.noSubmoduleBaseline, rec.input, getParsedWithJsonApi);
				});
			}
		});

		T.run("TestParseJsonSourceFileConfigFileContent", () -> {
			for (rec in parseJsonConfigFileTests) {
				T.run("TestParseJsonSourceFileConfigFileContent/" + rec.title + " with jsonSourceFile api", () -> {
					baselineParseConfigWith(rec.title + " with jsonSourceFile api.js", rec.noSubmoduleBaseline, rec.input, getParsedWithJsonSourceFileApi);
				});
			}
		});

		T.run("TestParseJsonSourceFileConfigFileContentReportsInvalidExtendedConfig", () -> {
			final files = [
				"/project/tsconfig.json" => "{\n  \"extends\": \"./bad.json\"\n}",
				// The parser recovers from this as object-like JSON, producing expected-token errors for ':', ',', ',', and '}'.
				"/project/bad.json" => "{ this is not json",
				"/project/main.ts" => "export const x = 1;",
			];
			final host = Tsoptionstest.NewVFSParseConfigHost(files, "/project", true /*useCaseSensitiveFileNames*/);
			final configFileName = "/project/tsconfig.json";
			final configFile = Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName,
				Tspath.ToPath(configFileName, host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames()), files[configFileName]);

			final parsed = Tsoptions.ParseJsonSourceFileConfigFileContent(configFile, host, host.GetCurrentDirectory(), null, null, configFileName, null, null,
				null);

			final parseErrors = Core.Filter(parsed.Errors, function(diagnostic:Diagnostic):Bool {
				return diagnostic.Code() == Diagnostics.X_0_expected.Code();
			});
			final expectedParseErrorMessages = [":", ",", ",", "}"];
			final expectedParseErrorPositions = [7, 10, 14, 18];
			T.eq(expectedParseErrorMessages.length, Core.len(parseErrors));
			T.isTrue(Slices.Equal(Core.Map(parseErrors, function(diagnostic:Diagnostic):String {
				return diagnostic.MessageArgs()[0];
			}), expectedParseErrorMessages));
			T.isTrue(Slices.Equal(Core.Map(parseErrors, function(d:Diagnostic):Int return d.Pos()), expectedParseErrorPositions));
			for (diagnostic in parseErrors) {
				T.eq("/project/bad.json", diagnostic.File().FileName());
			}
		});

		// Extending an empty config file used to panic on nil Statements (#4265).
		T.run("TestParseJsonSourceFileConfigFileContentWithEmptyExtendedConfig", () -> {
			final files = [
				"/project/tsconfig.json" => "{\n  \"extends\": \"./base.json\"\n}",
				"/project/base.json" => "",
				"/project/main.ts" => "export const x = 1;",
			];
			final host = Tsoptionstest.NewVFSParseConfigHost(files, "/project", true /*useCaseSensitiveFileNames*/);
			final configFileName = "/project/tsconfig.json";
			final configFile = Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName,
				Tspath.ToPath(configFileName, host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames()), files[configFileName]);

			final parsed = Tsoptions.ParseJsonSourceFileConfigFileContent(configFile, host, host.GetCurrentDirectory(), null, null, configFileName, null, null,
				null);

			T.isTrue(parsed != null);
			T.isTrue(Slices.Equal(parsed.FileNames(), ["/project/main.ts"]), Std.string(parsed.FileNames()));
		});

		T.run("TestParseJsonSourceFileConfigFileContentDoesNotDuplicateUnquotedKeyDiagnostics", () -> {
			final parsed = Tsoptionstest.GetParsedCommandLine("{\n  compilerOptions: {\n    strict: true\n  }\n}", ["/main.ts" => "export const x = 1;"], "/",
				true /*useCaseSensitiveFileNames*/);

			final diags = parsed.GetConfigFileParsingDiagnostics();
			T.eq(2, Core.len(diags));
			final expectedLocations = [[1, 2], [2, 4]];
			for (index in 0...Core.len(diags)) {
				final diagnostic = diags[index];
				T.eq(Diagnostics.String_literal_with_double_quotes_expected.Code(), diagnostic.Code());
				final lc = Scanner.GetECMALineAndUTF16CharacterOfPosition(diagnostic.File(), diagnostic.Pos());
				T.eq(expectedLocations[index][0], lc.a);
				T.eq(expectedLocations[index][1], (lc.b : Int));
			}
		});

		T.run("TestParseJsonSourceFileConfigFileContentReportsQuestionTokenDiagnostics", () -> {
			final parsed = Tsoptionstest.GetParsedCommandLine("{\n  compilerOptions?: {\n    strict?: true\n  }\n}", ["/main.ts" => "export const x = 1;"],
				"/", true /*useCaseSensitiveFileNames*/);

			final questionTokenDiagnostics:Array<Diagnostic> = [];
			for (diagnostic in parsed.GetConfigFileParsingDiagnostics()) {
				if (diagnostic.Code() == Diagnostics.The_0_modifier_can_only_be_used_in_TypeScript_files.Code()) {
					questionTokenDiagnostics.push(diagnostic);
				}
			}
			T.eq(2, questionTokenDiagnostics.length);
			final expectedLocations = [[1, 17], [2, 10]];
			for (index in 0...questionTokenDiagnostics.length) {
				final diagnostic = questionTokenDiagnostics[index];
				final lc = Scanner.GetECMALineAndUTF16CharacterOfPosition(diagnostic.File(), diagnostic.Pos());
				T.eq(expectedLocations[index][0], lc.a);
				T.eq(expectedLocations[index][1], (lc.b : Int));
			}
		});

		T.run("TestParseNullEnumCompilerOptions", () -> {
			final config = new TestConfig("{\n\t\t\t\"compilerOptions\": {\n\t\t\t\t\"target\": null,\n\t\t\t\t\"module\": null\n\t\t\t}\n\t\t}", "tsconfig.json", "/",
				["/app.ts" => ""]);
			// PORT: Go ranges over a map of two functions (random order); run them in a fixed order.
			for (name => getParsed in [
				"json api" => getParsedWithJsonApi,
				"jsonSourceFile api" => getParsedWithJsonSourceFileApi
			]) {
				T.run("TestParseNullEnumCompilerOptions/" + name, () -> {
					final allFileLists = new Map<String, String>();
					for (k => v in config.allFileList)
						allFileLists[k] = v;
					allFileLists["/tsconfig.json"] = config.jsonText;
					final host = Tsoptionstest.NewVFSParseConfigHost(allFileLists, config.basePath, true /*useCaseSensitiveFileNames*/);
					final parsedConfigFileContent = getParsed(config, host, config.basePath);
					T.eq(0, Core.len(parsedConfigFileContent.Errors));
				});
			}
		});

		T.run("TestParseTypeAcquisition", () -> {
			// repo.SkipIfNoTypeScriptSubmodule(t)
			// PORT: generated from the Go table (exact text; the configs are printed in the baselines).
			final cases:Array<TypeAcquisitionCase> = [
				new TypeAcquisitionCase("Convert correctly format tsconfig.json to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enable\": true,\n\t\t\"include\": [\"0.d.ts\", \"1.d.ts\"],\n\t\t\"exclude\": [\"0.js\", \"1.js\"],\n\t},\n}", "tsconfig.json"),
				new TypeAcquisitionCase("Convert incorrect format tsconfig.json to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enableAutoDiscovy\": true,\n\t}\n}", "tsconfig.json"),
				new TypeAcquisitionCase("Convert default tsconfig.json to typeAcquisition ", "{}", "tsconfig.json"),
				new TypeAcquisitionCase("Convert tsconfig.json with only enable property to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enable\": true,\n\t},\n}", "tsconfig.json"),
				new TypeAcquisitionCase("Convert jsconfig.json to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enable\": false,\n\t\t\"include\": [\"0.d.ts\"],\n\t\t\"exclude\": [\"0.js\"],\n\t},\n}", "jsconfig.json"),
				new TypeAcquisitionCase("Convert default jsconfig.json to typeAcquisition ", "{}", "jsconfig.json"),
				new TypeAcquisitionCase("Convert incorrect format jsconfig.json to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enableAutoDiscovy\": true,\n\t},\n}", "jsconfig.json"),
				new TypeAcquisitionCase("Convert jsconfig.json with only enable property to typeAcquisition ", "{\n\t\"typeAcquisition\": {\n\t\t\"enable\": false,\n\t},\n}", "jsconfig.json"),
			];
			for (test in cases) {
				final withJsonApiName = test.title + " with json api";
				final input = [
					new TestConfig(test.config, test.configName, "/apath", ["/apath/a.ts" => "", "/apath/b.ts" => "",])
				];
				T.run("TestParseTypeAcquisition/" + withJsonApiName, () -> {
					baselineParseConfigWith(withJsonApiName + ".js", true, input, getParsedWithJsonApi);
				});
				final withJsonSourceFileApiName = test.title + " with jsonSourceFile api";
				T.run("TestParseTypeAcquisition/" + withJsonSourceFileApiName, () -> {
					baselineParseConfigWith(withJsonSourceFileApiName + ".js", true, input, getParsedWithJsonSourceFileApi);
				});
			}
		});

		T.run("TestParseSrcCompiler", () -> {
			final compilerDir = Tspath.NormalizeSlashes(TsoptionsTestUtil.TypeScriptSubmodulePath() + "/src/compiler");
			final tsconfigFileName = Tspath.CombinePaths(compilerDir, "tsconfig.json");

			final fs = Osvfs.FS();
			final host = new VfsParseConfigHost(fs, compilerDir);

			final rf = fs.ReadFile(tsconfigFileName);
			final jsonText = rf.value;
			T.isTrue(rf.ok);
			final tsconfigPath = Tspath.ToPath(tsconfigFileName, compilerDir, fs.UseCaseSensitiveFileNames());
			final opts = new SourceFileParseOptions();
			opts.FileName = tsconfigFileName;
			opts.Path = tsconfigPath;
			final parsed = Parser.ParseSourceFile(opts, jsonText, ScriptKindJSON);

			if (Core.len(parsed.Diagnostics()) > 0) {
				for (error in parsed.Diagnostics()) {
					T.fail(error.Localize(ts.locale.Locale.Default));
				}
				return;
			}

			final tsConfigSourceFile = new TsConfigSourceFile(parsed);

			final parseConfigFileContent = Tsoptions.ParseJsonSourceFileConfigFileContent(tsConfigSourceFile, host, host.GetCurrentDirectory(), null, null,
				tsconfigFileName, /*resolutionStack*/ null, /*extraFileExtensions*/ null, /*extendedConfigCache*/ null);

			if (Core.len(parseConfigFileContent.Errors) > 0) {
				for (error in parseConfigFileContent.Errors) {
					T.fail(error.Localize(ts.locale.Locale.Default));
				}
				return;
			}

			final opts = parseConfigFileContent.CompilerOptions();
			final expected = new CompilerOptions();
			expected.Lib = ["lib.es2020.d.ts"];
			expected.Module = ModuleKindNodeNext;
			expected.ModuleResolution = ModuleResolutionKindNodeNext;
			expected.NewLine = NewLineKindLF;
			expected.OutDir = Tspath.NormalizeSlashes(TsoptionsTestUtil.TypeScriptSubmodulePath() + "/built/local");
			expected.Target = ScriptTargetES2020;
			expected.Types = ["node"];
			expected.ConfigFilePath = tsconfigFileName;
			expected.Declaration = TSTrue;
			expected.DeclarationMap = TSTrue;
			expected.EmitDeclarationOnly = TSTrue;
			expected.AlwaysStrict = TSTrue;
			expected.Composite = TSTrue;
			expected.IsolatedDeclarations = TSTrue;
			expected.NoImplicitOverride = TSTrue;
			expected.PreserveConstEnums = TSTrue;
			expected.RootDir = Tspath.NormalizeSlashes(TsoptionsTestUtil.TypeScriptSubmodulePath() + "/src");
			expected.SkipLibCheck = TSTrue;
			expected.Strict = TSTrue;
			expected.StrictBindCallApply = TSFalse;
			expected.SourceMap = TSTrue;
			expected.UseUnknownInCatchVariables = TSFalse;
			expected.Pretty = TSTrue;
			final diff = TsoptionsTestUtil.compilerOptionsDiff(opts, expected);
			T.isTrue(diff == "", "compiler options differ: " + diff);

			final fileNames = parseConfigFileContent.ParsedConfig.FileNames;
			final relativePaths:Array<String> = [];
			for (fileName in fileNames) {
				if (fileName.indexOf(".generated.") >= 0) {
					continue;
				}

				relativePaths.push(Tspath.ConvertToRelativePath(fileName, new ComparePathsOptions(fs.UseCaseSensitiveFileNames(), compilerDir)));
			}

			final expectedPaths = [
				"binder.ts", "builder.ts", "builderPublic.ts", "builderState.ts", "builderStatePublic.ts", "checker.ts", "commandLineParser.ts", "core.ts",
				"corePublic.ts", "debug.ts", "emitter.ts", "executeCommandLine.ts", "expressionToTypeNode.ts", "moduleNameResolver.ts", "moduleSpecifiers.ts",
				"parser.ts", "path.ts", "performance.ts", "performanceCore.ts", "program.ts", "programDiagnostics.ts", "resolutionCache.ts", "scanner.ts",
				"semver.ts", "sourcemap.ts", "symbolWalker.ts", "sys.ts", "tracing.ts", "transformer.ts", "tsbuild.ts", "tsbuildPublic.ts", "types.ts",
				"utilities.ts", "utilitiesPublic.ts", "visitorPublic.ts", "watch.ts", "watchPublic.ts", "watchUtilities.ts", "_namespaces/ts.moduleSpecifiers.ts",
				"_namespaces/ts.performance.ts", "_namespaces/ts.ts", "factory/baseNodeFactory.ts", "factory/emitHelpers.ts", "factory/emitNode.ts",
				"factory/nodeChildren.ts", "factory/nodeConverters.ts", "factory/nodeFactory.ts", "factory/nodeTests.ts", "factory/parenthesizerRules.ts",
				"factory/utilities.ts", "factory/utilitiesPublic.ts", "transformers/classFields.ts", "transformers/classThis.ts", "transformers/declarations.ts",
				"transformers/destructuring.ts", "transformers/es2015.ts", "transformers/es2016.ts", "transformers/es2017.ts", "transformers/es2018.ts",
				"transformers/es2019.ts", "transformers/es2020.ts", "transformers/es2021.ts", "transformers/esDecorators.ts", "transformers/esnext.ts",
				"transformers/generators.ts", "transformers/jsx.ts", "transformers/legacyDecorators.ts", "transformers/namedEvaluation.ts",
				"transformers/taggedTemplate.ts", "transformers/ts.ts", "transformers/typeSerializer.ts", "transformers/utilities.ts",
				"transformers/declarations/diagnostics.ts", "transformers/module/esnextAnd2015.ts", "transformers/module/impliedNodeFormatDependent.ts",
				"transformers/module/module.ts", "transformers/module/system.ts",
			];
			T.isTrue(Slices.Equal(relativePaths, expectedPaths), Std.string(relativePaths));
		});

		// BenchmarkParseSrcCompiler: not ported (benchmark).

		T.run("TestExtendedConfigErrorsAppearOnCacheHit", () -> {
			T.run("TestExtendedConfigErrorsAppearOnCacheHit/single config parsed twice", () -> {
				final files = [
					"/tsconfig.json" => "{\n  \"extends\": \"./base.json\"\n}",
					// 'excludes' instead of 'exclude' triggers diagnostic
					"/base.json" => "{\n  \"excludes\": [\"**/*.ts\"]\n}",
					"/app.ts" => "export {}",
				];

				final host = Tsoptionstest.NewVFSParseConfigHost(files, "/", true /*useCaseSensitiveFileNames*/);

				final parseConfig = function(configFileName:String, cache:ExtendedConfigCache):ParsedCommandLine {
					return parseConfigWithCache(host, configFileName, cache);
				};

				final cache = new MemoCache();
				final first = parseConfig("/tsconfig.json", cache);
				T.isTrue(Core.len(first.Errors) > 0, "expected diagnostics on first parse, got 0");
				final second = parseConfig("/tsconfig.json", cache);
				T.isTrue(Core.len(second.Errors) > 0, "expected diagnostics on second parse (cache hit), got 0");
			});

			T.run("TestExtendedConfigErrorsAppearOnCacheHit/two configs share same base", () -> {
				final files = [
					"/base.json" => "{\n  \"excludes\": [\"**/*.ts\"]\n}",
					"/projA/tsconfig.json" => "{\n  \"extends\": \"../base.json\"\n}",
					"/projB/tsconfig.json" => "{\n  \"extends\": \"../base.json\"\n}",
					"/projA/app.ts" => "export {}",
					"/projB/app.ts" => "export {}",
				];

				final host = Tsoptionstest.NewVFSParseConfigHost(files, "/", true /*useCaseSensitiveFileNames*/);

				final cache = new MemoCache();
				final first = parseConfigWithCache(host, "/projA/tsconfig.json", cache);
				T.isTrue(Core.len(first.Errors) > 0, "expected diagnostics for projA parse, got 0");
				final second = parseConfigWithCache(host, "/projB/tsconfig.json", cache);
				T.isTrue(Core.len(second.Errors) > 0, "expected diagnostics for projB parse (cache hit on base), got 0");
			});
		});

		T.run("TestExtendedConfigConfigDirPathsAreNotCached", () -> {
			final files = [
				"/tsconfig.base.json" => "{\n  \"compilerOptions\": {\n    \"paths\": {\n      \"@pkg/*\": [\"${configDir}/src/*\"]\n    }\n  }\n}",
				"/packages/a/tsconfig.json" => "{\n  \"extends\": \"../../tsconfig.base.json\"\n}",
				"/packages/b/tsconfig.json" => "{\n  \"extends\": \"../../tsconfig.base.json\"\n}",
				"/packages/a/index.ts" => "export {}",
				"/packages/b/index.ts" => "export {}",
			];

			final host = Tsoptionstest.NewVFSParseConfigHost(files, "/", true /*useCaseSensitiveFileNames*/);
			final cache = new MemoCache();

			final parseConfig = function(configFileName:String):ParsedCommandLine {
				final r = Tsoptions.GetParsedCommandLineOfConfigFile(configFileName, null, null, host, cache);
				T.isTrue(Core.len(r.b) == 0, "unexpected errors parsing " + configFileName + ": " + Std.string(r.b));
				return r.a;
			};

			parseConfig("/packages/a/tsconfig.json");
			final paths = parseConfig("/packages/b/tsconfig.json").CompilerOptions().Paths;
			T.isTrue(Slices.Equal(paths.GetOrZero("@pkg/*"), ["/packages/b/src/*"]), Std.string(paths.GetOrZero("@pkg/*")));
		});
	}

	static function parseConfigWithCache(host:VfsParseConfigHost, configFileName:String, cache:ExtendedConfigCache):ParsedCommandLine {
		final cfgPath = Tspath.ToPath(configFileName, host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames());
		final rf = host.FS().ReadFile(configFileName);
		T.isTrue(rf.ok, "missing " + configFileName + " in test fs");
		final opts = new SourceFileParseOptions();
		opts.FileName = configFileName;
		opts.Path = cfgPath;
		final tsConfigSourceFile = new TsConfigSourceFile(Parser.ParseSourceFile(opts, rf.value, ScriptKindJSON));
		return Tsoptions.ParseJsonSourceFileConfigFileContent(tsConfigSourceFile, host, host.GetCurrentDirectory(), null, null, configFileName, null, null,
			cache);
	}

	static function getParsedWithJsonApi(config:TestConfig, host:ParseConfigHost, basePath:String):ParsedCommandLine {
		final configFileName = Tspath.GetNormalizedAbsolutePath(config.configFileName, basePath);
		final path = Tspath.ToPath(config.configFileName, basePath, host.FS().UseCaseSensitiveFileNames());
		final parsed = Tsoptions.ParseConfigFileTextToJson(configFileName, path, config.jsonText).a;
		return Tsoptions.ParseJsonConfigFileContent(parsed, host, basePath, null, configFileName, /*resolutionStack*/ null, /*extraFileExtensions*/ null,
			/*extendedConfigCache*/ null);
	}

	static function getParsedWithJsonSourceFileApi(config:TestConfig, host:ParseConfigHost, basePath:String):ParsedCommandLine {
		final configFileName = Tspath.GetNormalizedAbsolutePath(config.configFileName, basePath);
		final path = Tspath.ToPath(config.configFileName, basePath, host.FS().UseCaseSensitiveFileNames());
		final opts = new SourceFileParseOptions();
		opts.FileName = configFileName;
		opts.Path = path;
		final parsed = Parser.ParseSourceFile(opts, config.jsonText, ScriptKindJSON);
		final tsConfigSourceFile = new TsConfigSourceFile(parsed);
		return Tsoptions.ParseJsonSourceFileConfigFileContent(tsConfigSourceFile, host, host.GetCurrentDirectory(), null, null, configFileName,
			/*resolutionStack*/ null, /*extraFileExtensions*/ null, /*extendedConfigCache*/ null);
	}

	static function baselineParseConfigWith(baselineFileName:String, noSubmoduleBaseline:Bool, input:Array<TestConfig>,
			getParsed:(config:TestConfig, host:ParseConfigHost, basePath:String) -> ParsedCommandLine):Void {
		noSubmoduleBaseline = true;
		final baselineContent = new StringWriter();
		for (i in 0...input.length) {
			final config = input[i];
			var basePath = config.basePath;
			if (basePath == "") {
				basePath = Tspath.GetNormalizedAbsolutePath(Tspath.GetDirectoryPath(config.configFileName), "");
			}
			final configFileName = Tspath.CombinePaths(basePath, config.configFileName);
			final allFileLists = new Map<String, String>();
			for (k => v in config.allFileList)
				allFileLists[k] = v;
			allFileLists[configFileName] = config.jsonText;
			final host = Tsoptionstest.NewVFSParseConfigHost(allFileLists, config.basePath, true /*useCaseSensitiveFileNames*/);
			final parsedConfigFileContent = getParsed(config, host, basePath);

			baselineContent.WriteString("Fs::\n");
			final err = printFS(baselineContent, host.FS(), "/");
			if (err != null) {
				T.fail(err.Error());
				return;
			}
			baselineContent.WriteString("\n");
			baselineContent.WriteString("configFileName:: ");
			baselineContent.WriteString(config.configFileName);
			baselineContent.WriteString("\n");
			if (noSubmoduleBaseline) {
				baselineContent.WriteString("CompilerOptions::\n");
				baselineContent.WriteString(Json.MarshalIndentOrdered(TsoptionsTestUtil.compilerOptionsJson(parsedConfigFileContent.ParsedConfig.CompilerOptions), "",
					"  "));
				baselineContent.WriteString("\n");
				baselineContent.WriteString("\n");

				if (parsedConfigFileContent.ParsedConfig.TypeAcquisition != null) {
					baselineContent.WriteString("TypeAcquisition::\n");
					baselineContent.WriteString(Json.MarshalIndentOrdered(TsoptionsTestUtil.typeAcquisitionJson(parsedConfigFileContent.ParsedConfig.TypeAcquisition),
						"", "  "));
					baselineContent.WriteString("\n");
					baselineContent.WriteString("\n");
				}
			}
			baselineContent.WriteString("FileNames::\n");
			baselineContent.WriteString(parsedConfigFileContent.ParsedConfig.FileNames.join(","));
			baselineContent.WriteString("\n");
			baselineContent.WriteString("Errors::\n");
			final fo = new FormattingOptions();
			fo.NewLine = "\r\n";
			fo.ComparePathsOptions = new ComparePathsOptions(true, basePath);
			Diagnosticwriter.FormatDiagnosticsWithColorAndContext(baselineContent, Diagnosticwriter.FromASTDiagnostics(parsedConfigFileContent.Errors), fo);
			baselineContent.WriteString("\n");
			if (i != input.length - 1) {
				baselineContent.WriteString("\n");
			}
		}
		if (noSubmoduleBaseline) {
			TsoptionsTestUtil.baselineRun(baselineFileName, baselineContent.toString(), "config/tsconfigParsing");
		} else {
			TsoptionsTestUtil.baselineRunAgainstSubmodule(baselineFileName, baselineContent.toString(), "config/tsconfigParsing");
		}
	}

	static function writeJsonReadableText(output:StringWriter, input:Dynamic):Void {
		output.WriteString(Json.MarshalIndentOrdered(input, "", "  "));
	}

	static function printFS(output:StringWriter, files:FS, root:String):Null<Error> {
		return files.WalkDir(root, function(path:String, d:Null<DirEntry>, err:Null<Error>):Null<Error> {
			if (err != null) {
				return err;
			}
			if (d.Type().IsRegular()) {
				final r = files.ReadFile(path);
				if (!r.ok) {
					return Errors.New("failed to read file " + path);
				} else {
					output.WriteString("//// [" + path + "]\r\n" + r.value + "\r\n\r\n");
				}
			}
			return null;
		});
	}
}

class TestConfig {
	public var jsonText:String;
	public var configFileName:String;
	public var basePath:String;
	public var allFileList:Map<String, String>;

	public function new(jsonText:String, configFileName:String, basePath:String, allFileList:Map<String, String>) {
		this.jsonText = jsonText;
		this.configFileName = configFileName;
		this.basePath = basePath;
		this.allFileList = allFileList;
	}
}

class ParseConfigFileTextToJsonTest {
	public var title:String;
	public var input:Array<String>;

	public function new(title:String, input:Array<String>) {
		this.title = title;
		this.input = input;
	}
}

class ParseJsonConfigTestCase {
	public var title:String;
	public var noSubmoduleBaseline:Bool;
	public var input:Array<TestConfig>;

	public function new(title:String, noSubmoduleBaseline:Bool, input:Array<TestConfig>) {
		this.title = title;
		this.noSubmoduleBaseline = noSubmoduleBaseline;
		this.input = input;
	}
}

class TypeAcquisitionCase {
	public var title:String;
	public var config:String;
	public var configName:String;

	public function new(title:String, config:String, configName:String) {
		this.title = title;
		this.config = config;
		this.configName = configName;
	}
}

// memoCache is a minimal memoizing ExtendedConfigCache used by tests to simulate
// cache hits across multiple parses of configs that extend a common base.
class MemoCache implements ExtendedConfigCache {
	var m:Null<Map<String, ExtendedConfigCacheEntry>> = null;

	public function new() {}

	public function GetExtendedConfig(fileName:String, path:Path, resolutionStack:Null<Array<Path>>, host:ParseConfigHost):ExtendedConfigCacheEntry {
		if (this.m == null) {
			this.m = new Map<String, ExtendedConfigCacheEntry>();
		}
		if (this.m.exists(path)) {
			return this.m.get(path);
		}
		final e = Tsoptions.ParseExtendedConfig(fileName, path, resolutionStack, host, this);
		this.m.set(path, e);
		return e;
	}
}
