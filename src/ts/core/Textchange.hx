package ts.core;

// Port of textchange.go (ApplyBulkEdits is in Core.hx).
// Go value struct with an embedded TextRange → composition field `TextRange` (PORTING.md §3).
// Go `TextChange{}` → `new TextChange()`.
class TextChange {
	public var TextRange:TextRange = new TextRange(0, 0);
	public var NewText:String = "";

	public function new(?TextRange:TextRange, NewText:String = "") {
		if (TextRange != null)
			this.TextRange = TextRange;
		this.NewText = NewText;
	}

	public function copy():TextChange {
		return new TextChange(this.TextRange, this.NewText);
	}

	// PORT: methods promoted from the embedded TextRange.
	public inline function Pos():Int {
		return this.TextRange.Pos();
	}

	public inline function End():Int {
		return this.TextRange.End();
	}

	public inline function Len():Int {
		return this.TextRange.Len();
	}

	public function ApplyTo(text:String):String {
		return text.substring(0, this.Pos()) + this.NewText + text.substring(this.End());
	}
}
