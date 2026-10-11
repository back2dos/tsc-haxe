package ts.printer;

// Port of utilities.go (types and methods; the package-level funcs and vars are statics in
// class Printer).

// PORT: unexported Go type `getLiteralTextFlags` → GetLiteralTextFlags (PORTING.md §1).
enum abstract GetLiteralTextFlags(Int) from Int to Int {
	@:op(A | B) static function or(a:GetLiteralTextFlags, b:GetLiteralTextFlags):GetLiteralTextFlags;
	@:op(A & B) static function and(a:GetLiteralTextFlags, b:GetLiteralTextFlags):GetLiteralTextFlags;
	@:op(~A) static function not(a:GetLiteralTextFlags):GetLiteralTextFlags;

	var getLiteralTextFlagsNone = 0;
	var getLiteralTextFlagsNeverAsciiEscape = 1 << 0;
	var getLiteralTextFlagsJsxAttributeEscape = 1 << 1;
	var getLiteralTextFlagsTerminateUnterminatedLiterals = 1 << 2;
	var getLiteralTextFlagsAllowNumericSeparator = 1 << 3;
}

enum abstract QuoteChar(Int) from Int to Int {
	var QuoteCharSingleQuote = "'".code;
	var QuoteCharDoubleQuote = '"'.code;
	var QuoteCharBacktick = "`".code;
}

// lineCharacterCache provides cached line/character lookups for a source file,
// optimized for monotonically increasing positions (e.g., during source map emit).
//
// When positions increase within the same line, only the delta between the last
// position and the new position needs to be scanned for UTF-16 code unit counts,
// turning what would be O(n²) into O(n) for long lines.
//
// Character offsets are measured in UTF-16 code units per the source map specification.
// PORT: unexported Go type `lineCharacterCache` → LineCharacterCache (PORTING.md §1).
class LineCharacterCache {
	public var lineMap:Array<TextPos> = null;
	public var text:std.String = "";
	public var cachedLine:Int = 0;
	public var cachedPos:Int = 0;
	public var cachedChar:UTF16Offset = 0;
	public var hasCached:Bool = false;
	public var lastCharacter:UTF16Offset = 0; // PORT: perf — second result of getLineAndCharacter

	public function new() {}

	// getLineAndCharacter returns the 0-based line number and UTF-16 code unit
	// offset from the start of that line for the given byte position.
	// PORT: perf — Go returns (line int, character core.UTF16Offset); character is left in lastCharacter, read by the
	// caller right after the call (no Pair per source map position).
	public function getLineAndCharacter(pos:Int):Int {
		final line = Scanner.ComputeLineOfPosition(lineMap, pos);
		final lineStart:Int = lineMap[line];
		// When pos is beyond the source text (e.g., for error-recovery tokens like
		// missing closing braces), we can't slice past the text end. Compute the
		// UTF-16 length up to EOF and add the remaining byte offset arithmetically,
		// matching TypeScript's computeLineAndCharacterOfPosition which uses
		// arithmetic (position - lineStarts[lineNumber]) and handles this implicitly.
		final endPos = pos < text.length ? pos : text.length; // min(pos, len(c.text))
		var character:UTF16Offset;
		if (hasCached && line == cachedLine && endPos >= cachedPos) {
			// Incremental: only count UTF-16 code units from the last cached position.
			// PORT: utf16 — Go `core.UTF16Len(c.text[c.cachedPos:endPos])` is the length of the range.
			character = cachedChar + (endPos - cachedPos);
		} else {
			// Full computation from line start.
			character = endPos - lineStart;
		}
		final cachedChar_ = character;
		character += pos - endPos;
		cachedLine = line;
		cachedPos = endPos;
		cachedChar = cachedChar_;
		hasCached = true;
		lastCharacter = character;
		return line;
	}
}
