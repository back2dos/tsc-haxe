package ts.tsoptions;

// Port of parsedcommandline_test.go.
class ParsedcommandlineTest {
	public static function run() {
		T.run("TestParsedCommandLine", () -> {
			T.run("TestParsedCommandLine/PossiblyMatchesFileName", () -> {
				// PORT: Go's untyped constant "/dev" → RootedDirectoryPathFromNormalized.
				final dev = Tspath.RootedDirectoryPathFromNormalized("/dev");
				final noFiles = new Map<String, String>();
				final noFilesFS = Vfstest.FromMap(noFiles, true);

				final files = [
					"/dev/a.ts" => "",
					"/dev/a.d.ts" => "",
					"/dev/a.js" => "",
					"/dev/b.ts" => "",
					"/dev/b.js" => "",
					"/dev/c.d.ts" => "",
					"/dev/z/a.ts" => "",
					"/dev/z/abz.ts" => "",
					"/dev/z/aba.ts" => "",
					"/dev/z/b.ts" => "",
					"/dev/z/bbz.ts" => "",
					"/dev/z/bba.ts" => "",
					"/dev/x/a.ts" => "",
					"/dev/x/aa.ts" => "",
					"/dev/x/b.ts" => "",
					"/dev/x/y/a.ts" => "",
					"/dev/x/y/b.ts" => "",
					"/dev/js/a.js" => "",
					"/dev/js/b.js" => "",
					"/dev/js/d.min.js" => "",
					"/dev/js/ab.min.js" => "",
					"/ext/ext.ts" => "",
					"/ext/b/a..b.ts" => "",
				];

				final assertMatches = function(parsedCommandLine:ParsedCommandLine, files:Map<String, String>, matches:Array<String>) {
					for (fileName in files.keys()) {
						final actual = parsedCommandLine.PossiblyMatchesFileName(Tspath.ToRootedFilePath(fileName, parsedCommandLine.BaseDirectory()));
						final expected = Slices.Contains(matches, fileName);
						T.isTrue(actual == expected, "fileName: " + fileName);
					}
					for (fileName in matches) {
						if (!files.exists(fileName)) {
							final actual = parsedCommandLine.PossiblyMatchesFileName(Tspath.ToRootedFilePath(fileName, parsedCommandLine.BaseDirectory()));
							T.isTrue(actual == true, "fileName: " + fileName);
						}
					}
				};

				T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal file list", () -> {
					T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal file list/without exclude", () -> {
						final parsedCommandLine = Tsoptionstest.GetParsedCommandLine('{
						"files": [
							"a.ts",
							"b.ts"
						]
					}', files, dev, /*caseSensitivity*/ CaseSensitive);

						assertMatches(parsedCommandLine, files, ["/dev/a.ts", "/dev/b.ts",]);
					});

					T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal file list/are not removed due to excludes", () -> {
						final parsedCommandLine = Tsoptionstest.GetParsedCommandLine('{
						"files": [
							"a.ts",
							"b.ts"
						],
						"exclude": [
							"b.ts"
						]
					}', files, dev, /*caseSensitivity*/ CaseSensitive);

						assertMatches(parsedCommandLine, files, ["/dev/a.ts", "/dev/b.ts",]);

						final emptyParsedCommandLine = parsedCommandLine.ReloadFileNamesOfParsedCommandLine(noFilesFS);
						assertMatches(emptyParsedCommandLine, noFiles, ["/dev/a.ts", "/dev/b.ts",]);
					});

					T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal file list/duplicates", () -> {
						final parsedCommandLine = Tsoptionstest.GetParsedCommandLine('{
						"files": [
							"a.ts",
							"a.ts",
							"b.ts",
						]
					}', files, dev, /*caseSensitivity*/ CaseSensitive);

						T.isTrue(Slices.Equal(parsedCommandLine.LiteralFileNames(),
							[Tspath.RootedFilePathFromNormalized("/dev/a.ts"), Tspath.RootedFilePathFromNormalized("/dev/b.ts"),]),
							Std.string(parsedCommandLine.LiteralFileNames()));
					});
				});

				T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal include list", () -> {
					T.run("TestParsedCommandLine/PossiblyMatchesFileName/with literal include list/without exclude", () -> {
						final parsedCommandLine = Tsoptionstest.GetParsedCommandLine('{
						"include": [
							"a.ts",
							"b.ts"
						]
					}', files, dev, /*caseSensitivity*/ CaseSensitive);

						assertMatches(parsedCommandLine, files, ["/dev/a.ts", "/dev/b.ts",]);

						final emptyParsedCommandLine = parsedCommandLine.ReloadFileNamesOfParsedCommandLine(noFilesFS);
						assertMatches(emptyParsedCommandLine, noFiles, ["/dev/a.ts", "/dev/b.ts",]);
					});
				});
			});

			// PORT: the next subtests come from TypeScript main (ed4807212c, typed paths); the content mapper subtest
			// before them needs content mapper packages and is not ported.
			T.run("TestParsedCommandLine/Config file specs are owned by the parsed command line", () -> {
				final configFileName = Tspath.RootedFilePathFromNormalized("/dev/tsconfig.json");
				final tsconfigSourceFile = Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName, CaseSensitivity.CaseSensitive.PathKey(configFileName.AsPath()),
					'{ "files": ["SRC/a.ts"] }');
				final dev = Tspath.RootedDirectoryPathFromNormalized("/dev");
				final sensitiveCommandLine = Tsoptions.ParseJsonSourceFileConfigFileContent(tsconfigSourceFile,
					Tsoptions.NewDefaultParseConfigHost(Tsoptionstest.NewVFS(null, CaseSensitive)), dev, null, null, null, null);
				Tsoptions.ParseJsonSourceFileConfigFileContent(tsconfigSourceFile,
					Tsoptions.NewDefaultParseConfigHost(Tsoptionstest.NewVFS(null, CaseInsensitive)), dev, null, null, null, null);

				T.eq("SRC/a.ts", sensitiveCommandLine.GetMatchedFileSpec(Tspath.RootedFilePathFromNormalized("/dev/SRC/a.ts")));
			});

			T.run("TestParsedCommandLine/Literal files and include matches share canonical keys", () -> {
				final fs = Tsoptionstest.NewVFS(["/dev/src/a.ts" => ""], CaseSensitive);
				final configFileName = Tspath.RootedFilePathFromNormalized("/dev/tsconfig.json");
				final commandLine = Tsoptions.ParseJsonSourceFileConfigFileContent(Tsoptions.NewTsconfigSourceFileFromFilePath(configFileName,
					CaseSensitivity.CaseSensitive.PathKey(configFileName.AsPath()), '{ "files": ["src/a.ts"], "include": ["src/*.ts"] }'),
					Tsoptions.NewDefaultParseConfigHost(fs), Tspath.RootedDirectoryPathFromNormalized("/dev"), null, null, null, null);

				T.isTrue(Slices.Equal(commandLine.FileNames(), [Tspath.RootedFilePathFromNormalized("/dev/src/a.ts")]), Std.string(commandLine.FileNames()));
			});

			T.run("TestParsedCommandLine/WithFileNames preserves config identity", () -> {
				final configFileName = "/dev/tsconfig.json";
				final tsconfigSourceFile = Tsoptions.NewTsconfigSourceFileFromFilePath(Tspath.RootedFilePathFromNormalized(configFileName),
					Tspath.PathKeyFromCanonical(configFileName), '{}');
				final parsedCommandLine = Tsoptions.ParseJsonSourceFileConfigFileContent(tsconfigSourceFile,
					Tsoptions.NewDefaultParseConfigHost(Tsoptionstest.NewVFS(new Map<String, String>(), CaseSensitive)),
					Tspath.RootedDirectoryPathFromNormalized("/dev"), null, null, null, null);

				final withTypings = parsedCommandLine.WithFileNames([
					Tspath.ToRootedFilePath("/dev/index.ts", parsedCommandLine.BaseDirectory()),
					Tspath.ToRootedFilePath("/cache/@types/pkg/index.d.ts", parsedCommandLine.BaseDirectory()),
				]);
				T.eq(configFileName, withTypings.ConfigName().AsString());
				T.isTrue(Slices.Equal(withTypings.FileNames(),
					[
						Tspath.RootedFilePathFromNormalized("/dev/index.ts"),
						Tspath.RootedFilePathFromNormalized("/cache/@types/pkg/index.d.ts")
					]),
					Std.string(withTypings.FileNames()));
			});
		});
	}
}
