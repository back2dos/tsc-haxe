package ts.testutil.tsbaseline;

import go.Io.Writer;
import ts.diagnosticwriter.Diagnosticwriter.ASTDiagnostic;
import ts.diagnosticwriter.Diagnosticwriter.FormattingOptions;
import ts.diagnosticwriter.Diagnosticwriter.FileLike;

// Port of internal/testutil/tsbaseline: package-level funcs and vars of error_baseline.go,
// type_symbol_baseline.go and util.go (the types of type_symbol_baseline.go are in TypeSymbolBaseline.hx).
// PORT: js_emit_baseline.go, sourcemap*_baseline.go and module_resolution_baseline.go are not ported yet.
// PORT: the Go regexps are hand-written matchers (PORTING.md §7 prefers a hand loop for simple patterns);
// each one names its Go pattern.
@:allow(ts.testutil.tsbaseline)
class Tsbaseline {
	// --- error_baseline.go ---

	// IO
	static inline final harnessNewLine = "\r\n";

	static var formatOpts(get, never):FormattingOptions;
	static var formatOptsValue:FormattingOptions = null;

	static function get_formatOpts():FormattingOptions {
		if (formatOptsValue == null) {
			formatOptsValue = new FormattingOptions();
			formatOptsValue.NewLine = harnessNewLine;
		}
		return formatOptsValue;
	}

	public static function DoErrorBaseline(t:T, baselinePath:String, inputFiles:Array<TestFile>, errors:Array<Diagnostic>, pretty:Bool,
			opts:Options):Void {
		baselinePath = replaceTsExtension(baselinePath, ".errors.txt");
		var errorBaseline:String;
		if (Core.len(errors) > 0) {
			errorBaseline = GetErrorBaseline(t, inputFiles, Diagnosticwriter.WrapASTDiagnostics(errors), Diagnosticwriter.CompareASTDiagnostics, pretty);
		} else {
			errorBaseline = Baseline.NoContent;
		}
		Baseline.Run(t, baselinePath, errorBaseline, opts);
	}

	static function minimalDiagnosticsToString(diagnostics:Array<ts.diagnosticwriter.Diagnosticwriter.Diagnostic>, pretty:Bool):String {
		final output = new StringWriter();
		if (pretty) {
			Diagnosticwriter.FormatDiagnosticsWithColorAndContext(output, diagnostics, formatOpts);
		} else {
			Diagnosticwriter.WriteFormatDiagnostics(output, diagnostics, formatOpts);
		}
		return output.String();
	}

	// PORT: generic over T diagnosticwriter.Diagnostic in Go; the harness only uses *ASTDiagnostic.
	public static function GetErrorBaseline(t:T, inputFiles:Array<TestFile>, diagnostics:Array<ASTDiagnostic>,
			compareDiagnostics:(ASTDiagnostic, ASTDiagnostic) -> Int, pretty:Bool):String {
		t.Helper();
		final outputLines = iterateErrorBaseline(t, inputFiles, diagnostics, compareDiagnostics, pretty);

		if (pretty) {
			final summaryBuilder = new StringWriter();
			Diagnosticwriter.WriteErrorSummaryText(summaryBuilder, Diagnosticwriter.ToDiagnostics(diagnostics), formatOpts);
			final summary = removeTestPathPrefixes(summaryBuilder.String(), false);
			outputLines.push(summary);
		}
		return outputLines.join("");
	}

	static function iterateErrorBaseline(t:T, inputFiles:Array<TestFile>, inputDiagnostics:Array<ASTDiagnostic>,
			compareDiagnostics:(ASTDiagnostic, ASTDiagnostic) -> Int, pretty:Bool):Array<String> {
		t.Helper();
		final diagnostics = Slices.Clone(inputDiagnostics);
		Slices.SortFunc(diagnostics, compareDiagnostics);

		var outputLines = new StringBuf();
		// Count up all errors that were found in files other than lib.d.ts so we don't miss any
		var totalErrorsReportedInNonLibraryNonTsconfigFiles = 0;
		var errorsReported = 0;

		var firstLine = true;

		final newLine = function():String {
			if (firstLine) {
				firstLine = false;
				return "";
			}
			return "\r\n";
		};

		final result:Array<String> = [];

		final outputErrorText = function(diag:ts.diagnosticwriter.Diagnosticwriter.Diagnostic) {
			final message = Diagnosticwriter.FlattenDiagnosticMessage(diag, harnessNewLine, Locale.Default);

			final errLines:Array<String> = [];
			for (line0 in removeTestPathPrefixes(message, false).split("\n")) {
				final line = Strings.TrimSuffix(line0, "\r");
				if (line.length == 0) {
					continue;
				}
				final out = Fmt.Sprintf("!!! %s TS%d: %s", [diag.Category().Name(), diag.Code(), line]);
				errLines.push(out);
			}

			final related = diag.RelatedInformation();
			if (related != null) {
				for (info in related) {
					var location = "";
					if (info.File() != null) {
						location = " " + formatLocation(info.File(), info.Pos(), formatOpts, function(output:Writer, text:String, formatStyle:String) {
							output.Write(text);
						});
					}
					location = removeTestPathPrefixes(location, false);
					if (location.length > 0 && isDefaultLibraryFile(info.File().FileName())) {
						location = replaceDiagnosticsLocationPattern(location);
					}
					errLines.push(Fmt.Sprintf("!!! related TS%d%s: %s", [
						info.Code(),
						location,
						Diagnosticwriter.FlattenDiagnosticMessage(info, harnessNewLine, Locale.Default)
					]));
				}
			}

			for (e in errLines) {
				outputLines.add(newLine());
				outputLines.add(e);
			}

			errorsReported++;

			// do not count errors from lib.d.ts here, they are computed separately as numLibraryDiagnostics
			// if lib.d.ts is explicitly included in input files and there are some errors in it (i.e. because of duplicate identifiers)
			// then they will be added twice thus triggering 'total errors' assertion with condition
			// Similarly for tsconfig, which may be in the input files and contain errors.
			// 'totalErrorsReportedInNonLibraryNonTsconfigFiles + numLibraryDiagnostics + numTsconfigDiagnostics, diagnostics.length

			if (diag.File() == null || !isDefaultLibraryFile(diag.File().FileName()) && !isTsConfigFile(diag.File().FileName())) {
				totalErrorsReportedInNonLibraryNonTsconfigFiles++;
			}
		};

		var topDiagnostics = minimalDiagnosticsToString(Diagnosticwriter.ToDiagnostics(diagnostics), pretty);
		topDiagnostics = removeTestPathPrefixes(topDiagnostics, false);
		topDiagnostics = replaceDiagnosticsLocationPrefix(topDiagnostics);

		result.push(topDiagnostics + harnessNewLine + harnessNewLine);

		// Report global errors
		for (error in diagnostics) {
			if (error.File() == null) {
				outputErrorText(error);
			}
		}

		result.push(outputLines.toString());
		outputLines = new StringBuf();
		errorsReported = 0;

		// 'merge' the lines of each input file with any errors associated with it
		final dupeCase = new StringMap<Int>();
		for (inputFile in inputFiles) {
			// Filter down to the errors in the file
			final fileErrors = Core.Filter(diagnostics, function(e:ASTDiagnostic):Bool {
				return e.File() != null
					&& Tspath.ComparePaths(removeTestPathPrefixes(e.File().FileName(), false), removeTestPathPrefixes(inputFile.UnitName, false),
						new ComparePathsOptions()) == 0;
			});

			// Header
			outputLines.add(Fmt.Sprintf("%s==== %s (%d errors) ====", [newLine(), removeTestPathPrefixes(inputFile.UnitName, false), Core.len(fileErrors)]));

			// Make sure we emit something for every error
			var markedErrorCount = 0;
			// For each line, emit the line followed by any error squiggles matching this line

			final lineStarts = Core.ComputeECMALineStarts(inputFile.Content);
			final lines = splitLineDelimiter(inputFile.Content);

			for (lineIndex in 0...lines.length) {
				var line = lines[lineIndex];
				if (line.length > 0 && StringTools.fastCodeAt(line, line.length - 1) == "\r".code) {
					line = line.substring(0, line.length - 1);
				}

				final thisLineStart:Int = lineStarts[lineIndex];
				var nextLineStart:Int;
				// On the last line of the file, fake the next line start number so that we handle errors on the last character of the file correctly
				if (lineIndex == lines.length - 1) {
					nextLineStart = inputFile.Content.length;
				} else {
					nextLineStart = lineStarts[lineIndex + 1];
				}
				// Emit this line from the original file
				outputLines.add(newLine());
				outputLines.add("    ");
				outputLines.add(line);
				if (fileErrors != null) {
					for (errDiagnostic in fileErrors) {
						// Does any error start or continue on to this line? Emit squiggles
						final errStart = errDiagnostic.Pos();
						final end = errStart + errDiagnostic.Len();
						if (end >= thisLineStart && (errStart < nextLineStart || lineIndex == lines.length - 1)) {
							// How many characters from the start of this line the error starts at (could be positive or negative)
							final relativeOffset = errStart - thisLineStart;
							// How many characters of the error are on this line (might be longer than this line in reality)
							final length = (end - errStart) - Std.int(std.Math.max(0, thisLineStart - errStart));
							// Calculate the start of the squiggle
							final squiggleStart = Std.int(std.Math.max(0, relativeOffset));
							// TODO/REVIEW: this doesn't work quite right in the browser if a multi file test has files whose names are just the right length relative to one another
							outputLines.add(newLine());
							outputLines.add("    ");
							if (squiggleStart > line.length) {
								throw Fmt.Sprintf("runtime error: slice bounds out of range [:%d] with length %d", [squiggleStart, line.length]);
							}
							outputLines.add(replaceNonWhitespace(line.substring(0, squiggleStart)));
							// This was `new Array(count).join("~")`; which maps 0 to "", 1 to "", 2 to "~", 3 to "~~", etc.
							final squiggleEnd = Std.int(std.Math.max(squiggleStart, std.Math.min(squiggleStart + length, line.length)));
							outputLines.add(Strings.Repeat("~", runeCount(line.substring(squiggleStart, squiggleEnd))));
							// If the error ended here, or we're at the end of the file, emit its message
							if (lineIndex == lines.length - 1 || nextLineStart > end) {
								outputErrorText(errDiagnostic);
								markedErrorCount++;
							}
						}
					}
				}
			}

			// Verify we didn't miss any errors in this file
			if (markedErrorCount != Core.len(fileErrors)) {
				t.Errorf("assertion failed: %d (markedErrorCount int) != %d (len(fileErrors) int): count of errors in %s", markedErrorCount,
					Core.len(fileErrors), inputFile.UnitName);
			}
			final isDupe = dupeCase.exists(sanitizeTestFilePath(inputFile.UnitName));
			result.push(outputLines.toString());
			if (isDupe) {
				// Case-duplicated files on a case-insensitive build will have errors reported in both the dupe and the original
				// thanks to the canse-insensitive path comparison on the error file path - We only want to count those errors once
				// for the assert below, so we subtract them here.
				totalErrorsReportedInNonLibraryNonTsconfigFiles -= errorsReported;
			}
			outputLines = new StringBuf();
			errorsReported = 0;
		}

		final numLibraryDiagnostics = Core.CountWhere(diagnostics, function(d:ASTDiagnostic):Bool {
			return d.File() != null && (isDefaultLibraryFile(d.File().FileName()) || isBuiltFile(d.File().FileName()));
		});
		final numTsconfigDiagnostics = Core.CountWhere(diagnostics, function(d:ASTDiagnostic):Bool {
			return d.File() != null && isTsConfigFile(d.File().FileName());
		});
		// Verify we didn't miss any errors in total
		if (totalErrorsReportedInNonLibraryNonTsconfigFiles + numLibraryDiagnostics + numTsconfigDiagnostics != Core.len(diagnostics)) {
			t.Errorf("assertion failed: total number of errors");
		}

		return result;
	}

	static function formatLocation(file:FileLike, pos:Int, formatOpts:FormattingOptions,
			writeWithStyleAndReset:ts.diagnosticwriter.Diagnosticwriter.FormattedWriter):String {
		final output = new StringWriter();
		Diagnosticwriter.WriteLocation(output, file, pos, formatOpts, writeWithStyleAndReset);
		return output.String();
	}

	// Go: diagnosticsLocationPrefix = regexp.MustCompile(`(?im)^(lib.*\.d\.ts)\(\d+,\d+\)`), ReplaceAllString(s, "$1(--,--)").
	static function replaceDiagnosticsLocationPrefix(s:String):String {
		final b = new StringBuf();
		var pos = 0;
		var i = 0;
		while (i <= s.length) {
			final atLineStart = i == 0 || StringTools.fastCodeAt(s, i - 1) == "\n".code;
			if (atLineStart && i < s.length) {
				final m = matchLibLocation(s, i, true);
				if (m >= 0) {
					// m = end of group 1; the match continues with (\d+,\d+)
					final matchEnd = matchParenDigits(s, m);
					b.add(s.substring(pos, m));
					b.add("(--,--)");
					pos = matchEnd;
					i = matchEnd;
					continue;
				}
			}
			i++;
		}
		b.add(s.substring(pos));
		return b.toString();
	}

	// Go: diagnosticsLocationPattern = regexp.MustCompile(`(?i)(lib.*\.d\.ts):\d+:\d+`), ReplaceAllString(s, "$1:--:--").
	static function replaceDiagnosticsLocationPattern(s:String):String {
		final b = new StringBuf();
		var pos = 0;
		var i = 0;
		while (i < s.length) {
			final m = matchLibLocation(s, i, false);
			if (m >= 0) {
				final matchEnd = matchColonDigits(s, m);
				b.add(s.substring(pos, m));
				b.add(":--:--");
				pos = matchEnd;
				i = matchEnd;
				continue;
			}
			i++;
		}
		b.add(s.substring(pos));
		return b.toString();
	}

	// Matches (?i)lib.*\.d\.ts at `start` followed by `\(\d+,\d+\)` (paren) or `:\d+:\d+` (not paren), with
	// `.*` greedy (no newline). Returns the end of the `lib...d.ts` group, or -1.
	static function matchLibLocation(s:String, start:Int, paren:Bool):Int {
		if (start + 3 > s.length)
			return -1;
		if (s.substring(start, start + 3).toLowerCase() != "lib")
			return -1;
		var lineEnd = start + 3;
		while (lineEnd < s.length && StringTools.fastCodeAt(s, lineEnd) != "\n".code)
			lineEnd++;
		// greedy: try the longest group first
		var e = lineEnd;
		while (e >= start + 3 + 5) {
			if (s.substring(e - 5, e).toLowerCase() == ".d.ts") {
				final rest = paren ? matchParenDigits(s, e) : matchColonDigits(s, e);
				if (rest >= 0)
					return e;
			}
			e--;
		}
		return -1;
	}

	static function digitsEnd(s:String, i:Int):Int {
		final start = i;
		while (i < s.length && StringTools.fastCodeAt(s, i) >= "0".code && StringTools.fastCodeAt(s, i) <= "9".code)
			i++;
		return i > start ? i : -1;
	}

	// `\(\d+,\d+\)` at i; returns the end or -1.
	static function matchParenDigits(s:String, i:Int):Int {
		if (i >= s.length || StringTools.fastCodeAt(s, i) != "(".code)
			return -1;
		var j = digitsEnd(s, i + 1);
		if (j < 0 || j >= s.length || StringTools.fastCodeAt(s, j) != ",".code)
			return -1;
		j = digitsEnd(s, j + 1);
		if (j < 0 || j >= s.length || StringTools.fastCodeAt(s, j) != ")".code)
			return -1;
		return j + 1;
	}

	// `:\d+:\d+` at i; returns the end or -1.
	static function matchColonDigits(s:String, i:Int):Int {
		if (i >= s.length || StringTools.fastCodeAt(s, i) != ":".code)
			return -1;
		var j = digitsEnd(s, i + 1);
		if (j < 0 || j >= s.length || StringTools.fastCodeAt(s, j) != ":".code)
			return -1;
		return digitsEnd(s, j + 1);
	}

	// Go: nonWhitespace.ReplaceAllString(s, " ") with nonWhitespace = `\S` (Go \s = [\t\n\f\r ]): every
	// other rune (a surrogate pair is one rune) becomes one space.
	static function replaceNonWhitespace(s:String):String {
		final b = new StringBuf();
		var i = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == "\t".code || c == "\n".code || c == 0x0C || c == "\r".code || c == " ".code) {
				b.add(s.substring(i, i + 1));
				i++;
			} else {
				b.add(" ");
				i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length && StringTools.fastCodeAt(s, i + 1) >= 0xDC00
					&& StringTools.fastCodeAt(s, i + 1) <= 0xDFFF) ? 2 : 1;
			}
		}
		return b.toString();
	}

	// utf8.RuneCountInString: code points (a surrogate pair counts once).
	static function runeCount(s:String):Int {
		var n = 0;
		var i = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length && StringTools.fastCodeAt(s, i + 1) >= 0xDC00
				&& StringTools.fastCodeAt(s, i + 1) <= 0xDFFF) ? 2 : 1;
			n++;
		}
		return n;
	}

	// --- type_symbol_baseline.go ---

	public static function DoTypeAndSymbolBaseline(t:T, baselinePath:String, header:String, program:ProgramLike, allFiles:Array<TestFile>, opts:Options,
			skipTypeBaselines:Bool, skipSymbolBaselines:Bool, hasErrorBaseline:Bool):Void {
		// The full walker simulates the types that you would get from doing a full
		// compile.  The pull walker simulates the types you get when you just do
		// a type query for a random node (like how the LS would do it).  Most of the
		// time, these will be the same.  However, occasionally, they can be different.
		// Specifically, when the compiler internally depends on symbol IDs to order
		// things, then we may see different results because symbols can be created in a
		// different order with 'pull' operations, and thus can produce slightly differing
		// output.
		//
		// For example, with a full type check, we may see a type displayed as: number | string
		// But with a pull type check, we may see it as:                        string | number
		//
		// These types are equivalent, but depend on what order the compiler observed
		// certain parts of the program.

		final fullWalker = newTypeWriterWalker(program, hasErrorBaseline);

		t.Run("type", function(t:T) {
			try {
				// !!! Remove once the type baselines print node reuse lines
				// PORT: typesOpts.DiffFixupOld only affects the .diff baseline, which is not ported.
				final typesOpts = opts.copy();
				checkBaselines(t, baselinePath, allFiles, fullWalker, header, typesOpts, false /*isSymbolBaseline*/);
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating type baseline for test " + header, e);
			}
		});
		t.Run("symbol", function(t:T) {
			try {
				checkBaselines(t, baselinePath, allFiles, fullWalker, header, opts, true /*isSymbolBaseline*/);
			} catch (e:haxe.Exception) {
				Testutil.RecoverAndFail(t, "Panic on creating symbol baseline for test " + header, e);
			}
		});
	}

	static function isTypeBaselineNodeReuseLine(line:String):Bool {
		if (!StringTools.startsWith(line, ">"))
			return false;
		line = line.substring(1);
		line = line.substring(1); // line[1:]
		while (StringTools.startsWith(line, " ")) // strings.TrimLeft(.., " ")
			line = line.substring(1);
		if (!StringTools.startsWith(line, ":"))
			return false;
		line = line.substring(1);
		for (i in 0...line.length) {
			final c = StringTools.fastCodeAt(line, i);
			if (c != " ".code && c != "^".code && c != "\r".code)
				return false;
		}
		return true;
	}

	static function checkBaselines(t:T, baselinePath:String, allFiles:Array<TestFile>, fullWalker:TypeWriterWalker, header:String, opts:Options,
			isSymbolBaseline:Bool):Void {
		final fullExtension = Core.IfElse(isSymbolBaseline, ".symbols", ".types");
		final outputFileName = replaceTsExtension(baselinePath, fullExtension);
		final fullBaseline = generateBaseline(allFiles, fullWalker, header, isSymbolBaseline);
		Baseline.Run(t, outputFileName, fullBaseline, opts);
	}

	static function generateBaseline(allFiles:Array<TestFile>, fullWalker:TypeWriterWalker, header:String, isSymbolBaseline:Bool):String {
		final result = new StringBuf();
		// !!! Perf baseline
		final perfLines:Array<String> = [];
		// prePerformanceValues := getPerformanceBaselineValues()
		final baselines = iterateBaseline(allFiles, fullWalker, isSymbolBaseline);
		for (value in baselines) {
			result.add(value);
		}
		// postPerformanceValues := getPerformanceBaselineValues()

		// !!! Perf baselines (commented out in Go)

		final s = result.toString();
		if (s.length > 0) {
			return Fmt.Sprintf("//// [%s] ////\r\n\r\n%s%s", [header, perfLines.join("\n"), s]);
		}
		return Baseline.NoContent;
	}

	static function iterateBaseline(allFiles:Array<TestFile>, fullWalker:TypeWriterWalker, isSymbolBaseline:Bool):Array<String> {
		final baselines:Array<String> = [];

		for (file in allFiles) {
			final unitName = file.UnitName;
			final typeLines = new StringBuf();
			typeLines.add("=== ");
			typeLines.add(unitName);
			typeLines.add(" ===\r\n");
			final codeLines = splitCodeLines(file.Content);
			var results:Array<TypeWriterResult>;
			if (isSymbolBaseline) {
				results = fullWalker.getSymbols(unitName);
			} else {
				results = fullWalker.getTypes(unitName);
			}
			var lastIndexWritten = -1;
			for (result in results) {
				if (isSymbolBaseline && result.symbol == "") {
					return baselines;
				}
				if (lastIndexWritten == -1) {
					typeLines.add(codeLines.slice(0, result.line + 1).join("\r\n"));
					typeLines.add("\r\n");
				} else if (lastIndexWritten != result.line) {
					if (!(lastIndexWritten + 1 < codeLines.length
						&& (isBracketLine(codeLines[lastIndexWritten + 1]) || Strings.TrimSpace(codeLines[lastIndexWritten + 1]) == ""))) {
						typeLines.add("\r\n");
					}
					typeLines.add(codeLines.slice(lastIndexWritten + 1, result.line + 1).join("\r\n"));
					typeLines.add("\r\n");
				}
				lastIndexWritten = result.line;
				final typeOrSymbolString = Core.IfElse(isSymbolBaseline, result.symbol, result.typ);
				final lineText = removeLineDelimiters(result.sourceText);
				typeLines.add(">");
				typeLines.add(lineText + " : " + typeOrSymbolString);
				typeLines.add("\r\n");
				if (result.underline != "") {
					typeLines.add(">");
					for (_ in 0...utf8Len(lineText)) {
						typeLines.add(" ");
					}
					typeLines.add(" : ");
					typeLines.add(result.underline);
					typeLines.add("\r\n");
				}
			}

			if (lastIndexWritten + 1 < codeLines.length) {
				if (!(lastIndexWritten + 1 < codeLines.length
					&& (isBracketLine(codeLines[lastIndexWritten + 1]) || Strings.TrimSpace(codeLines[lastIndexWritten + 1]) == ""))) {
					typeLines.add("\r\n");
				}
				typeLines.add(codeLines.slice(lastIndexWritten + 1).join("\r\n"));
			}
			typeLines.add("\r\n");

			baselines.push(removeTestPathPrefixes(typeLines.toString(), false /*retainTrailingDirectorySeparator*/));
		}

		return baselines;
	}

	// len(s) of a Go string: its UTF-8 byte length.
	static function utf8Len(s:String):Int {
		var n = 0;
		var i = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c < 0x80)
				n += 1;
			else if (c < 0x800)
				n += 2;
			else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
				n += 4;
				i++;
			} else
				n += 3;
			i++;
		}
		return n;
	}

	// Go: codeLinesRegexp = `[\r  ]|\r?\n`, Split(s, -1). Leftmost-first: a `\r` is matched by the
	// first alternative alone, so each of \r, \n, U+2028, U+2029 is a separator.
	static function splitCodeLines(s:String):Array<String> {
		final result:Array<String> = [];
		var start = 0;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == "\r".code || c == "\n".code || c == 0x2028 || c == 0x2029) {
				result.push(s.substring(start, i));
				start = i + 1;
			}
		}
		result.push(s.substring(start));
		return result;
	}

	// Go: bracketLineRegex = `^\s*[{|}]\s*$`
	static function isBracketLine(s:String):Bool {
		final t = trimGoSpace(s);
		return t == "{" || t == "|" || t == "}";
	}

	static function trimGoSpace(s:String):String {
		inline function isSp(c:Int)
			return c == "\t".code || c == "\n".code || c == 0x0C || c == "\r".code || c == " ".code;
		var a = 0;
		var b = s.length;
		while (a < b && isSp(StringTools.fastCodeAt(s, a)))
			a++;
		while (b > a && isSp(StringTools.fastCodeAt(s, b - 1)))
			b--;
		return s.substring(a, b);
	}

	// Go: lineDelimiter.ReplaceAllString(s, "") with lineDelimiter = `\r?\n`.
	static function removeLineDelimiters(s:String):String {
		final b = new StringBuf();
		var start = 0;
		for (i in 0...s.length) {
			if (StringTools.fastCodeAt(s, i) == "\n".code) {
				var end = i;
				if (end > start && StringTools.fastCodeAt(s, end - 1) == "\r".code)
					end--;
				b.add(s.substring(start, end));
				start = i + 1;
			}
		}
		b.add(s.substring(start));
		return b.toString();
	}

	static function newTypeWriterWalker(program:ProgramLike, hadErrorBaseline:Bool):TypeWriterWalker {
		final w = new TypeWriterWalker();
		w.program = program;
		w.hadErrorBaseline = hadErrorBaseline;
		w.declarationTextCache = new ObjectMap();
		return w;
	}

	static function forEachASTNode(node:Node):Array<Node> {
		final result:Array<Node> = [];
		final work:Array<Node> = [node];

		final resChildren:Array<Node> = [];
		final addChild = function(child:Node):Bool {
			resChildren.push(child);
			return false;
		};

		while (work.length > 0) {
			final elem = work.pop();
			if ((elem.Flags & NodeFlagsReparsed) == 0
				|| elem.Kind == KindAsExpression
				|| elem.Kind == KindSatisfiesExpression
				|| ((elem.Parent.Kind == KindSatisfiesExpression || elem.Parent.Kind == KindAsExpression) && elem == elem.Parent.Expression())) {
				if ((elem.Flags & NodeFlagsReparsed) == 0 || elem.Parent.Kind == KindAsExpression || elem.Parent.Kind == KindSatisfiesExpression) {
					result.push(elem);
				}
				elem.ForEachChild(addChild);
				Slices.Reverse(resChildren);
				for (c in resChildren)
					work.push(c);
				resChildren.resize(0);
			}
		}
		return result;
	}

	static function isImportStatementName(node:Node):Bool {
		if (Ast.IsImportSpecifier(node.Parent) && (node == node.Parent.Name() || node == node.Parent.PropertyName())) {
			return true;
		}
		if (Ast.IsImportClause(node.Parent) && node == node.Parent.Name()) {
			return true;
		}
		if (Ast.IsImportEqualsDeclaration(node.Parent) && node == node.Parent.Name()) {
			return true;
		}
		return false;
	}

	static function isExportStatementName(node:Node):Bool {
		if (Ast.IsExportAssignment(node.Parent) && node == node.Parent.Expression()) {
			return true;
		}
		if (Ast.IsExportSpecifier(node.Parent) && (node == node.Parent.Name() || node == node.Parent.PropertyName())) {
			return true;
		}
		return false;
	}

	static function isIntrinsicJsxTag(node:Node, sourceFile:SourceFile):Bool {
		if (!(Ast.IsJsxOpeningElement(node.Parent) || Ast.IsJsxClosingElement(node.Parent) || Ast.IsJsxSelfClosingElement(node.Parent))) {
			return false;
		}
		if (node.Parent.TagName() != node) {
			return false;
		}
		final text = Scanner.GetSourceTextOfNodeFromSourceFile(sourceFile, node, false /*includeTrivia*/);
		return Scanner.IsIntrinsicJsxName(text);
	}

	// --- util.go ---

	static inline final libFolder = "built/local/";
	static inline final builtFolder = "/.ts";

	// Go: tsExtension = regexp.MustCompile(`\.tsx?$`), ReplaceAllString(path, ext).
	static function replaceTsExtension(path:String, ext:String):String {
		if (StringTools.endsWith(path, ".tsx"))
			return path.substring(0, path.length - 4) + ext;
		if (StringTools.endsWith(path, ".ts"))
			return path.substring(0, path.length - 3) + ext;
		return path;
	}

	// Go: lineDelimiter.Split(s, -1) with lineDelimiter = `\r?\n`.
	static function splitLineDelimiter(s:String):Array<String> {
		final result:Array<String> = [];
		var start = 0;
		for (i in 0...s.length) {
			if (StringTools.fastCodeAt(s, i) == "\n".code) {
				var end = i;
				if (end > start && StringTools.fastCodeAt(s, end - 1) == "\r".code)
					end--;
				result.push(s.substring(start, end));
				start = i + 1;
			}
		}
		result.push(s.substring(start));
		return result;
	}

	static final testPathPrefixes = ["/.ts/", "/.lib/", "/.src/", "bundled:///libs/", "file:///./ts/", "file:///./lib/", "file:///./src/"];
	static final testPathPrefixReplacements = ["", "", "", "", "file:///", "file:///", "file:///"];
	static final testPathTrailingReplacements = ["/", "/", "/", "/", "file:///", "file:///", "file:///"];

	// PORT: strings.NewReplacer(...).Replace: leftmost match, ties broken by argument order.
	static function removeTestPathPrefixes(text:String, retainTrailingDirectorySeparator:Bool):String {
		final repl = retainTrailingDirectorySeparator ? testPathTrailingReplacements : testPathPrefixReplacements;
		final b = new StringBuf();
		var start = 0;
		var i = 0;
		while (i < text.length) {
			var matched = -1;
			final c = StringTools.fastCodeAt(text, i);
			if (c == "/".code || c == "b".code || c == "f".code) {
				for (k in 0...testPathPrefixes.length) {
					final p = testPathPrefixes[k];
					if (StringTools.startsWith(text.substr(i, p.length), p) && text.substr(i, p.length) == p) {
						matched = k;
						break;
					}
				}
			}
			if (matched >= 0) {
				b.add(text.substring(start, i));
				b.add(repl[matched]);
				i += testPathPrefixes[matched].length;
				start = i;
			} else {
				i++;
			}
		}
		b.add(text.substring(start));
		return b.toString();
	}

	static function isDefaultLibraryFile(filePath:String):Bool {
		final fileName = Tspath.GetBaseFileName(filePath);
		return StringTools.startsWith(fileName, "lib.") && StringTools.endsWith(fileName, Tspath.ExtensionDts);
	}

	static function isBuiltFile(filePath:String):Bool {
		return StringTools.startsWith(filePath, libFolder) || StringTools.startsWith(filePath, Tspath.EnsureTrailingDirectorySeparator(builtFolder));
	}

	static function isTsConfigFile(path:String):Bool {
		// !!! fix to check for just prefixes/suffixes
		return path.indexOf("tsconfig") >= 0 && path.indexOf("json") >= 0;
	}

	// Go: testPathCharacters = `[\^<>:"|?*%]`, testPathDotDot = `\.\.\/`.
	static function sanitizeTestFilePath(name:String):String {
		final b = new StringBuf();
		for (i in 0...name.length) {
			final c = StringTools.fastCodeAt(name, i);
			switch (c) {
				case "^".code | "<".code | ">".code | ":".code | "\"".code | "|".code | "?".code | "*".code | "%".code:
					b.add("_");
				default:
					b.add(name.substring(i, i + 1));
			}
		}
		var path = Tspath.NormalizeSlashes(b.toString());
		path = StringTools.replace(path, "../", "__dotdot/");
		path = Tspath.ToPath(path, "", false /*useCaseSensitiveFileNames*/);
		return Strings.TrimPrefix(path, "/");
	}
}

// PORT: Go `strings.Builder` used as an io.Writer.
class StringWriter implements Writer {
	final b = new StringBuf();

	public function new() {}

	public function Write(p:String):ValueError<Int> {
		b.add(p);
		return new ValueError<Int>(p.length, null);
	}

	public function String():String {
		return b.toString();
	}
}
