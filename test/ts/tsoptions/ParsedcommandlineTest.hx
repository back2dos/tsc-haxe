package ts.tsoptions;

// Port of parsedcommandline_test.go.
class ParsedcommandlineTest {
	public static function run() {
		T.run("TestParsedCommandLine", () -> {
			T.run("TestParsedCommandLine/PossiblyMatchesFileName", () -> {
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
						final actual = parsedCommandLine.PossiblyMatchesFileName(fileName);
						final expected = Slices.Contains(matches, fileName);
						T.isTrue(actual == expected, "fileName: " + fileName);
					}
					for (fileName in matches) {
						if (!files.exists(fileName)) {
							final actual = parsedCommandLine.PossiblyMatchesFileName(fileName);
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
					}', files, "/dev", /*useCaseSensitiveFileNames*/ true);

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
					}', files, "/dev", /*useCaseSensitiveFileNames*/ true);

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
					}', files, "/dev", /*useCaseSensitiveFileNames*/ true);

						T.isTrue(Slices.Equal(parsedCommandLine.LiteralFileNames(), ["/dev/a.ts", "/dev/b.ts",]),
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
					}', files, "/dev", /*useCaseSensitiveFileNames*/ true);

						assertMatches(parsedCommandLine, files, ["/dev/a.ts", "/dev/b.ts",]);

						final emptyParsedCommandLine = parsedCommandLine.ReloadFileNamesOfParsedCommandLine(noFilesFS);
						assertMatches(emptyParsedCommandLine, noFiles, ["/dev/a.ts", "/dev/b.ts",]);
					});
				});
			});
		});
	}
}
