package ts.printer;

import go.Strings.Builder;

// Port of textwriter.go (type textWriter and its methods; NewTextWriter, GetDefaultIndentSize and
// getIndentString are package statics in class Printer).

// PORT: unexported Go type `textWriter` → TextWriter (PORTING.md §1).
class TextWriter implements EmitTextWriter implements Grower {
	public var newLine:std.String = "";
	public var indentSize:Int = 0;
	public var builder:Builder = new Builder();
	public var lastWritten:std.String = "";
	public var indent:Int = 0;
	public var lineStart:Bool = false;
	public var lineCount:Int = 0;
	public var linePos:Int = 0;
	public var hasTrailingCommentState:Bool = false;
	// PORT: perf — reused by updateLineCountAndPosFor (Go's iter.Seq there does not allocate per call).
	final lineStartsSeq:ECMALineStartsSeqIterator = new ECMALineStartsSeqIterator("");

	public function new() {}

	public function Clear():Void {
		// PORT: Go `*w = textWriter{newLine: w.newLine, indentSize: w.indentSize, lineStart: true}`
		builder = new Builder();
		lastWritten = "";
		indent = 0;
		lineStart = true;
		lineCount = 0;
		linePos = 0;
		hasTrailingCommentState = false;
	}

	public function Grow(n:Int):Void {
		builder.Grow(n);
	}

	public function DecreaseIndent():Void {
		indent--;
	}

	// GetColumn returns the column position measured in UTF-16 code units
	// for source map compatibility.
	public function GetColumn():UTF16Offset {
		if (lineStart) {
			return indent * indentSize;
		}
		// Count UTF-16 code units from the last line start.
		// For ASCII-only output (the common case), this equals the byte count.
		// PORT: utf16 — Go `core.UTF16Len(w.builder.String()[w.linePos:])`; positions are UTF-16
		// offsets here, so this is the length of the builder minus linePos (no string copy).
		return builder.Len() - linePos;
	}

	public function GetIndent():Int {
		return indent;
	}

	public function GetLine():Int {
		return lineCount;
	}

	public function String():std.String {
		return builder.String();
	}

	public function GetTextPos():Int {
		return builder.Len();
	}

	public function HasTrailingComment():Bool {
		return hasTrailingCommentState;
	}

	public function HasTrailingWhitespace():Bool {
		if (builder.Len() == 0) {
			return false;
		}
		final ch = Utf16.DecodeLastRuneInString(lastWritten);
		if (ch == Utf16.RuneError) {
			return false;
		}
		return Stringutil.IsWhiteSpaceLike(ch);
	}

	public function IncreaseIndent():Void {
		indent++;
	}

	public function IsAtStartOfLine():Bool {
		return lineStart;
	}

	public function RawWrite(s:std.String):Void {
		if (s != "") {
			builder.WriteString(s);
			lastWritten = s;
			hasTrailingCommentState = false;
		}
		updateLineCountAndPosFor(s);
	}

	function updateLineCountAndPosFor(s:std.String):Void {
		var count = 0;
		var lastLineStart:TextPos = 0;

		for (lineStart in lineStartsSeq.reset(s)) { // PORT: perf (Go: core.ComputeECMALineStartsSeq(s))
			count++;
			lastLineStart = lineStart;
		}

		if (count > 1) {
			lineCount += count - 1;
			final curLen = builder.Len();
			linePos = curLen - s.length + (lastLineStart : Int);
			lineStart = (linePos - curLen) == 0;
			return;
		}
		lineStart = false;
	}

	function writeText(s:std.String):Void {
		if (s != "") {
			if (lineStart) {
				builder.WriteString(Printer.getIndentString(indent, indentSize));
				lineStart = false;
			}
			builder.WriteString(s);
			lastWritten = s;
			updateLineCountAndPosFor(s);
		}
	}

	public function Write(s:std.String):Void {
		if (s != "") {
			hasTrailingCommentState = false;
		}
		writeText(s);
	}

	public function WriteComment(text:std.String):Void {
		if (text != "") {
			hasTrailingCommentState = true;
		}
		writeText(text);
	}

	public function WriteKeyword(text:std.String):Void {
		Write(text);
	}

	function writeLineRaw():Void {
		builder.WriteString(newLine);
		lastWritten = newLine;
		lineCount++;
		linePos = builder.Len();
		lineStart = true;
		hasTrailingCommentState = false;
	}

	public function WriteLine():Void {
		if (!lineStart) {
			writeLineRaw();
		}
	}

	public function WriteLineForce(force:Bool):Void {
		if (!lineStart || force) {
			writeLineRaw();
		}
	}

	public function WriteLiteral(s:std.String):Void {
		Write(s);
	}

	public function WriteOperator(text:std.String):Void {
		Write(text);
	}

	public function WriteParameter(text:std.String):Void {
		Write(text);
	}

	public function WriteProperty(text:std.String):Void {
		Write(text);
	}

	public function WritePunctuation(text:std.String):Void {
		Write(text);
	}

	public function WriteSpace(text:std.String):Void {
		Write(text);
	}

	public function WriteStringLiteral(text:std.String):Void {
		Write(text);
	}

	public function WriteSymbol(text:std.String, symbol:Symbol):Void {
		Write(text);
	}

	public function WriteTrailingSemicolon(text:std.String):Void {
		Write(text);
	}
}
