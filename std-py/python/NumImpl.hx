package python;

import python.internal.UBuiltins;

// PORT: python — JS/IEEE 754 results for the std Math functions where Python's math module differs
// (used by the Math override in std-py/Math.hx):
// - math.floor/ceil return an int (and lose -0); Math.ffloor/fceil/fround must return a float
//   with the sign of zero kept, as on JS.
// - math.pow and math.exp raise OverflowError/ValueError where IEEE 754 gives ±Inf or NaN.
class NumImpl {
	static inline function m():Dynamic {
		return python.lib.Math;
	}

	public static function ffloor(v:Float):Float {
		if (v == 0 || !Syntax.code("{0}.isfinite({1})", m(), v))
			return UBuiltins.float(v);
		return UBuiltins.float(Syntax.code("{0}.floor({1})", m(), v));
	}

	public static function fceil(v:Float):Float {
		if (v == 0 || !Syntax.code("{0}.isfinite({1})", m(), v))
			return UBuiltins.float(v);
		final r:Float = UBuiltins.float(Syntax.code("{0}.ceil({1})", m(), v));
		return r == 0 && v < 0 ? -0.0 : r;
	}

	public static function fround(v:Float):Float {
		if (v == 0 || !Syntax.code("{0}.isfinite({1})", m(), v))
			return UBuiltins.float(v);
		final r:Float = UBuiltins.float(Syntax.code("{0}.floor({1})", m(), v + 0.5));
		return r == 0 && v < 0 ? -0.0 : r;
	}

	public static function pow(v:Float, exp:Float):Float {
		if (exp != exp || ((v == 1 || v == -1) && !Syntax.code("{0}.isfinite({1})", m(), exp)))
			return Math.NaN; // JS: 1 ** NaN, (±1) ** ±Infinity are NaN (Python: 1.0)
		try {
			return Syntax.code("{0}.pow({1}, {2})", m(), v, exp);
		} catch (e:Dynamic) {
			final isInt = Syntax.code("{0}.isfinite({1})", m(), exp) && exp == Syntax.code("{0}.floor({1})", m(), exp);
			final oddInt = isInt && UBuiltins.int(exp) % 2 != 0;
			if (v == 0) // 0 ** negative
				return Syntax.code("{0}.copysign({1}, {2})", m(), 1.0, v) < 0 && oddInt ? Math.NEGATIVE_INFINITY : Math.POSITIVE_INFINITY;
			if (v > 0) // overflow
				return Math.POSITIVE_INFINITY;
			if (isInt) // negative ** integer: overflow
				return oddInt ? Math.NEGATIVE_INFINITY : Math.POSITIVE_INFINITY;
			return Math.NaN; // negative ** non-integer
		}
	}

	public static function exp(v:Float):Float {
		try {
			return Syntax.code("{0}.exp({1})", m(), v);
		} catch (e:Dynamic) {
			return Math.POSITIVE_INFINITY; // OverflowError: only for large positive v
		}
	}
}
