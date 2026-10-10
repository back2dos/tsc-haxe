package ts.diagnosticwriter;

import go.IdentityMap;

// Port of internal/diagnosticwriter (diagnosticwriter.go): package-level funcs, consts and vars;
// the types follow the package class in this module.
// PORT: Go `*ast.Diagnostic` is written `ts.ast.Diagnostic.Diagnostic` here: the name Diagnostic is
// this package's interface.
@:allow(ts.diagnosticwriter)
class Diagnosticwriter {
	public static function WrapASTDiagnostic(d:ts.ast.Diagnostic.Diagnostic):ASTDiagnostic {
		return new ASTDiagnostic(d);
	}

	public static function WrapASTDiagnostics(diags:Array<ts.ast.Diagnostic.Diagnostic>):Array<ASTDiagnostic> {
		final result = new Array<ASTDiagnostic>();
		if (diags != null) for (d in diags) {
			result.push(WrapASTDiagnostic(d));
		}
		return result;
	}

	public static function FromASTDiagnostics(diags:Array<ts.ast.Diagnostic.Diagnostic>):Array<Diagnostic> {
		final result = new Array<Diagnostic>();
		if (diags != null) for (d in diags) {
			result.push(WrapASTDiagnostic(d));
		}
		return result;
	}

	public static function ToDiagnostics<T:Diagnostic>(diags:Array<T>):Array<Diagnostic> {
		final result = new Array<Diagnostic>();
		if (diags != null) for (d in diags) {
			result.push(d);
		}
		return result;
	}

	public static function CompareASTDiagnostics(a:ASTDiagnostic, b:ASTDiagnostic):Int {
		return Ast.CompareDiagnostics(a.Diagnostic, b.Diagnostic);
	}

	static inline final foregroundColorEscapeGrey = "\x1b[90m";
	static inline final foregroundColorEscapeRed = "\x1b[91m";
	static inline final foregroundColorEscapeYellow = "\x1b[93m";
	static inline final foregroundColorEscapeBlue = "\x1b[94m";
	static inline final foregroundColorEscapeCyan = "\x1b[96m";

	static inline final gutterStyleSequence = "\x1b[7m";
	static inline final gutterSeparator = " ";
	static inline final resetEscapeSequence = "\x1b[0m";
	static inline final ellipsis = "...";

	public static function FormatDiagnosticsWithColorAndContext(output:Writer, diags:Array<Diagnostic>, formatOpts:FormattingOptions):Void {
		if (Core.len(diags) == 0) {
			return;
		}
		for (i in 0...diags.length) {
			final diagnostic = diags[i];
			if (i > 0) {
				Fmt.Fprint(output, [formatOpts.NewLine]);
			}
			FormatDiagnosticWithColorAndContext(output, diagnostic, formatOpts);
		}
	}

	public static function FormatDiagnosticWithColorAndContext(output:Writer, diagnostic:Diagnostic, formatOpts:FormattingOptions):Void {
		if (diagnostic.File() != null) {
			final file = diagnostic.File();
			final pos = diagnostic.Pos();
			WriteLocation(output, file, pos, formatOpts, writeWithStyleAndReset);
			Fmt.Fprint(output, [" - "]);
		}

		writeWithStyleAndReset(output, diagnostic.Category().Name(), getCategoryFormat(diagnostic.Category()));
		Fmt.Fprintf(output, "%s TS%d: %s", [foregroundColorEscapeGrey, diagnostic.Code(), resetEscapeSequence]);
		WriteFlattenedDiagnosticMessage(output, diagnostic, formatOpts.NewLine, formatOpts.Locale);

		if (diagnostic.File() != null && diagnostic.Code() != Diagnostics.File_appears_to_be_binary.Code()) {
			Fmt.Fprint(output, [formatOpts.NewLine]);
			writeCodeSnippet(output, diagnostic.File(), diagnostic.Pos(), diagnostic.Len(), getCategoryFormat(diagnostic.Category()), "", formatOpts);
			Fmt.Fprint(output, [formatOpts.NewLine]);
		}

		if ((diagnostic.RelatedInformation() != null) && (diagnostic.RelatedInformation().length > 0)) {
			for (relatedInformation in diagnostic.RelatedInformation()) {
				final file = relatedInformation.File();
				if (file != null) {
					Fmt.Fprint(output, [formatOpts.NewLine]);
					Fmt.Fprint(output, ["  "]);
					final pos = relatedInformation.Pos();
					WriteLocation(output, file, pos, formatOpts, writeWithStyleAndReset);
					Fmt.Fprint(output, [" - "]);
					WriteFlattenedDiagnosticMessage(output, relatedInformation, formatOpts.NewLine, formatOpts.Locale);
					writeCodeSnippet(output, file, pos, relatedInformation.Len(), foregroundColorEscapeCyan, "    ", formatOpts);
				}
				Fmt.Fprint(output, [formatOpts.NewLine]);
			}
		}
	}

	static function writeCodeSnippet(writer:Writer, sourceFile:FileLike, start:Int, length:Int, squiggleColor:String, indent:String,
			formatOpts:FormattingOptions):Void {
		final first = Scanner.GetECMALineAndUTF16CharacterOfPosition(sourceFile, start);
		final firstLine = first.a;
		final firstLineChar = first.b;
		final last = Scanner.GetECMALineAndUTF16CharacterOfPosition(sourceFile, start + length);
		final lastLine = last.a;
		var lastLineChar = last.b;
		if (length == 0) {
			lastLineChar++; // When length is zero, squiggle the character right after the start position.
		}

		final lastLineOfFile = Scanner.GetECMALineOfPosition(sourceFile, sourceFile.Text().length);

		final hasMoreThanFiveLines = lastLine - firstLine >= 4;
		var gutterWidth = Std.string(lastLine + 1).length;
		if (hasMoreThanFiveLines) {
			gutterWidth = Core.IfElse(ellipsis.length > gutterWidth, ellipsis.length, gutterWidth); // max
		}

		var i = firstLine;
		while (i <= lastLine) {
			Fmt.Fprint(writer, [formatOpts.NewLine]);

			// If the error spans over 5 lines, we'll only show the first 2 and last 2 lines,
			// so we'll skip ahead to the second-to-last line.
			if (hasMoreThanFiveLines && firstLine + 1 < i && i < lastLine - 1) {
				Fmt.Fprint(writer, [indent]);
				Fmt.Fprint(writer, [gutterStyleSequence]);
				Fmt.Fprintf(writer, "%*s", [gutterWidth, ellipsis]);
				Fmt.Fprint(writer, [resetEscapeSequence]);
				Fmt.Fprint(writer, [gutterSeparator]);
				Fmt.Fprint(writer, [formatOpts.NewLine]);
				i = lastLine - 1;
			}

			final lineStart = Scanner.GetECMAPositionOfLineAndByteOffset(sourceFile, i, 0);
			var lineEnd:Int;
			if (i < lastLineOfFile) {
				lineEnd = Scanner.GetECMAPositionOfLineAndByteOffset(sourceFile, i + 1, 0);
			} else {
				lineEnd = sourceFile.Text().length;
			}

			var lineContent = Strings.TrimRightFunc(sourceFile.Text().substring(lineStart, lineEnd), Unicode.IsSpace); // trim from end
			lineContent = Strings.ReplaceAll(lineContent, "\t", " "); // convert tabs to single spaces

			// Output the gutter and the actual contents of the line.
			Fmt.Fprint(writer, [indent]);
			Fmt.Fprint(writer, [gutterStyleSequence]);
			Fmt.Fprintf(writer, "%*d", [gutterWidth, i + 1]);
			Fmt.Fprint(writer, [resetEscapeSequence]);
			Fmt.Fprint(writer, [gutterSeparator]);
			Fmt.Fprint(writer, [lineContent]);
			Fmt.Fprint(writer, [formatOpts.NewLine]);

			// Output the gutter and the error span for the line using tildes.
			Fmt.Fprint(writer, [indent]);
			Fmt.Fprint(writer, [gutterStyleSequence]);
			Fmt.Fprintf(writer, "%*s", [gutterWidth, ""]);
			Fmt.Fprint(writer, [resetEscapeSequence]);
			Fmt.Fprint(writer, [gutterSeparator]);
			Fmt.Fprint(writer, [squiggleColor]);
			if (i == firstLine) {
				// If we're on the last line, then limit it to the last character of the last line.
				// Otherwise, we'll just squiggle the rest of the line, giving 'slice' no end position.
				var lastCharForLine:Int;
				if (i == lastLine) {
					lastCharForLine = lastLineChar;
				} else {
					lastCharForLine = lineContent.length; // core.UTF16Len
				}

				// Fill with spaces until the first character,
				// then squiggle the remainder of the line.
				Fmt.Fprint(writer, [repeat(" ", firstLineChar)]);
				Fmt.Fprint(writer, [repeat("~", lastCharForLine - firstLineChar)]);
			} else if (i == lastLine) {
				// Squiggle until the final character.
				Fmt.Fprint(writer, [repeat("~", lastLineChar)]);
			} else {
				// Squiggle the entire line.
				Fmt.Fprint(writer, [repeat("~", lineContent.length)]); // core.UTF16Len
			}

			Fmt.Fprint(writer, [resetEscapeSequence]);
			i++;
		}
	}

	// PORT: strings.Repeat (panics on a negative count, like Go).
	static function repeat(s:String, count:Int):String {
		if (count < 0) {
			throw "strings: negative Repeat count";
		}
		final b = new StringBuf();
		for (_ in 0...count) {
			b.add(s);
		}
		return b.toString();
	}

	public static function FlattenDiagnosticMessage(d:Diagnostic, newLine:String, locale:Locale):String {
		final output = new StringBuilderWriter();
		WriteFlattenedDiagnosticMessage(output, d, newLine, locale);
		return output.String();
	}

	public static function WriteFlattenedASTDiagnosticMessage(writer:Writer, diagnostic:ts.ast.Diagnostic.Diagnostic, newline:String, locale:Locale):Void {
		WriteFlattenedDiagnosticMessage(writer, WrapASTDiagnostic(diagnostic), newline, locale);
	}

	public static function WriteFlattenedDiagnosticMessage(writer:Writer, diagnostic:Diagnostic, newline:String, locale:Locale):Void {
		Fmt.Fprint(writer, [diagnostic.Localize(locale)]);

		final chains = diagnostic.MessageChain();
		if (chains != null) {
			for (chain in chains) {
				flattenDiagnosticMessageChain(writer, chain, newline, locale, 1 /*level*/);
			}
		}
	}

	static function flattenDiagnosticMessageChain(writer:Writer, chain:Diagnostic, newLine:String, locale:Locale, level:Int):Void {
		Fmt.Fprint(writer, [newLine]);
		for (_ in 0...level) {
			Fmt.Fprint(writer, ["  "]);
		}

		Fmt.Fprint(writer, [chain.Localize(locale)]);
		final children = chain.MessageChain();
		if (children != null) {
			for (child in children) {
				flattenDiagnosticMessageChain(writer, child, newLine, locale, level + 1);
			}
		}
	}

	static function getCategoryFormat(category:Category):String {
		switch (category) {
			case CategoryError:
				return foregroundColorEscapeRed;
			case CategoryWarning:
				return foregroundColorEscapeYellow;
			case CategorySuggestion:
				return foregroundColorEscapeGrey;
			case CategoryMessage:
				return foregroundColorEscapeBlue;
			default:
		}
		throw "Unhandled diagnostic category";
	}

	static function writeWithStyleAndReset(output:Writer, text:String, formatStyle:String):Void {
		Fmt.Fprint(output, [formatStyle]);
		Fmt.Fprint(output, [text]);
		Fmt.Fprint(output, [resetEscapeSequence]);
	}

	public static function WriteLocation(output:Writer, file:FileLike, pos:Int, formatOpts:FormattingOptions, writeWithStyleAndReset:FormattedWriter):Void {
		final first = Scanner.GetECMALineAndUTF16CharacterOfPosition(file, pos);
		final firstLine = first.a;
		final firstChar = first.b;
		var relativeFileName:String;
		if (formatOpts != null) {
			relativeFileName = Tspath.ConvertToRelativePath(file.FileName(), formatOpts.ComparePathsOptions);
		} else {
			relativeFileName = file.FileName();
		}

		writeWithStyleAndReset(output, relativeFileName, foregroundColorEscapeCyan);
		Fmt.Fprint(output, [":"]);
		writeWithStyleAndReset(output, Std.string(firstLine + 1), foregroundColorEscapeYellow);
		Fmt.Fprint(output, [":"]);
		writeWithStyleAndReset(output, Std.string(firstChar + 1), foregroundColorEscapeYellow);
	}

	// Some of these lived in watch.ts, but they're not specific to the watch API.

	public static function WriteErrorSummaryText(output:Writer, allDiagnostics:Array<Diagnostic>, formatOpts:FormattingOptions):Void {
		// Roughly corresponds to 'getErrorSummaryText' from watch.ts

		final errorSummary = getErrorSummary(allDiagnostics);
		final totalErrorCount = errorSummary.TotalErrorCount;
		if (totalErrorCount == 0) {
			return;
		}

		var firstFile:FileLike = null;
		if (Core.len(errorSummary.SortedFiles) > 0) {
			firstFile = errorSummary.SortedFiles[0];
		}
		final firstFileName = prettyPathForFileError(firstFile, errorSummary.errorsByFileGet(firstFile), formatOpts);
		final numErroringFiles = errorSummary.errorsByFileLen();

		var message:String;
		if (totalErrorCount == 1) {
			// Special-case a single error.
			if (Core.len(errorSummary.GlobalErrors) > 0 || firstFileName == "") {
				message = Diagnostics.Found_1_error.Localize(formatOpts.Locale, []);
			} else {
				message = Diagnostics.Found_1_error_in_0.Localize(formatOpts.Locale, [firstFileName]);
			}
		} else {
			switch (numErroringFiles) {
				case 0:
					// No file-specific errors.
					message = Diagnostics.Found_0_errors.Localize(formatOpts.Locale, [totalErrorCount]);
				case 1:
					// One file with errors.
					message = Diagnostics.Found_0_errors_in_the_same_file_starting_at_Colon_1.Localize(formatOpts.Locale, [totalErrorCount, firstFileName]);
				default:
					// Multiple files with errors.
					message = Diagnostics.Found_0_errors_in_1_files.Localize(formatOpts.Locale, [totalErrorCount, numErroringFiles]);
			}
		}
		Fmt.Fprint(output, [formatOpts.NewLine]);
		Fmt.Fprint(output, [message]);
		Fmt.Fprint(output, [formatOpts.NewLine]);
		Fmt.Fprint(output, [formatOpts.NewLine]);
		if (numErroringFiles > 1) {
			writeTabularErrorsDisplay(output, errorSummary, formatOpts);
			Fmt.Fprint(output, [formatOpts.NewLine]);
		}
	}

	static function getErrorSummary(diags:Array<Diagnostic>):ErrorSummary {
		var totalErrorCount = 0;
		var globalErrors:Array<Diagnostic> = null;
		var errorsByFile:IdentityMap<FileLike, Array<Diagnostic>> = null;

		if (diags != null) {
			for (diagnostic in diags) {
				if (diagnostic.Category() != CategoryError) {
					continue;
				}

				totalErrorCount++;
				if (diagnostic.File() == null) {
					if (globalErrors == null)
						globalErrors = [];
					globalErrors.push(diagnostic);
				} else {
					if (errorsByFile == null) {
						errorsByFile = new IdentityMap<FileLike, Array<Diagnostic>>();
					}
					var list = errorsByFile.get(diagnostic.File());
					if (list == null) {
						list = [];
						errorsByFile.set(diagnostic.File(), list);
					}
					list.push(diagnostic);
				}
			}
		}

		// !!!
		// Need an ordered map here, but sorting for consistency.
		final sortedFiles:Array<FileLike> = errorsByFile == null ? [] : [for (k in errorsByFile.keys()) k];
		Slices.SortFunc(sortedFiles, function(a:FileLike, b:FileLike):Int {
			return Strings.Compare(a.FileName(), b.FileName());
		});

		final summary = new ErrorSummary();
		summary.TotalErrorCount = totalErrorCount;
		summary.GlobalErrors = globalErrors;
		summary.ErrorsByFile = errorsByFile;
		summary.SortedFiles = sortedFiles;
		return summary;
	}

	static function writeTabularErrorsDisplay(output:Writer, errorSummary:ErrorSummary, formatOpts:FormattingOptions):Void {
		final sortedFiles = errorSummary.SortedFiles;

		var maxErrors = 0;
		if (errorSummary.ErrorsByFile != null) {
			for (errorsForFile in errorSummary.ErrorsByFile) {
				maxErrors = Core.IfElse(errorsForFile.length > maxErrors, errorsForFile.length, maxErrors); // max
			}
		}

		// !!!
		// TODO (drosen): This was never localized.
		// Should make this better.
		final headerRow = Diagnostics.Errors_Files.Localize(formatOpts.Locale, []);
		// PORT: byte — Go len() counts UTF-8 bytes; the English header is ASCII.
		final leftColumnHeadingLength = Strings.Split(headerRow, " ")[0].length;
		final lengthOfBiggestErrorCount = Std.string(maxErrors).length;
		final leftPaddingGoal = Core.IfElse(leftColumnHeadingLength > lengthOfBiggestErrorCount, leftColumnHeadingLength, lengthOfBiggestErrorCount); // max
		final headerPadding = Core.IfElse(lengthOfBiggestErrorCount - leftColumnHeadingLength > 0, lengthOfBiggestErrorCount - leftColumnHeadingLength, 0); // max

		Fmt.Fprint(output, [repeat(" ", headerPadding)]);
		Fmt.Fprint(output, [headerRow]);
		Fmt.Fprint(output, [formatOpts.NewLine]);

		for (file in sortedFiles) {
			final fileErrors = errorSummary.errorsByFileGet(file);
			final errorCount = Core.len(fileErrors);

			Fmt.Fprintf(output, "%*d  ", [leftPaddingGoal, errorCount]);
			Fmt.Fprint(output, [prettyPathForFileError(file, fileErrors, formatOpts)]);
			Fmt.Fprint(output, [formatOpts.NewLine]);
		}
	}

	static function prettyPathForFileError(file:FileLike, fileErrors:Array<Diagnostic>, formatOpts:FormattingOptions):String {
		if (file == null || Core.len(fileErrors) == 0) {
			return "";
		}
		final line = Scanner.GetECMALineOfPosition(file, fileErrors[0].Pos());
		var fileName = file.FileName();
		if (Tspath.PathIsAbsolute(fileName) && Tspath.PathIsAbsolute(formatOpts.ComparePathsOptions.CurrentDirectory)) {
			fileName = Tspath.ConvertToRelativePath(file.FileName(), formatOpts.ComparePathsOptions);
		}
		return Fmt.Sprintf("%s%s:%d%s", [fileName, foregroundColorEscapeGrey, line + 1, resetEscapeSequence]);
	}

	public static function WriteFormatDiagnostics(output:Writer, diagnostics:Array<Diagnostic>, formatOpts:FormattingOptions):Void {
		if (diagnostics != null) {
			for (diagnostic in diagnostics) {
				WriteFormatDiagnostic(output, diagnostic, formatOpts);
			}
		}
	}

	public static function WriteFormatDiagnostic(output:Writer, diagnostic:Diagnostic, formatOpts:FormattingOptions):Void {
		if (diagnostic.File() != null) {
			final lc = Scanner.GetECMALineAndUTF16CharacterOfPosition(diagnostic.File(), diagnostic.Pos());
			final line = lc.a;
			final character = lc.b;
			final fileName = diagnostic.File().FileName();
			final relativeFileName = Tspath.ConvertToRelativePath(fileName, formatOpts.ComparePathsOptions);
			Fmt.Fprintf(output, "%s(%d,%d): ", [relativeFileName, line + 1, character + 1]);
		}

		Fmt.Fprintf(output, "%s TS%d: ", [diagnostic.Category().Name(), diagnostic.Code()]);
		WriteFlattenedDiagnosticMessage(output, diagnostic, formatOpts.NewLine, formatOpts.Locale);
		Fmt.Fprint(output, [formatOpts.NewLine]);
	}

	public static function FormatDiagnosticsStatusWithColorAndTime(output:Writer, time:String, diag:Diagnostic, formatOpts:FormattingOptions):Void {
		Fmt.Fprint(output, ["["]);
		writeWithStyleAndReset(output, time, foregroundColorEscapeGrey);
		Fmt.Fprint(output, ["] "]);
		WriteFlattenedDiagnosticMessage(output, diag, formatOpts.NewLine, formatOpts.Locale);
	}

	public static function FormatDiagnosticsStatusAndTime(output:Writer, time:String, diag:Diagnostic, formatOpts:FormattingOptions):Void {
		Fmt.Fprint(output, [time, " - "]);
		WriteFlattenedDiagnosticMessage(output, diag, formatOpts.NewLine, formatOpts.Locale);
	}

	// PORT: lazy getter (PORTING.md §7a: the initializer uses another class's statics).
	public static var ScreenStartingCodes(get, never):Array<Int>;
	static var screenStartingCodes:Array<Int> = null;

	static function get_ScreenStartingCodes():Array<Int> {
		if (screenStartingCodes == null) {
			screenStartingCodes = [
				Diagnostics.Starting_compilation_in_watch_mode.Code(),
				Diagnostics.File_change_detected_Starting_incremental_compilation.Code(),
			];
		}
		return screenStartingCodes;
	}

	public static function TryClearScreen(output:Writer, diag:Diagnostic, options:CompilerOptions):Bool {
		if (!options.PreserveWatchOutput.IsTrue()
			&& !options.ExtendedDiagnostics.IsTrue()
			&& !options.Diagnostics.IsTrue()
			&& Slices.Contains(ScreenStartingCodes, diag.Code())) {
			Fmt.Fprint(output, ["\x1B[2J\x1B[3J\x1B[H"]); // Clear screen and move cursor to home position
			return true;
		}
		return false;
	}
}

interface FileLike extends SourceFileLike {
	function FileName():String;
	// Text():String and ECMALineMap():Array<TextPos> from SourceFileLike.
}

// Diagnostic interface abstracts over ast.Diagnostic and LSP diagnostics
interface Diagnostic {
	function File():FileLike;
	function Pos():Int;
	function End():Int;
	function Len():Int;
	function Code():Int;
	function Category():Category;
	function Localize(locale:Locale):String;
	function MessageChain():Array<Diagnostic>;
	function RelatedInformation():Array<Diagnostic>;
}

// ASTDiagnostic wraps ast.Diagnostic to implement the Diagnostic interface
// PORT: Go embeds *ast.Diagnostic; composition field `Diagnostic` plus forwarders for the promoted methods.
class ASTDiagnostic implements Diagnostic {
	public var Diagnostic:ts.ast.Diagnostic.Diagnostic = null;

	public function new(Diagnostic:ts.ast.Diagnostic.Diagnostic) {
		this.Diagnostic = Diagnostic;
	}

	public function RelatedInformation():Array<Diagnostic> {
		final related = Diagnostic.RelatedInformation();
		final result = new Array<Diagnostic>();
		if (related != null) for (r in related) {
			result.push(new ASTDiagnostic(r));
		}
		return result;
	}

	public function File():FileLike {
		final file = Diagnostic.File();
		if (file != null) {
			return FileLikeOfSourceFile.of(file);
		}
		return null;
	}

	public function MessageChain():Array<Diagnostic> {
		final chain = Diagnostic.MessageChain();
		final result = new Array<Diagnostic>();
		if (chain != null) for (c in chain) {
			result.push(new ASTDiagnostic(c));
		}
		return result;
	}

	public function Pos():Int {
		return Diagnostic.Pos();
	}

	public function End():Int {
		return Diagnostic.End();
	}

	public function Len():Int {
		return Diagnostic.Len();
	}

	public function Code():Int {
		return Diagnostic.Code();
	}

	public function Category():Category {
		return Diagnostic.Category();
	}

	public function Localize(locale:Locale):String {
		return Diagnostic.Localize(locale);
	}
}

// PORT: Go's *ast.SourceFile implements FileLike structurally; Haxe interfaces are nominal and the
// SourceFile class does not declare FileLike, so it is wrapped. The wrapper is cached per SourceFile so
// that File() keeps Go's pointer identity (getErrorSummary uses the file as a map key).
class FileLikeOfSourceFile implements FileLike {
	static var cache:IdentityMap<SourceFile, FileLikeOfSourceFile> = null;

	public final SourceFile:SourceFile;

	function new(file:SourceFile) {
		this.SourceFile = file;
	}

	public static function of(file:SourceFile):FileLikeOfSourceFile {
		if (cache == null) {
			cache = new IdentityMap<SourceFile, FileLikeOfSourceFile>();
		}
		var f = cache.get(file);
		if (f == null) {
			f = new FileLikeOfSourceFile(file);
			cache.set(file, f);
		}
		return f;
	}

	public function FileName():String {
		return SourceFile.FileName();
	}

	public function Text():String {
		return SourceFile.Text();
	}

	public function ECMALineMap():Array<TextPos> {
		return SourceFile.ECMALineMap();
	}
}

class FormattingOptions {
	public var Locale:Locale = ts.locale.Locale.Default;
	// PORT: embedded tspath.ComparePathsOptions → composition field.
	public var ComparePathsOptions:ComparePathsOptions = new ComparePathsOptions();
	public var NewLine:String = "";

	public function new() {}
}

typedef FormattedWriter = (output:Writer, text:String, formatStyle:String) -> Void;

class ErrorSummary {
	public var TotalErrorCount:Int = 0;
	public var GlobalErrors:Array<Diagnostic> = null;
	public var ErrorsByFile:IdentityMap<FileLike, Array<Diagnostic>> = null;
	public var SortedFiles:Array<FileLike> = null;

	public function new() {}

	// PORT: Go map index `ErrorsByFile[f]` on a possibly nil map (nil → nil slice).
	@:allow(ts.diagnosticwriter)
	function errorsByFileGet(f:FileLike):Array<Diagnostic> {
		return ErrorsByFile == null || f == null ? null : ErrorsByFile.get(f);
	}

	// PORT: Go len(ErrorsByFile).
	@:allow(ts.diagnosticwriter)
	function errorsByFileLen():Int {
		var n = 0;
		if (ErrorsByFile != null) {
			for (_ in ErrorsByFile.keys())
				n++;
		}
		return n;
	}
}

// PORT: Go `var output strings.Builder` passed as io.Writer.
private class StringBuilderWriter implements Writer {
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
