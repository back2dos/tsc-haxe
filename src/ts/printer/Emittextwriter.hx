package ts.printer;

// Port of emittextwriter.go.

// Externally opaque interface for printing text
interface EmitTextWriter {
	function Write(s:std.String):Void;
	function WriteTrailingSemicolon(text:std.String):Void;
	function WriteComment(text:std.String):Void;
	function WriteKeyword(text:std.String):Void;
	function WriteOperator(text:std.String):Void;
	function WritePunctuation(text:std.String):Void;
	function WriteSpace(text:std.String):Void;
	function WriteStringLiteral(text:std.String):Void;
	function WriteParameter(text:std.String):Void;
	function WriteProperty(text:std.String):Void;
	function WriteSymbol(text:std.String, symbol:Symbol):Void;
	function WriteLine():Void;
	function WriteLineForce(force:Bool):Void;
	function IncreaseIndent():Void;
	function DecreaseIndent():Void;
	function Clear():Void;
	function String():std.String;
	function RawWrite(s:std.String):Void;
	function WriteLiteral(s:std.String):Void;
	function GetTextPos():Int;
	function GetLine():Int;
	function GetColumn():UTF16Offset;
	function GetIndent():Int;
	function IsAtStartOfLine():Bool;
	function HasTrailingComment():Bool;
	function HasTrailingWhitespace():Bool;
}

// PORT: Go `p.writer.(interface{ Grow(n int) })` (an anonymous interface in Printer.Write) → a
// named interface; textWriter and ChangeTrackerWriter (promoted Grow) implement it.
interface Grower {
	function Grow(n:Int):Void;
}
