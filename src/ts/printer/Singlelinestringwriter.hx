package ts.printer;

import go.Strings.Builder;

// Port of singlelinestringwriter.go (type singleLineStringWriter and its methods;
// GetSingleLineStringWriter is a package static in class Printer).

// PORT: unexported Go type `singleLineStringWriter` → SingleLineStringWriter (PORTING.md §1).
class SingleLineStringWriter implements EmitTextWriter {
	public var builder:Builder = new Builder();
	public var lastWritten:std.String = "";

	public function new() {}

	public function Clear():Void {
		lastWritten = "";
		builder.Reset();
	}

	public function DecreaseIndent():Void {
		// Do Nothing
	}

	public function GetColumn():UTF16Offset {
		return 0;
	}

	public function GetIndent():Int {
		return 0;
	}

	public function GetLine():Int {
		return 0;
	}

	public function String():std.String {
		return builder.String();
	}

	public function GetTextPos():Int {
		return builder.Len();
	}

	public function HasTrailingComment():Bool {
		return false;
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
		// Do Nothing
	}

	public function IsAtStartOfLine():Bool {
		return false;
	}

	public function RawWrite(s:std.String):Void {
		lastWritten = s;
		builder.WriteString(s);
	}

	public function Write(s:std.String):Void {
		lastWritten = s;
		builder.WriteString(s);
	}

	public function WriteComment(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteKeyword(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteLine():Void {
		lastWritten = " ";
		builder.WriteString(" ");
	}

	public function WriteLineForce(force:Bool):Void {
		lastWritten = " ";
		builder.WriteString(" ");
	}

	public function WriteLiteral(s:std.String):Void {
		lastWritten = s;
		builder.WriteString(s);
	}

	public function WriteOperator(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteParameter(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteProperty(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WritePunctuation(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteSpace(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteStringLiteral(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteSymbol(text:std.String, symbol:Symbol):Void {
		lastWritten = text;
		builder.WriteString(text);
	}

	public function WriteTrailingSemicolon(text:std.String):Void {
		lastWritten = text;
		builder.WriteString(text);
	}
}
