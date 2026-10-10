package ts.jsnum;

// --- pseudobigint.go ---

// PseudoBigInt represents a JS-like bigint. The zero state of the struct represents the value 0.
// Immutable value type (all fields final), no copy() needed.
final class PseudoBigInt {
	public final Negative:Bool; // true if the value is a non-zero negative number.
	public final Base10Value:String; // The absolute value in base 10 with no leading zeros. The value zero is represented as an empty string.

	public function new(Negative:Bool = false, Base10Value:String = "") {
		this.Negative = Negative;
		this.Base10Value = Base10Value;
	}

	public function String():String {
		if (Base10Value.length == 0) {
			return "0";
		}
		if (Negative) {
			return "-" + Base10Value;
		}
		return Base10Value;
	}

	public function toString():String {
		return String();
	}

	public function Sign():Int {
		if (Base10Value.length == 0) {
			return 0;
		}
		if (Negative) {
			return -1;
		}
		return 1;
	}
}
