package go;

import go.Errors;
import go.Tuple.ValueError;
import haxe.Int64;

// Shims for Go package strconv.
class Strconv {
	public static final ErrRange:Error = Errors.New("value out of range");
	public static final ErrSyntax:Error = Errors.New("invalid syntax");

	// strconv.ParseUint. The uint64 result is returned as the bit pattern in a haxe.Int64.
	// PORT: base 0 (prefixes, underscores) is not implemented; it throws.
	public static function ParseUint(s:String, base:Int, bitSize:Int):ParseUintResult {
		final fnParseUint = "ParseUint";
		if (s == "")
			return new ParseUintResult(0, syntaxError(fnParseUint, s));

		final s0 = s;
		if (2 <= base && base <= 36) {
			// valid base; nothing to do
		} else if (base == 0) {
			throw "Strconv.ParseUint: base 0 not implemented";
		} else {
			return new ParseUintResult(0, baseError(fnParseUint, s0, base));
		}

		if (bitSize == 0) {
			bitSize = 64;
		} else if (bitSize < 0 || bitSize > 64) {
			return new ParseUintResult(0, bitSizeError(fnParseUint, s0, bitSize));
		}

		// Cutoff is the smallest number such that cutoff*base > maxUint64.
		final cutoff = Int64.add(udivSmall(Int64.make(-1, -1), base), 1);
		// 1<<bitSize - 1. Haxe Int64.shl masks the count to 6 bits (1<<64 would be 1), so bitSize 64 is
		// special-cased to ^0.
		final maxVal = bitSize == 64 ? Int64.make(-1, -1) : Int64.sub(Int64.shl(Int64.ofInt(1), bitSize), 1);

		var n:Int64 = 0;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			var d:Int;
			if ('0'.code <= c && c <= '9'.code)
				d = c - '0'.code;
			else if ('a'.code <= (c | 0x20) && (c | 0x20) <= 'z'.code)
				d = (c | 0x20) - 'a'.code + 10;
			else
				return new ParseUintResult(0, syntaxError(fnParseUint, s0));

			if (d >= base)
				return new ParseUintResult(0, syntaxError(fnParseUint, s0));

			if (Int64.ucompare(n, cutoff) >= 0) {
				// n*base overflows
				return new ParseUintResult(maxVal, rangeError(fnParseUint, s0));
			}
			n = Int64.mul(n, base);

			final n1 = Int64.add(n, d);
			if (Int64.ucompare(n1, n) < 0 || Int64.ucompare(n1, maxVal) > 0) {
				// n+d overflows
				return new ParseUintResult(maxVal, rangeError(fnParseUint, s0));
			}
			n = n1;
		}

		return new ParseUintResult(n, null);
	}

	// Unsigned 64-bit x / d for 1 <= d <= 36.
	static function udivSmall(x:Int64, d:Int):Int64 {
		final hi:Float = x.high < 0 ? x.high + 4294967296.0 : x.high;
		final lo:Float = x.low < 0 ? x.low + 4294967296.0 : x.low;
		final qh = std.Math.floor(hi / d);
		final rem = hi - qh * d;
		final ql = std.Math.floor((rem * 4294967296.0 + lo) / d);
		return Int64.make(Std.int(qh >= 2147483648.0 ? qh - 4294967296.0 : qh), Std.int(ql >= 2147483648.0 ? ql - 4294967296.0 : ql));
	}

	static function syntaxError(fn:String, str:String):NumError {
		return new NumError(fn, str, ErrSyntax);
	}

	static function rangeError(fn:String, str:String):NumError {
		return new NumError(fn, str, ErrRange);
	}

	static function baseError(fn:String, str:String, base:Int):NumError {
		return new NumError(fn, str, Errors.New("invalid base " + base));
	}

	static function bitSizeError(fn:String, str:String, bitSize:Int):NumError {
		return new NumError(fn, str, Errors.New("invalid bit size " + bitSize));
	}

	// strconv.ParseInt.
	// PORT: base 0 is not implemented (see ParseUint).
	public static function ParseInt(s:String, base:Int, bitSize:Int):ValueError<Int64> {
		final fnParseInt = "ParseInt";

		if (s == "") {
			return new ValueError<Int64>(0, syntaxError(fnParseInt, s));
		}

		// Pick off leading sign.
		final s0 = s;
		var neg = false;
		if (StringTools.fastCodeAt(s, 0) == '+'.code) {
			s = s.substring(1);
		} else if (StringTools.fastCodeAt(s, 0) == '-'.code) {
			neg = true;
			s = s.substring(1);
		}

		// Convert unsigned and check range.
		final r = ParseUint(s, base, bitSize);
		final un = r.value;
		final err = r.err;
		if (err != null && (cast err : NumError).Err != ErrRange) {
			(cast err : NumError).Func = fnParseInt;
			(cast err : NumError).Num = s0;
			return new ValueError<Int64>(0, err);
		}

		if (bitSize == 0) {
			bitSize = 64; // IntSize
		}

		final cutoff = Int64.shl(Int64.ofInt(1), bitSize - 1); // uint64
		if (!neg && Int64.ucompare(un, cutoff) >= 0) {
			return new ValueError<Int64>(Int64.sub(cutoff, 1), rangeError(fnParseInt, s0));
		}
		if (neg && Int64.ucompare(un, cutoff) > 0) {
			return new ValueError<Int64>(Int64.neg(cutoff), rangeError(fnParseInt, s0));
		}
		var n = un;
		if (neg) {
			n = Int64.neg(n);
		}
		return new ValueError<Int64>(n, null);
	}

	// strconv.Atoi.
	// PORT: Go int is 64-bit; Haxe Int is 32-bit, so values outside the Int range give a range
	// error (Go accepts them up to 64 bits).
	public static function Atoi(s:String):ValueError<Int> {
		final r = ParseInt(s, 10, 32);
		if (r.err != null) {
			final ne:NumError = cast r.err;
			ne.Func = "Atoi";
			return new ValueError<Int>(Int64.toInt(r.value), r.err);
		}
		return new ValueError<Int>(Int64.toInt(r.value), null);
	}

	// strconv.FormatInt. PORT: only base 10.
	public static function FormatInt(i:Int64, base:Int):String {
		if (base != 10)
			throw "Strconv.FormatInt: base " + base + " not implemented";
		return Int64.toStr(i);
	}

	// strconv.FormatFloat for bitSize 64.
	// PORT: only prec -1 (shortest round-trip digits) and fmt 'e', 'f', 'g'; others throw.
	public static function FormatFloat(f:Float, fmt:Int, prec:Int, bitSize:Int):String {
		if (bitSize != 64 || prec != -1 || (fmt != 'e'.code && fmt != 'f'.code && fmt != 'g'.code))
			throw "Strconv.FormatFloat: not implemented";
		if (f != f)
			return "NaN";
		if (f == std.Math.POSITIVE_INFINITY)
			return "+Inf";
		if (f == std.Math.NEGATIVE_INFINITY)
			return "-Inf";
		final neg = Math.Signbit(f);
		final abs = neg ? -f : f;
		// digs: decimal digits d (no trailing zeros), value = 0.d * 10^dp
		var d = "";
		var dp = 0;
		if (abs != 0) {
			final e = StrconvFloat.shortest(abs);
			final ei = e.indexOf("e");
			final mant = e.substring(0, ei);
			d = mant.charAt(0) + (mant.length > 2 ? mant.substring(2) : "");
			var end = d.length;
			while (end > 1 && StringTools.fastCodeAt(d, end - 1) == '0'.code)
				end--;
			d = d.substring(0, end);
			dp = Std.parseInt(StringTools.replace(e.substring(ei + 1), "+", "")) + 1;
		}
		final nd = d.length;
		var shortestPrec = 0;
		switch (fmt) {
			case 'e'.code:
				shortestPrec = nd - 1;
			case 'f'.code:
				shortestPrec = nd - dp > 0 ? nd - dp : 0;
			default:
				shortestPrec = nd;
		}
		if (fmt == 'g'.code) {
			var eprec = 6; // shortest
			final exp = dp - 1;
			if (exp < -4 || exp >= eprec) {
				return fmtE(neg, d, dp, shortestPrec - 1);
			}
			return fmtF(neg, d, dp, shortestPrec - dp > 0 ? shortestPrec - dp : 0);
		}
		if (fmt == 'e'.code)
			return fmtE(neg, d, dp, shortestPrec);
		return fmtF(neg, d, dp, shortestPrec);
	}

	// %e: -d.ddddde±dd
	static function fmtE(neg:Bool, d:String, dp:Int, prec:Int):String {
		final b = new StringBuf();
		if (neg)
			b.add("-");
		final nd = d.length;
		// first digit
		b.add(nd == 0 ? "0" : d.charAt(0));
		// .moredigits
		if (prec > 0) {
			b.add(".");
			var i = 1;
			final m = nd < prec + 1 ? nd : prec + 1;
			if (i < m) {
				b.add(d.substring(i, m));
				i = m;
			}
			while (i <= prec) {
				b.add("0");
				i++;
			}
		}
		// e±
		b.add("e");
		var exp = dp - 1;
		if (nd == 0) // special case: 0 has exponent 0
			exp = 0;
		if (exp < 0) {
			b.add("-");
			exp = -exp;
		} else {
			b.add("+");
		}
		// dd or ddd
		if (exp < 10)
			b.add("0" + exp);
		else
			b.add(Std.string(exp));
		return b.toString();
	}

	// %f: -ddddddd.ddddd
	static function fmtF(neg:Bool, d:String, dp:Int, prec:Int):String {
		final b = new StringBuf();
		if (neg)
			b.add("-");
		final nd = d.length;
		// integer, padded with zeros as needed.
		if (dp > 0) {
			var m = nd < dp ? nd : dp;
			b.add(d.substring(0, m));
			while (m < dp) {
				b.add("0");
				m++;
			}
		} else {
			b.add("0");
		}
		// fraction
		if (prec > 0) {
			b.add(".");
			for (i in 1...prec + 1) {
				final j = dp + i - 1;
				b.add(0 <= j && j < nd ? d.charAt(j) : "0");
			}
		}
		return b.toString();
	}

	// strconv.ParseFloat.
	// PORT: bitSize 32, hexadecimal floats and '_' separators are not implemented (they throw).
	// The decimal syntax is checked here; the correctly rounded conversion is done by the
	// platform (JS Number parsing / C strtod), which gives the same result as Go.
	public static function ParseFloat(s:String, bitSize:Int):ValueError<Float> {
		final fnParseFloat = "ParseFloat";
		if (bitSize != 64)
			throw "Strconv.ParseFloat: bitSize " + bitSize + " not implemented";
		final n = s.length;
		var i = 0;
		inline function c(k:Int):Int
			return k < n ? StringTools.fastCodeAt(s, k) : -1;
		var neg = false;
		if (c(0) == '+'.code || c(0) == '-'.code) {
			neg = c(0) == '-'.code;
			i++;
		}
		// special(): infinity, inf, nan (case-insensitive)
		final rest = s.substring(i).toLowerCase();
		if (rest == "infinity" || rest == "inf")
			return new ValueError<Float>(neg ? std.Math.NEGATIVE_INFINITY : std.Math.POSITIVE_INFINITY, null);
		if (rest == "nan" && i == 0)
			return new ValueError<Float>(std.Math.NaN, null);
		if (s.indexOf("_") >= 0 || (c(i) == '0'.code && (c(i + 1) == 'x'.code || c(i + 1) == 'X'.code)))
			throw "Strconv.ParseFloat: hex floats and underscores not implemented";
		var sawdigits = false;
		var sawdot = false;
		while (i < n) {
			final ch = c(i);
			if (ch == '.'.code) {
				if (sawdot)
					break;
				sawdot = true;
			} else if ('0'.code <= ch && ch <= '9'.code) {
				sawdigits = true;
			} else {
				break;
			}
			i++;
		}
		if (!sawdigits)
			return new ValueError<Float>(0, syntaxError(fnParseFloat, s));
		if (c(i) == 'e'.code || c(i) == 'E'.code) {
			i++;
			if (c(i) == '+'.code || c(i) == '-'.code)
				i++;
			if (!(c(i) >= '0'.code && c(i) <= '9'.code))
				return new ValueError<Float>(0, syntaxError(fnParseFloat, s));
			while (c(i) >= '0'.code && c(i) <= '9'.code)
				i++;
		}
		if (i != n)
			return new ValueError<Float>(0, syntaxError(fnParseFloat, s));
		final f = StrconvFloat.parse(s);
		if (f == std.Math.POSITIVE_INFINITY || f == std.Math.NEGATIVE_INFINITY)
			return new ValueError<Float>(f, rangeError(fnParseFloat, s));
		return new ValueError<Float>(f, null);
	}

	// strconv.Quote.
	// PORT: Go's unicode.IsPrint needs the Unicode tables. Here every non-ASCII code point is
	// printable except C1 controls, non-ASCII spaces (Zs/Zl/Zp), common format characters (Cf),
	// private use, and noncharacters U+FFFE/U+FFFF. A lone surrogate (Go: invalid UTF-8 byte)
	// is written as �.
	public static function Quote(s:String):String {
		final b = new StringBuf();
		b.addChar('"'.code);
		var i = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			var r = c;
			var width = 1;
			if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
				final d = StringTools.fastCodeAt(s, i + 1);
				if (d >= 0xDC00 && d <= 0xDFFF) {
					r = ((c - 0xD800) << 10) + (d - 0xDC00) + 0x10000;
					width = 2;
				}
			}
			i += width;
			if (r >= 0xD800 && r <= 0xDFFF) {
				b.add("\\ufffd");
				continue;
			}
			if (r == '"'.code || r == '\\'.code) {
				b.addChar('\\'.code);
				b.addChar(r);
				continue;
			}
			if (isPrint(r)) {
				b.add(width == 2 ? s.substr(i - 2, 2) : String.fromCharCode(r));
				continue;
			}
			switch (r) {
				case 7:
					b.add("\\a");
				case 8:
					b.add("\\b");
				case 12:
					b.add("\\f");
				case 10:
					b.add("\\n");
				case 13:
					b.add("\\r");
				case 9:
					b.add("\\t");
				case 11:
					b.add("\\v");
				default:
					if (r < ' '.code || r == 0x7f) {
						b.add("\\x");
						b.add(hex(r, 2));
					} else if (r < 0x10000) {
						b.add("\\u");
						b.add(hex(r, 4));
					} else {
						b.add("\\U");
						b.add(hex(r, 8));
					}
			}
		}
		b.addChar('"'.code);
		return b.toString();
	}

	static function hex(r:Int, digits:Int):String {
		return StringTools.hex(r, digits).toLowerCase();
	}

	static function isPrint(r:Int):Bool {
		if (r < 0x80)
			return r >= 0x20 && r < 0x7F;
		if (r < 0xA0 || r == 0xA0 || r == 0xAD)
			return false;
		if (r == 0x1680 || (r >= 0x2000 && r <= 0x200F) || (r >= 0x2028 && r <= 0x202F) || (r >= 0x205F && r <= 0x2064)
			|| r == 0x3000 || r == 0xFEFF || r == 0x061C || r == 0x180E)
			return false;
		if (r >= 0xE000 && r <= 0xF8FF)
			return false;
		if ((r & 0xFFFE) == 0xFFFE)
			return false;
		if (r >= 0xF0000)
			return false;
		return true;
	}
}

// Result of strconv.ParseUint: (uint64, error).
final class ParseUintResult {
	public final value:Int64;
	public final err:Null<Error>;

	public inline function new(value:Int64, err:Null<Error>) {
		this.value = value;
		this.err = err;
	}
}

// strconv.NumError
class NumError implements Error implements Errors.Wrapper {
	public var Func:String = "";
	public var Num:String = "";
	public var Err:Error = null;

	public function new(Func:String, Num:String, Err:Error) {
		this.Func = Func;
		this.Num = Num;
		this.Err = Err;
	}

	public function Error():String {
		return "strconv." + Func + ": " + "parsing " + Strconv.Quote(Num) + ": " + Err.Error();
	}

	public function Unwrap():Null<Error> {
		return Err;
	}

	public function toString():String {
		return Error();
	}
}

// Platform float <-> decimal primitives for FormatFloat / ParseFloat.
#if cpp
@:cppFileCode('#include <stdio.h>\n#include <stdlib.h>')
#end
private class StrconvFloat {
	// Shortest decimal digits that round-trip to x (x finite, > 0), in the form
	// "d.ddde±X" (like JS Number.prototype.toExponential() without argument).
	public static function shortest(x:Float):String {
		#if js
		return js.Syntax.code("({0}).toExponential()", x);
		#elseif cpp
		// Smallest p with a p-digit decimal that round-trips. The nearest p-digit decimal
		// (snprintf, correctly rounded) is tried first; when x is a power of two the rounding
		// interval is asymmetric, so the neighbouring p-digit decimal on the other side of x
		// is tried too.
		for (p in 1...18) {
			final s = fmtE(x, p - 1);
			final v = parse(s);
			if (v == x)
				return s;
			final ei = s.indexOf("e");
			final digits = s.charAt(0) + (p > 1 ? s.substring(2, ei) : "");
			var exp = Std.parseInt(StringTools.replace(s.substring(ei + 1), "+", ""));
			final n = neighbour(digits, v < x);
			if (n == null)
				continue;
			var nd = n;
			if (nd.length > p) {
				// carry: 99..9 + 1 = 100..0
				exp++;
				nd = nd.substring(0, p);
			}
			final cand = nd.charAt(0) + (p > 1 ? "." + nd.substring(1) : "") + "e" + (exp < 0 ? "-" : "+") + Std.string(exp < 0 ? -exp : exp);
			if (parse(cand) == x)
				return cand;
		}
		return fmtE(x, 16);
		#else
		// PORT: jvm/cs/python — Std.string(Float) is the shortest round-trip decimal (JVM: Double.toString
		// since JDK 19; Python repr; .NET Core "R"), only in another notation.
		#if python
		// PORT: python — a Float can hold a Python int (exact, printed with all digits): repr(float(x)).
		final e = toExponential(python.Syntax.code("repr(float({0}))", x));
		#else
		final e = toExponential(Std.string(x));
		#end
		// PORT: jvm — JDK 19+ Double.toString never gives fewer than 2 digits (4.9E-324, where JS
		// gives 5e-324): try the 1-digit decimals around a 2-digit result, the nearer one first.
		if (e.length > 3 && e.charAt(1) == "." && e.charAt(3) == "e") {
			final d0 = StringTools.fastCodeAt(e, 0) - "0".code, d1 = StringTools.fastCodeAt(e, 2) - "0".code;
			final rest = e.substring(3);
			final near = d1 >= 5 ? d0 + 1 : d0, far = d1 >= 5 ? d0 : d0 + 1;
			for (c in [near, far]) {
				if (c >= 1 && c <= 9 && parse(c + rest) == x)
					return c + rest;
			}
		}
		return e;
		#end
	}

	#if !(js || cpp)
	// "123.45", "1.0E21", "1e-07", … → "d.ddde±X" (JS toExponential() form), same digits.
	static function toExponential(s:String):String {
		final digits = new StringBuf();
		var exp = 0; // decimal exponent of the first collected digit
		var seenDot = false, started = false, i = 0, n = 0;
		while (i < s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c == ".".code) {
				seenDot = true;
			} else if (c >= "0".code && c <= "9".code) {
				if (c != "0".code || started) {
					if (!started)
						exp = seenDot ? -(n + 1) : 0;
					started = true;
					digits.addChar(c);
				} else if (seenDot) {
					n++; // leading zero after the dot
				}
				if (started && !seenDot && digits.length > 1)
					exp++;
			} else if (c == "e".code || c == "E".code) {
				exp += Std.parseInt(StringTools.replace(s.substring(i + 1), "+", ""));
				break;
			}
			i++;
		}
		var d = digits.toString();
		var end = d.length;
		while (end > 1 && StringTools.fastCodeAt(d, end - 1) == "0".code)
			end--;
		d = d.substring(0, end);
		return d.charAt(0) + (d.length > 1 ? "." + d.substring(1) : "") + "e" + (exp < 0 ? "-" : "+") + Std.string(exp < 0 ? -exp : exp);
	}
	#end

	#if cpp
	// digits + 1 (up) or digits - 1 (down) as a decimal string; null if down would lose a digit.
	static function neighbour(digits:String, up:Bool):Null<String> {
		final a = [for (i in 0...digits.length) StringTools.fastCodeAt(digits, i) - '0'.code];
		var i = a.length - 1;
		if (up) {
			while (i >= 0) {
				if (a[i] < 9) {
					a[i]++;
					break;
				}
				a[i] = 0;
				i--;
			}
			if (i < 0)
				a.unshift(1);
		} else {
			while (i >= 0) {
				if (a[i] > 0) {
					a[i]--;
					break;
				}
				a[i] = 9;
				i--;
			}
			if (a[0] == 0)
				return null;
		}
		final b = new StringBuf();
		for (d in a)
			b.add(d);
		return b.toString();
	}

	@:functionCode('char buf[64]; snprintf(buf, sizeof(buf), "%.*e", (int)prec, (double)x); return ::String::create(buf);')
	static function fmtE(x:Float, prec:Int):String {
		return null;
	}
	#end

	// Correctly rounded decimal → float64 for an already validated decimal string.
	public static function parse(s:String):Float {
		#if js
		return js.Syntax.code("Number({0})", s);
		#elseif cpp
		return untyped __cpp__("strtod({0}.utf8_str(), 0)", s);
		#elseif jvm
		return java.lang.Double.DoubleClass.parseDouble(s); // PORT: jvm — correctly rounded
		#else
		return Std.parseFloat(s);
		#end
	}
}
