package ts.core;

// Port of text.go (types and methods; CompareTextRanges is in Core.hx).

// TextPos
// PORT: Go `type TextPos int32` → abstract over Int with implicit Int conversions (Go code
// converts with TextPos(x) / int(p) everywhere). Positions are UTF-16 offsets (PORTING.md §5).
abstract TextPos(Int) from Int to Int {
	@:op(A + B) static function add(a:TextPos, b:TextPos):TextPos;

	@:op(A - B) static function sub(a:TextPos, b:TextPos):TextPos;

	@:op(A < B) static function lt(a:TextPos, b:TextPos):Bool;

	@:op(A <= B) static function lte(a:TextPos, b:TextPos):Bool;

	@:op(A > B) static function gt(a:TextPos, b:TextPos):Bool;

	@:op(A >= B) static function gte(a:TextPos, b:TextPos):Bool;

	@:op(A++) inline function postInc():TextPos {
		return this++;
	}

	@:op(++A) inline function preInc():TextPos {
		return ++this;
	}

	@:op(A--) inline function postDec():TextPos {
		return this--;
	}

	@:op(--A) inline function preDec():TextPos {
		return --this;
	}
}

// TextRange
// PORT: Go value struct → immutable final class (all fields final, PORTING.md §3: no copy()
// needed). The constructor and all methods are `inline`, so when the result is consumed
// directly (e.g. through an inline `Loc` property of a node that stores pos/end as Int fields)
// Haxe's inline-constructor optimization removes the temporary object.
// Go `TextRange{}` (zero value) → `new TextRange(0, 0)`.
@:allow(ts.core)
final class TextRange {
	final pos:Int;
	final end:Int;

	public inline function new(pos:Int, end:Int) {
		this.pos = pos;
		this.end = end;
	}

	public inline function Pos():Int {
		return pos;
	}

	public inline function End():Int {
		return end;
	}

	public inline function Len():Int {
		return end - pos;
	}

	public inline function IsValid():Bool {
		return pos >= 0 || end >= 0;
	}

	public inline function Contains(pos:Int):Bool {
		return pos >= this.pos && pos < this.end;
	}

	public inline function ContainsInclusive(pos:Int):Bool {
		return pos >= this.pos && pos <= this.end;
	}

	public inline function ContainsExclusive(pos:Int):Bool {
		return this.pos < pos && pos < this.end;
	}

	public inline function WithPos(pos:Int):TextRange {
		return new TextRange(pos, this.end);
	}

	public inline function WithEnd(end:Int):TextRange {
		return new TextRange(this.pos, end);
	}

	public inline function ContainedBy(t2:TextRange):Bool {
		return t2.pos <= pos && t2.end >= end;
	}

	public inline function Overlaps(t2:TextRange):Bool {
		final start = pos > t2.pos ? pos : t2.pos;
		final end = this.end < t2.end ? this.end : t2.end;
		return start < end;
	}

	// Similar to Overlaps, but treats touching ranges as intersecting.
	// For example, [0, 5) intersects [5, 10).
	public inline function Intersects(t2:TextRange):Bool {
		final start = pos > t2.pos ? pos : t2.pos;
		final end = this.end < t2.end ? this.end : t2.end;
		return start <= end;
	}

	// PORT: Go struct equality `t == t2` (no Haxe equivalent for value comparison).
	public inline function Equals(t2:TextRange):Bool {
		return pos == t2.pos && end == t2.end;
	}

	// PORT: for debugging output only (Go prints `{pos end}` with %v).
	public function toString():String {
		return '{$pos $end}';
	}
}
