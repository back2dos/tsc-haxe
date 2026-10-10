package go;

import go.Tuple.ValueOk;
import haxe.Int64;

// Shims for Go package math/big: only what the port needs (non-negative magnitudes with a
// sign, exact multiplication/power, parse, decimal String, conversion to float64 with
// round-to-nearest-even).
// PORT: Go types big.Int / big.Float are named BigInt / BigFloat (Int and Float are Haxe core
// types). Float64() returns only the value; Go's big.Accuracy result is dropped.
class Big {
	// big.NewInt
	public static function NewInt(x:Int64):BigInt {
		return new BigInt().SetInt64(x);
	}
}

// Magnitude helpers. A magnitude is a little-endian Array<Int> of 15-bit limbs without
// leading (high) zero limbs; zero is [].
private class Nat {
	public static inline final W = 15;
	public static inline final B = 1 << W;
	public static inline final M = B - 1;

	public static function norm(a:Array<Int>):Array<Int> {
		var n = a.length;
		while (n > 0 && a[n - 1] == 0)
			n--;
		if (n < a.length)
			a.resize(n);
		return a;
	}

	public static function mul(a:Array<Int>, b:Array<Int>):Array<Int> {
		if (a.length == 0 || b.length == 0)
			return [];
		final r = [for (_ in 0...a.length + b.length) 0];
		for (i in 0...a.length) {
			var carry = 0;
			final ai = a[i];
			for (j in 0...b.length) {
				final t = r[i + j] + ai * b[j] + carry;
				r[i + j] = t & M;
				carry = t >>> W;
			}
			var k = i + b.length;
			while (carry != 0) {
				final t = r[k] + carry;
				r[k] = t & M;
				carry = t >>> W;
				k++;
			}
		}
		return norm(r);
	}

	// a = a*m + d in place (m, d < 2^15).
	public static function mulAddSmall(a:Array<Int>, m:Int, d:Int):Array<Int> {
		var carry = d;
		for (i in 0...a.length) {
			final t = a[i] * m + carry;
			a[i] = t & M;
			carry = t >>> W;
		}
		while (carry != 0) {
			a.push(carry & M);
			carry = carry >>> W;
		}
		return norm(a);
	}

	// a = a / d in place, returns the remainder (d < 2^15).
	public static function divSmall(a:Array<Int>, d:Int):Int {
		var rem = 0;
		var i = a.length - 1;
		while (i >= 0) {
			final t = rem * B + a[i];
			a[i] = Std.int(t / d);
			rem = t - a[i] * d;
			i--;
		}
		norm(a);
		return rem;
	}

	public static function bitLen(a:Array<Int>):Int {
		if (a.length == 0)
			return 0;
		var top = a[a.length - 1];
		var n = 0;
		while (top != 0) {
			n++;
			top >>>= 1;
		}
		return (a.length - 1) * W + n;
	}

	public static inline function bit(a:Array<Int>, i:Int):Int {
		final li = Std.int(i / W);
		return li < a.length ? (a[li] >>> (i % W)) & 1 : 0;
	}

	// a >> s
	public static function shr(a:Array<Int>, s:Int):Array<Int> {
		final ls = Std.int(s / W);
		final bs = s % W;
		final n = a.length - ls;
		if (n <= 0)
			return [];
		final r = [for (_ in 0...n) 0];
		for (i in 0...n) {
			var v = a[i + ls] >>> bs;
			if (bs != 0 && i + ls + 1 < a.length)
				v |= (a[i + ls + 1] << (W - bs)) & M;
			r[i] = v;
		}
		return norm(r);
	}

	// true if any of the low s bits of a are set.
	public static function anyLowBits(a:Array<Int>, s:Int):Bool {
		for (i in 0...s)
			if (bit(a, i) != 0)
				return true;
		return false;
	}

	// a + 1
	public static function inc(a:Array<Int>):Array<Int> {
		final r = a.copy();
		var i = 0;
		while (true) {
			if (i == r.length) {
				r.push(1);
				break;
			}
			r[i]++;
			if (r[i] < B)
				break;
			r[i] = 0;
			i++;
		}
		return r;
	}

	// Rounds a to at most prec significant bits, round half to even.
	// Returns the mantissa; the value is mantissa * 2^shift with shift in `shiftOut[0]`.
	public static function round(a:Array<Int>, prec:Int, shiftOut:Array<Int>):Array<Int> {
		final n = bitLen(a);
		if (n <= prec) {
			shiftOut[0] = 0;
			return a.copy();
		}
		final s = n - prec;
		var q = shr(a, s);
		final half = bit(a, s - 1) != 0;
		if (half && (anyLowBits(a, s - 1) || bit(q, 0) != 0))
			q = inc(q);
		shiftOut[0] = s;
		return q;
	}

	// mantissa * 2^shift as a Float; mantissa has at most 53 bits after round(.., 53, ..).
	public static function toFloat(m:Array<Int>, shift:Int):Float {
		var f = 0.0;
		var i = m.length - 1;
		while (i >= 0) {
			f = f * B + m[i]; // exact: f < 2^54
			i--;
		}
		// multiply by 2^shift in exact steps (overflow gives +Inf as in IEEE rounding)
		while (shift > 0 && f != std.Math.POSITIVE_INFINITY) {
			final k = shift > 1000 ? 1000 : shift;
			f *= pow2(k);
			shift -= k;
		}
		return f;
	}

	static function pow2(k:Int):Float {
		// 2^k for 0 <= k <= 1023
		return Math.Float64frombits(Int64.make((k + 1023) << 20, 0));
	}
}

// big.Int
class BigInt {
	public var neg:Bool = false;
	public var abs:Array<Int> = [];

	public function new() {}

	// (*big.Int).SetInt64
	public function SetInt64(x:Int64):BigInt {
		neg = x < 0;
		var u = neg ? -x : x; // -MinInt64 == MinInt64; read as unsigned below
		abs = [];
		var hi:Float = u.high < 0 ? u.high + 4294967296.0 : u.high;
		var lo:Float = u.low < 0 ? u.low + 4294967296.0 : u.low;
		// split the 64-bit unsigned value into 15-bit limbs
		var limbs:Array<Int> = [];
		var vhi = hi;
		var vlo = lo;
		while (vhi != 0 || vlo != 0) {
			// (vhi*2^32 + vlo) mod 2^15, then divide by 2^15
			final r = Std.int(vlo % Nat.B);
			limbs.push(r);
			final hiRem = vhi % Nat.B;
			vhi = std.Math.ffloor(vhi / Nat.B);
			vlo = std.Math.ffloor(vlo / Nat.B) + hiRem * (4294967296.0 / Nat.B);
		}
		abs = Nat.norm(limbs);
		return this;
	}

	// (*big.Int).Sign
	public function Sign():Int {
		if (abs.length == 0)
			return 0;
		return neg ? -1 : 1;
	}

	// (*big.Int).Exp: z = x**y. PORT: m must be nil (no modular exponentiation); y must fit in
	// 31 bits. y <= 0 → 1.
	public function Exp(x:BigInt, y:BigInt, m:Null<BigInt>):BigInt {
		if (m != null)
			throw "Big.Exp: modulus not implemented";
		if (y.neg || y.abs.length == 0) {
			neg = false;
			abs = [1];
			return this;
		}
		if (Nat.bitLen(y.abs) > 31)
			throw "Big.Exp: exponent too large";
		var e = 0;
		var i = y.abs.length - 1;
		while (i >= 0) {
			e = e * Nat.B + y.abs[i];
			i--;
		}
		final odd = (e & 1) == 1;
		var result:Array<Int> = [1];
		var base = x.abs.copy();
		while (e != 0) {
			if ((e & 1) == 1)
				result = Nat.mul(result, base);
			e >>>= 1;
			if (e != 0)
				base = Nat.mul(base, base);
		}
		abs = result;
		neg = x.neg && odd && result.length != 0;
		return this;
	}

	// (*big.Int).SetString. Returns (z, ok). Base 0 accepts the prefixes 0b, 0o, 0x, a
	// leading 0 for octal, and '_' separators between digits (math/big natconv scan rules).
	public function SetString(s:String, base:Int):ValueOk<BigInt> {
		if (!(base == 0 || 2 <= base && base <= 36))
			throw "invalid number base " + base;
		var pos = 0;
		final len = s.length;
		inline function ch():Int
			return pos < len ? StringTools.fastCodeAt(s, pos) : -1;

		// sign
		var negative = false;
		if (ch() == '+'.code || ch() == '-'.code) {
			negative = ch() == '-'.code;
			pos++;
		}

		var prev = '.'.code;
		var invalSep = false;
		var count = 0;
		var b = base;
		var prefix = 0;
		if (base == 0) {
			b = 10;
			if (ch() == '0'.code) {
				prev = '0'.code;
				count = 1;
				pos++;
				if (pos < len) {
					switch (ch()) {
						case 'b'.code, 'B'.code:
							b = 2;
							prefix = 'b'.code;
						case 'o'.code, 'O'.code:
							b = 8;
							prefix = 'o'.code;
						case 'x'.code, 'X'.code:
							b = 16;
							prefix = 'x'.code;
						default:
							b = 8;
							prefix = '0'.code;
					}
					if (prefix != 0) {
						count = 0; // prefix is not counted
						if (prefix != '0'.code)
							pos++;
					}
				}
			}
		}

		var z:Array<Int> = [];
		while (pos < len) {
			final c = ch();
			if (c == '_'.code && base == 0) {
				if (prev != '0'.code)
					invalSep = true;
				prev = '_'.code;
			} else {
				var d1:Int;
				if ('0'.code <= c && c <= '9'.code)
					d1 = c - '0'.code;
				else if ('a'.code <= c && c <= 'z'.code)
					d1 = c - 'a'.code + 10;
				else if ('A'.code <= c && c <= 'Z'.code)
					d1 = c - 'A'.code + 10;
				else
					d1 = 1000;
				if (d1 >= b)
					break; // ch does not belong to number anymore
				prev = '0'.code;
				count++;
				z = Nat.mulAddSmall(z, b, d1);
			}
			pos++;
		}

		var ok = true;
		if (invalSep || prev == '_'.code)
			ok = false;
		if (count == 0) {
			if (prefix == '0'.code) {
				// only the octal prefix 0: decimal 0
				z = [];
			} else {
				ok = false;
			}
		}
		// SetString requires the entire string to be consumed.
		if (pos != len)
			ok = false;
		if (!ok)
			return new ValueOk<BigInt>(null, false);
		abs = z;
		neg = negative && z.length != 0;
		return new ValueOk<BigInt>(this, true);
	}

	// (*big.Int).String: base 10.
	public function String():String {
		if (abs.length == 0)
			return "0";
		final a = abs.copy();
		final chunks:Array<Int> = [];
		while (a.length != 0)
			chunks.push(Nat.divSmall(a, 10000));
		final sb = new StringBuf();
		if (neg)
			sb.add("-");
		var i = chunks.length - 1;
		sb.add(chunks[i]);
		i--;
		while (i >= 0) {
			sb.add(StringTools.lpad(Std.string(chunks[i]), "0", 4));
			i--;
		}
		return sb.toString();
	}

	public function toString():String {
		return String();
	}

	// (*big.Int).Float64: nearest float64, round half to even. PORT: accuracy dropped.
	public function Float64():Float {
		final sh = [0];
		final m = Nat.round(abs, 53, sh);
		final f = Nat.toFloat(m, sh[0]);
		return neg ? -f : f;
	}
}

// big.Float: only SetPrec, SetInt and Float64 (mode ToNearestEven).
class BigFloat {
	var prec:Int = 0;
	var neg:Bool = false;
	var mant:Array<Int> = [];
	var exp:Int = 0;

	public function new() {}

	// (*big.Float).SetPrec. PORT: does not re-round an existing value (only used before SetInt).
	public function SetPrec(prec:Int):BigFloat {
		this.prec = prec;
		return this;
	}

	// (*big.Float).SetInt: rounds x to prec bits (prec 0 → exact, as Go uses max(64, bitLen)).
	public function SetInt(x:BigInt):BigFloat {
		neg = x.neg;
		final bits = Nat.bitLen(x.abs);
		if (prec == 0)
			prec = bits > 64 ? bits : 64;
		final sh = [0];
		mant = Nat.round(x.abs, prec, sh);
		exp = sh[0];
		return this;
	}

	// (*big.Float).Float64: nearest float64, round half to even. PORT: accuracy dropped.
	// Only values >= 1 in magnitude (set from integers) are supported.
	public function Float64():Float {
		final sh = [0];
		final m = Nat.round(mant, 53, sh);
		final f = Nat.toFloat(m, sh[0] + exp);
		return neg ? -f : f;
	}
}
