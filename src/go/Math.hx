package go;

import go.Tuple.Pair;
import haxe.Int64;
#if !cpp
import haxe.io.FPHelper;
#end

// Shims for Go package math.
// Functions that Go implements in pure Go on amd64 (Pow, Frexp, Ldexp, Modf, Log2) are ported
// from GOROOT/src/math, so results are bit-identical to Go on JS and hxcpp. Functions that are
// correctly rounded by IEEE 754 (Sqrt, Mod, Trunc, Floor, Abs) map to the native operation.
// PORT: Exp and Log use the native Math.exp / Math.log (Go uses amd64 assembly); results may
// differ from Go in the last bit. Only the non-integer-exponent branch of Pow and the
// non-power-of-two branch of Log2 use them.
class Math {
	public static inline final MaxInt32 = 2147483647;
	public static inline final MinInt32 = -2147483648;
	public static inline final MaxFloat64 = 1.79769313486231570814527423731704356798070e+308;
	public static inline final SmallestNonzeroFloat64 = 4.9406564584124654417656879286822137236505980e-324;
	public static inline final Pi = 3.14159265358979323846264338327950288419716939937510582097494459;
	public static inline final E = 2.71828182845904523536028747135266249775724709369995957496696763;
	public static inline final Ln2 = 0.693147180559945309417232121458176568075500134360255254120680009;

	static inline final mask = 0x7FF;
	static inline final shift = 64 - 11 - 1;
	static inline final bias = 1023;

	public static inline function NaN():Float {
		return std.Math.NaN;
	}

	// math.Inf: +Inf if sign >= 0, -Inf if sign < 0.
	public static inline function Inf(sign:Int):Float {
		return sign >= 0 ? std.Math.POSITIVE_INFINITY : std.Math.NEGATIVE_INFINITY;
	}

	public static inline function IsNaN(f:Float):Bool {
		return f != f;
	}

	// math.IsInf: sign > 0 → +Inf, sign < 0 → -Inf, sign == 0 → either.
	public static inline function IsInf(f:Float, sign:Int):Bool {
		return sign >= 0 && f > MaxFloat64 || sign <= 0 && f < -MaxFloat64;
	}

	// math.Float64bits: the uint64 bit pattern in a haxe.Int64.
	public static function Float64bits(f:Float):Int64 {
		return Int64.make(bitsHigh(f), bitsLow(f));
	}

	public static inline function Float64frombits(b:Int64):Float {
		return fromBits(b.low, b.high);
	}

	// Raw IEEE 754 bit casts. On hxcpp haxe.io.FPHelper needs cpp.marshal (not available with
	// every hxcpp version), so they are done in C++ directly.
	#if cpp
	@:functionCode('double d = f; unsigned long long u; memcpy(&u, &d, 8); return (int)(unsigned int)(u >> 32);')
	#end
	static function bitsHigh(f:Float):Int {
		#if cpp
		return 0;
		#else
		return FPHelper.doubleToI64(f).high;
		#end
	}

	#if cpp
	@:functionCode('double d = f; unsigned long long u; memcpy(&u, &d, 8); return (int)(unsigned int)u;')
	#end
	static function bitsLow(f:Float):Int {
		#if cpp
		return 0;
		#else
		return FPHelper.doubleToI64(f).low;
		#end
	}

	#if cpp
	@:functionCode('unsigned long long u = ((unsigned long long)(unsigned int)high << 32) | (unsigned int)low; double d; memcpy(&d, &u, 8); return d;')
	#end
	static function fromBits(low:Int, high:Int):Float {
		#if cpp
		return 0;
		#else
		return FPHelper.i64ToDouble(low, high);
		#end
	}

	// math.Signbit
	public static inline function Signbit(x:Float):Bool {
		return bitsHigh(x) < 0;
	}

	// math.Copysign
	public static function Copysign(f:Float, sign:Float):Float {
		return fromBits(bitsLow(f), (bitsHigh(f) & 0x7FFFFFFF) | (bitsHigh(sign) & 0x80000000));
	}

	public static inline function Abs(x:Float):Float {
		return Copysign(x, 1);
	}

	// math.Trunc
	public static function Trunc(x:Float):Float {
		if (x == 0 || IsNaN(x) || IsInf(x, 0))
			return x;
		return x < 0 ? std.Math.fceil(x) : std.Math.ffloor(x);
	}

	// math.Floor
	public static function Floor(x:Float):Float {
		if (x == 0 || IsNaN(x) || IsInf(x, 0))
			return x;
		return std.Math.ffloor(x);
	}

	// math.Ceil
	public static function Ceil(x:Float):Float {
		if (x == 0 || IsNaN(x) || IsInf(x, 0))
			return x;
		final r = std.Math.fceil(x);
		// Go: Ceil(-0.5) = -0
		return r == 0 && x < 0 ? -0.0 : r;
	}

	// math.Min: special cases as in Go (-Inf wins, then NaN, then -0 < +0).
	public static function Min(x:Float, y:Float):Float {
		if (IsInf(x, -1) || IsInf(y, -1))
			return Inf(-1);
		if (IsNaN(x) || IsNaN(y))
			return NaN();
		if (x == 0 && x == y) {
			if (Signbit(x))
				return x;
			return y;
		}
		if (x < y)
			return x;
		return y;
	}

	// math.Mod: IEEE fmod; exact, the same as JS % and C fmod.
	public static inline function Mod(x:Float, y:Float):Float {
		return x % y;
	}

	public static inline function Sqrt(x:Float):Float {
		return std.Math.sqrt(x);
	}

	// PORT: native, see header.
	public static inline function Exp(x:Float):Float {
		return std.Math.exp(x);
	}

	// PORT: native, see header.
	public static inline function Log(x:Float):Float {
		return std.Math.log(x);
	}

	// math.Log2
	public static function Log2(x:Float):Float {
		final fe = Frexp(x);
		final frac = fe.a;
		final exp = fe.b;
		// Make sure exact powers of two give an exact answer.
		// Don't depend on Log(0.5)*(1/Ln2)+exp being exactly exp-1.
		if (frac == 0.5) {
			return exp - 1;
		}
		return Log(frac) * (1 / Ln2) + exp;
	}

	static function normalize(x:Float):Pair<Float, Int> {
		final SmallestNormal = 2.2250738585072014e-308; // 2**-1022
		if (Abs(x) < SmallestNormal) {
			return new Pair(x * 4503599627370496.0 /* 1 << 52 */, -52);
		}
		return new Pair(x, 0);
	}

	// Biased exponent field of x (bits 52..62).
	static inline function expBits(x:Float):Int {
		return (bitsHigh(x) >>> 20) & mask;
	}

	// x with its exponent field replaced by e (biased).
	static inline function withExpBits(x:Float, e:Int):Float {
		return fromBits(bitsLow(x), (bitsHigh(x) & ~(mask << 20)) | (e << 20));
	}

	// math.Frexp: (frac, exp).
	public static function Frexp(f:Float):Pair<Float, Int> {
		// special cases
		if (f == 0) {
			return new Pair(f, 0); // correctly return -0
		}
		if (IsInf(f, 0) || IsNaN(f)) {
			return new Pair(f, 0);
		}
		final n = normalize(f);
		f = n.a;
		var exp = n.b;
		exp += expBits(f) - bias + 1;
		return new Pair(withExpBits(f, -1 + bias), exp);
	}

	// math.Ldexp
	public static function Ldexp(frac:Float, exp:Int):Float {
		// special cases
		if (frac == 0) {
			return frac; // correctly return -0
		}
		if (IsInf(frac, 0) || IsNaN(frac)) {
			return frac;
		}
		final n = normalize(frac);
		frac = n.a;
		exp += n.b;
		exp += expBits(frac) - bias;
		if (exp < -1075) {
			return Copysign(0, frac); // underflow
		}
		if (exp > 1023) { // overflow
			if (frac < 0) {
				return Inf(-1);
			}
			return Inf(1);
		}
		var m:Float = 1;
		if (exp < -1022) { // denormal
			exp += 53;
			m = 1.0 / 9007199254740992.0; // 2**-53
		}
		return m * withExpBits(frac, exp + bias);
	}

	// math.Modf: (int, frac).
	public static function Modf(f:Float):Pair<Float, Float> {
		if (f < 1) {
			if (f < 0) {
				final r = Modf(-f);
				return new Pair(-r.a, -r.b);
			} else if (f == 0) {
				return new Pair(f, f);
			}
			return new Pair(0.0, f);
		}
		// PORT: Go clears the fraction bits of the mantissa; for f >= 1 this equals Trunc.
		final int_ = Trunc(f);
		return new Pair(int_, f - int_);
	}

	static function isOddInt(x:Float):Bool {
		if (Abs(x) >= 9007199254740992.0 /* 1 << 53 */) {
			return false;
		}
		final m = Modf(x);
		// int64(xi)&1 == 1, with |xi| < 2^53
		return m.b == 0 && Mod(m.a, 2) != 0;
	}

	// math.Pow (port of GOROOT/src/math/pow.go)
	public static function Pow(x:Float, y:Float):Float {
		if (y == 0 || x == 1) {
			return 1;
		} else if (y == 1) {
			return x;
		} else if (IsNaN(x) || IsNaN(y)) {
			return NaN();
		} else if (x == 0) {
			if (y < 0) {
				if (Signbit(x) && isOddInt(y)) {
					return Inf(-1);
				}
				return Inf(1);
			} else if (y > 0) {
				if (Signbit(x) && isOddInt(y)) {
					return x;
				}
				return 0;
			}
		} else if (IsInf(y, 0)) {
			if (x == -1) {
				return 1;
			} else if ((Abs(x) < 1) == IsInf(y, 1)) {
				return 0;
			} else {
				return Inf(1);
			}
		} else if (IsInf(x, 0)) {
			if (IsInf(x, -1)) {
				return Pow(1 / x, -y); // Pow(-0, -y)
			}
			if (y < 0) {
				return 0;
			} else if (y > 0) {
				return Inf(1);
			}
		} else if (y == 0.5) {
			return Sqrt(x);
		} else if (y == -0.5) {
			return 1 / Sqrt(x);
		}

		final mf = Modf(Abs(y));
		var yi = mf.a;
		var yf = mf.b;
		if (yf != 0 && x < 0) {
			return NaN();
		}
		if (yi >= 9223372036854775808.0 /* 1 << 63 */) {
			// yi is a large even int that will lead to overflow (or underflow to 0)
			// for all x except -1 (x == 1 was handled earlier)
			if (x == -1) {
				return 1;
			} else if ((Abs(x) < 1) == (y > 0)) {
				return 0;
			} else {
				return Inf(1);
			}
		}

		// ans = a1 * 2**ae (= 1 for now).
		var a1 = 1.0;
		var ae = 0;

		// ans *= x**yf
		if (yf != 0) {
			if (yf > 0.5) {
				yf--;
				yi++;
			}
			a1 = Exp(yf * Log(x));
		}

		// ans *= x**yi
		// by multiplying in successive squarings
		// of x according to bits of yi.
		// accumulate powers of two into exp.
		final fe = Frexp(x);
		var x1 = fe.a;
		var xe = fe.b;
		// PORT: Go iterates `for i := int64(yi); i != 0; i >>= 1`; yi < 2^63 is an integer, so
		// the bits of i are taken from the Float with exact halving.
		var i = yi;
		while (i != 0) {
			if (xe < -(1 << 12) || (1 << 12) < xe) {
				// catch xe before it overflows the left shift below
				// Since i !=0 it has at least one bit still set, so ae will accumulate xe
				// on at least one more iteration, ae += xe is a lower bound on ae
				// the lower bound on ae exceeds the size of a float64 exp
				// so the final call to Ldexp will produce under/overflow (0/Inf)
				ae += xe;
				break;
			}
			if (Mod(i, 2) == 1) {
				a1 *= x1;
				ae += xe;
			}
			x1 *= x1;
			xe <<= 1;
			if (x1 < .5) {
				x1 += x1;
				xe--;
			}
			i = std.Math.ffloor(i / 2);
		}

		// ans = a1*2**ae
		// if y < 0 { ans = 1 / ans }
		// but in the opposite order
		if (y < 0) {
			a1 = 1 / a1;
			ae = -ae;
		}
		return Ldexp(a1, ae);
	}
}
