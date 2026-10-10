package ts.jsnum;

// --- string.go --- (methods of Number; package-level functions are in Jsnum.hx)
// PORT: module named String_ because String.hx would shadow the String type.
class String_ {
	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-tostring
	public static function String(n:Number):String {
		if (n.IsNaN()) {
			return "NaN";
		} else if (n.IsInf()) {
			if (n < 0) {
				return "-Infinity";
			}
			return "Infinity";
		}

		// Fast path: for safe integers, directly convert to string.
		if (Jsnum.MinSafeInteger <= n && n <= Jsnum.MaxSafeInteger) {
			final i = Jsnum.int64OfFloat(n);
			if (Jsnum.int64ToFloat(i) == (n : Float)) {
				return Strconv.FormatInt(i, 10);
			}
		}

		// Otherwise, the Go json package handles this correctly.
		// PORT: json.Marshal(float64) → Jsnum.marshalFloat64 (the Haxe Json shim uses haxe.Json,
		// whose float format differs per target).
		final b = Jsnum.marshalFloat64(n);
		return b;
	}
}
