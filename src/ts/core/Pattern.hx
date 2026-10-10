package ts.core;

// Port of pattern.go (types and methods; TryParsePattern and FindBestPatternMatch are in Core.hx).
// PORT: Go value struct; upstream never assigns its fields after construction, so it is an
// immutable class (final fields, PORTING.md §3). Go `Pattern{}` → `new Pattern()`.
class Pattern {
	public final Text:String;
	public final StarIndex:Int; // -1 for exact match

	public function new(Text:String = "", StarIndex:Int = 0) {
		this.Text = Text;
		this.StarIndex = StarIndex;
	}

	public function IsValid():Bool {
		return this.StarIndex == -1 || this.StarIndex < this.Text.length;
	}

	public function Matches(candidate:String):Bool {
		if (this.StarIndex == -1) {
			return this.Text == candidate;
		}
		return candidate.length >= this.Text.length - 1
			&& StringTools.startsWith(candidate, this.Text.substring(0, this.StarIndex))
			&& StringTools.endsWith(candidate, this.Text.substring(this.StarIndex + 1));
	}

	public function MatchedText(candidate:String):String {
		if (!this.Matches(candidate)) {
			throw "candidate does not match pattern";
		}
		if (this.StarIndex == -1) {
			return "";
		}
		return candidate.substring(this.StarIndex, candidate.length - this.Text.length + this.StarIndex + 1);
	}

	// PORT: Go struct equality `p == q` / `p != core.Pattern{}`.
	public function Equals(other:Pattern):Bool {
		return this.Text == other.Text && this.StarIndex == other.StarIndex;
	}
}
