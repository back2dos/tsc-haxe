package ts.jsnum;

import haxe.Int64;

// Port of internal/jsnum.
// Package jsnum provides JS-like number handling.
@:allow(ts.jsnum)
class Jsnum {
	// --- jsnum.go ---

	public static inline final MaxSafeInteger:Number = 9007199254740991.0; // 1<<53 - 1
	public static inline final MinSafeInteger:Number = -9007199254740991.0; // -MaxSafeInteger

	public static function NaN():Number {
		return Math.NaN();
	}

	public static function Inf(sign:Int):Number {
		return Math.Inf(sign);
	}

	static function isNonFinite(x:Float):Bool {
		// This is equivalent to checking `math.IsNaN(x) || math.IsInf(x, 0)` in one operation.
		// PORT: 64-bit — const mask = 0x7FF0000000000000; only the high word has mask bits.
		final mask = 0x7FF00000;
		return Math.Float64bits(x).high & mask == mask;
	}

	static final negativeZero:Number = Math.Copysign(0, -1);

	// PORT: conversion — Go int32(x) for a float64 x. In range it truncates; out of range
	// (or NaN) Go on amd64 yields math.MinInt32 (CVTTSD2SL). Std.int is only defined in range.
	static function int32OfFloat(x:Float):Int {
		if (x > -2147483649.0 && x < 2147483648.0) {
			return Std.int(x);
		}
		return -2147483648;
	}

	// PORT: conversion — Go int32(int64(x)) for an integral x with |x| < 2**32: wraps mod 2**32.
	static function wrapInt32(x:Float):Int {
		if (x >= 2147483648.0) {
			x -= 4294967296.0;
		} else if (x < -2147483648.0) {
			x += 4294967296.0;
		}
		return Std.int(x);
	}

	// PORT: uint32 — a Go uint32 is kept as its bit pattern in an Int; this is float64(u).
	static inline function uint32ToFloat(u:Int):Float {
		return u < 0 ? u + 4294967296.0 : u;
	}

	// PORT: conversion — Go int64(x) for a float64 x: truncates; out of range (or NaN) Go on
	// amd64 yields math.MinInt64 (CVTTSD2SQ).
	static function int64OfFloat(x:Float):Int64 {
		x = Math.Trunc(x);
		if (!(x >= -9223372036854775808.0 && x < 9223372036854775808.0)) {
			return Int64.make(0x80000000, 0);
		}
		final hi = std.Math.ffloor(x / 4294967296.0);
		final lo = x - hi * 4294967296.0;
		return Int64.make(wrapInt32(hi), wrapInt32(lo));
	}

	// PORT: conversion — Go float64(i) for an int64 i (round to nearest).
	static function int64ToFloat(i:Int64):Float {
		return i.high * 4294967296.0 + uint32ToFloat(i.low);
	}

	// --- pseudobigint.go ---

	public static function NewPseudoBigInt(value:String, negative:Bool):PseudoBigInt {
		value = Strings.TrimLeft(value, "0");
		return new PseudoBigInt(negative && value.length != 0, value);
	}

	public static function ParseValidBigInt(text:String):PseudoBigInt {
		final negative = StringTools.startsWith(text, "-");
		if (negative) {
			text = text.substring(1);
		}
		return NewPseudoBigInt(ParsePseudoBigInt(text), negative);
	}

	public static function ParsePseudoBigInt(stringValue:String):String {
		stringValue = Strings.TrimSuffix(stringValue, "n");
		var b1 = 0;
		if (stringValue.length > 1) {
			b1 = StringTools.fastCodeAt(stringValue, 1);
		}
		switch (b1) {
			case 'b'.code, 'B'.code, 'o'.code, 'O'.code, 'x'.code, 'X'.code:
				// Not decimal.
			default:
				stringValue = Strings.TrimLeft(stringValue, "0");
				if (stringValue == "") {
					return "0";
				}
				return stringValue;
		}
		final r = new BigInt().SetString(stringValue, 0);
		if (!r.ok) {
			throw "Failed to parse big int: " + Strconv.Quote(stringValue);
		}
		return r.value.String(); // !!!
	}

	// --- string.go ---

	// https://tc39.es/ecma262/2024/multipage/abstract-operations.html#sec-stringtonumber
	public static function FromString(s:String):Number {
		// Implementing StringToNumber exactly as written in the spec involves
		// writing a parser, along with the conversion of the parsed AST into the
		// actual value.
		//
		// We've already implemented a number parser in the scanner, but we can't
		// import it here. We also do not have the conversion implemented since we
		// previously just wrote `+literal` and let the runtime handle it.
		//
		// The strategy below is to instead break the number apart and fix it up
		// such that Go's own parsing functionality can handle it. This won't be
		// the fastest method, but it saves us from writing the full parser and
		// conversion logic.

		s = Strings.TrimFunc(s, isStrWhiteSpace);

		switch (s) {
			case "":
				return 0;
			case "Infinity", "+Infinity":
				return Inf(1);
			case "-Infinity":
				return Inf(-1);
		}

		var i = 0;
		while (i < s.length) {
			final r = Utf16.DecodeRuneInString(s, i);
			if (!isNumberRune(r)) {
				return NaN();
			}
			i += Utf16.RuneLen(r);
		}

		final pr = tryParseInt(s);
		if (pr.ok) {
			return pr.value;
		}

		// Cut this off first so we can ensure -0 is returned as -0.
		final negative = StringTools.startsWith(s, "-");
		if (negative) {
			s = s.substring(1);
		}

		if (!negative) {
			if (StringTools.startsWith(s, "+")) {
				s = s.substring(1);
			}
		}

		final first = Utf16.DecodeRuneInString(s, 0);
		if (!Stringutil.IsDigit(first) && first != '.'.code) {
			return NaN();
		}

		final f = parseFloatString(s);
		if (Math.IsNaN(f)) {
			return NaN();
		}

		var sign = 1.0;
		if (negative) {
			sign = -1.0;
		}
		return Math.Copysign(f, sign);
	}

	static function isStrWhiteSpace(r:Int):Bool {
		// This is different than stringutil.IsWhiteSpaceLike.

		// https://tc39.es/ecma262/2024/multipage/ecmascript-language-lexical-grammar.html#prod-LineTerminator
		// https://tc39.es/ecma262/2024/multipage/ecmascript-language-lexical-grammar.html#prod-WhiteSpace

		switch (r) {
			// LineTerminator
			case '\n'.code, '\r'.code, 0x2028, 0x2029:
				return true;
			// WhiteSpace
			case '\t'.code, 0x0B, 0x0C, 0xFEFF:
				return true;
		}

		// WhiteSpace
		return Unicode.Is(Unicode.Zs, r);
	}

	static final errUnknownPrefix = Errors.New("unknown number prefix");

	static function tryParseInt(s:String):ValueOk<Number> {
		var i:Int64 = 0;
		var err:Null<Error> = null;
		var hasIntResult = false;

		if (s.length > 2) {
			final prefix = s.substring(0, 2);
			final rest = s.substring(2);
			switch (prefix) {
				case "0b", "0B":
					if (!isAllBinaryDigits(rest)) {
						return new ValueOk<Number>(NaN(), true);
					}
					final r = Strconv.ParseInt(rest, 2, 64);
					i = r.value;
					err = r.err;
					hasIntResult = true;
				case "0o", "0O":
					if (!isAllOctalDigits(rest)) {
						return new ValueOk<Number>(NaN(), true);
					}
					final r = Strconv.ParseInt(rest, 8, 64);
					i = r.value;
					err = r.err;
					hasIntResult = true;
				case "0x", "0X":
					if (!isAllHexDigits(rest)) {
						return new ValueOk<Number>(NaN(), true);
					}
					final r = Strconv.ParseInt(rest, 16, 64);
					i = r.value;
					err = r.err;
					hasIntResult = true;
			}
		}

		if (!hasIntResult) {
			// StringToNumber does not parse leading zeros as octal.
			s = trimLeadingZeros(s);
			if (!isAllDigits(s)) {
				return new ValueOk<Number>(0, false);
			}
			final r = Strconv.ParseInt(s, 10, 64);
			i = r.value;
			err = r.err;
			hasIntResult = true;
		}

		if (hasIntResult && err == null) {
			return new ValueOk<Number>(int64ToFloat(i), true);
		}

		// Using this to parse large integers.
		final bi = new BigInt().SetString(s, 0);
		if (!bi.ok) {
			return new ValueOk<Number>(NaN(), true);
		}

		final f = bi.value.Float64();
		return new ValueOk<Number>(f, true);
	}

	static function parseFloatString(s:String):Float {
		var hasDot = false;
		var hasExp = false;

		// <a>
		// <a>.<b>
		// <a>.<b>e<c>
		// <a>e<c>
		var a = "";
		var b = "";
		var c = "";
		var rest = "";

		final dot = s.indexOf(".");
		hasDot = dot >= 0;
		if (hasDot) {
			a = s.substring(0, dot);
			rest = s.substring(dot + 1);
		} else {
			a = s;
		}
		if (hasDot) {
			// <a>.<b>
			// <a>.<b>e<c>
			final r = cutAny(rest, "eE");
			b = r.a;
			c = r.b;
			hasExp = r.c;
		} else {
			// <a>
			// <a>e<c>
			final r = cutAny(s, "eE");
			a = r.a;
			c = r.b;
			hasExp = r.c;
		}

		final sb = new StringBuf();

		if (a == "") {
			if (hasDot && b == "") {
				return Math.NaN();
			}
			if (hasExp && c == "") {
				return Math.NaN();
			}
			sb.add("0");
		} else {
			a = trimLeadingZeros(a);
			if (!isAllDigits(a)) {
				return Math.NaN();
			}
			sb.add(a);
		}

		if (hasDot) {
			sb.add(".");
			if (b == "") {
				sb.add("0");
			} else {
				b = trimTrailingZeros(b);
				if (!isAllDigits(b)) {
					return Math.NaN();
				}
				sb.add(b);
			}
		}

		if (hasExp) {
			sb.add("e");

			final negative = StringTools.startsWith(c, "-");
			if (negative) {
				c = c.substring(1);
				sb.add("-");
			} else {
				if (StringTools.startsWith(c, "+")) {
					c = c.substring(1);
				}
			}
			c = trimLeadingZeros(c);
			if (!isAllDigits(c)) {
				return Math.NaN();
			}
			sb.add(c);
		}

		return stringToFloat64(sb.toString());
	}

	static function cutAny(s:String, cutset:String):Triple<String, String, Bool> {
		final i = Strings.IndexAny(s, cutset);
		if (i >= 0) {
			final before = s.substring(0, i);
			final afterAndFound = s.substring(i);
			final size = Utf16.RuneLen(Utf16.DecodeRuneInString(afterAndFound, 0));
			final after = afterAndFound.substring(size);
			return new Triple(before, after, true);
		}
		return new Triple(s, "", false);
	}

	static function trimLeadingZeros(s:String):String {
		if (StringTools.startsWith(s, "0")) {
			s = Strings.TrimLeft(s, "0");
			if (s == "") {
				return "0";
			}
		}
		return s;
	}

	static function trimTrailingZeros(s:String):String {
		if (StringTools.endsWith(s, "0")) {
			s = Strings.TrimRight(s, "0");
			if (s == "") {
				return "0";
			}
		}
		return s;
	}

	static function stringToFloat64(s:String):Float {
		final r = Strconv.ParseFloat(s, 64);
		if (r.err == null) {
			return r.value;
		} else {
			if (Errors.Is(r.err, Strconv.ErrRange)) {
				return r.value;
			}
		}
		return Math.NaN();
	}

	static function isAllDigits(s:String):Bool {
		var i = 0;
		while (i < s.length) {
			final r = Utf16.DecodeRuneInString(s, i);
			if (!Stringutil.IsDigit(r)) {
				return false;
			}
			i += Utf16.RuneLen(r);
		}
		return true;
	}

	static function isAllBinaryDigits(s:String):Bool {
		var i = 0;
		while (i < s.length) {
			final r = Utf16.DecodeRuneInString(s, i);
			if (r != '0'.code && r != '1'.code) {
				return false;
			}
			i += Utf16.RuneLen(r);
		}
		return true;
	}

	static function isAllOctalDigits(s:String):Bool {
		var i = 0;
		while (i < s.length) {
			final r = Utf16.DecodeRuneInString(s, i);
			if (!Stringutil.IsOctalDigit(r)) {
				return false;
			}
			i += Utf16.RuneLen(r);
		}
		return true;
	}

	static function isAllHexDigits(s:String):Bool {
		var i = 0;
		while (i < s.length) {
			final r = Utf16.DecodeRuneInString(s, i);
			if (!Stringutil.IsHexDigit(r)) {
				return false;
			}
			i += Utf16.RuneLen(r);
		}
		return true;
	}

	static function isNumberRune(r:Int):Bool {
		if (Stringutil.IsDigit(r)) {
			return true;
		}

		if ('a'.code <= r && r <= 'f'.code) {
			return true;
		}

		if ('A'.code <= r && r <= 'F'.code) {
			return true;
		}

		switch (r) {
			case '.'.code, '-'.code, '+'.code, 'x'.code, 'X'.code, 'o'.code, 'O'.code:
				return true;
		}

		return false;
	}

	// PORT: json.Marshal(float64) of the Go json package (go-json-experiment jsonwire.AppendFloat,
	// bits 64), used by Number.String(). The Haxe Json shim formats floats per target.
	static function marshalFloat64(src:Float):String {
		final abs = Math.Abs(src);
		var fmt = 'f'.code;
		if (abs != 0) {
			if (abs < 1e-6 || abs >= 1e21) {
				fmt = 'e'.code;
			}
		}
		var dst = Strconv.FormatFloat(src, fmt, -1, 64);
		if (fmt == 'e'.code) {
			// Clean up e-09 to e-9.
			final n = dst.length;
			if (n >= 4 && dst.charAt(n - 4) == "e" && dst.charAt(n - 3) == "-" && dst.charAt(n - 2) == "0") {
				dst = dst.substring(0, n - 2) + dst.charAt(n - 1);
			}
		}
		return dst;
	}
}

// Number represents a JS-like number.
//
// All operations that can be performed directly on this type
// (e.g., conversion, arithmetic, etc.) behave as they would in JavaScript,
// but any other operation should use this type's methods,
// not the "math" package and conversions.
// PORT: Go `type Number float64` → zero-cost abstract; the operators Go allows on Number are
// forwarded to Float. Unexported methods are visible to package ts.jsnum via @:allow.
// Number.String() (string.go) is in String_.hx (`using ts.jsnum.String_`).
@:allow(ts.jsnum)
abstract Number(Float) from Float to Float {
	@:op(A + B) static function add(a:Number, b:Number):Number;
	@:op(A - B) static function sub(a:Number, b:Number):Number;
	@:op(A * B) static function mul(a:Number, b:Number):Number;
	@:op(A / B) static inline function div(a:Number, b:Number):Number {
		return go.Math.Div(a, b); // PORT: python — x / 0 (inline `a / b` on the other targets)
	}
	@:op(-A) static function neg(a:Number):Number;
	@:op(A == B) static function eq(a:Number, b:Number):Bool;
	@:op(A != B) static function ne(a:Number, b:Number):Bool;
	@:op(A < B) static function lt(a:Number, b:Number):Bool;
	@:op(A <= B) static function le(a:Number, b:Number):Bool;
	@:op(A > B) static function gt(a:Number, b:Number):Bool;
	@:op(A >= B) static function ge(a:Number, b:Number):Bool;

	public function IsNaN():Bool {
		return Math.IsNaN(this);
	}

	public function IsInf():Bool {
		return Math.IsInf(this, 0);
	}

	// https://tc39.es/ecma262/2024/multipage/abstract-operations.html#sec-touint32
	// PORT: uint32 — returns the uint32 bit pattern in an Int.
	function toUint32():Int {
		// The only difference between ToUint32 and ToInt32 is the interpretation of the bits.
		return toInt32();
	}

	// https://tc39.es/ecma262/2024/multipage/abstract-operations.html#sec-toint32
	function toInt32():Int {
		var x:Float = this;

		// Fast path: if the number is in the range (-2^31, 2^32), i.e. an SMI,
		// then we don't need to do any special mapping.
		final smi = Jsnum.int32OfFloat(x);
		if (smi == x) {
			return smi;
		}

		// 2. If number is not finite or number is either +0𝔽 or -0𝔽, return +0𝔽.
		// Zero was covered by the test above.
		if (Jsnum.isNonFinite(x)) {
			return 0;
		}

		// Let int be truncate(ℝ(number)).
		x = Math.Trunc(x);
		// Let int32bit be int modulo 2**32.
		x = Math.Mod(x, 4294967296.0 /* 1<<32 */);
		// If int32bit ≥ 2**31, return 𝔽(int32bit - 2**32); otherwise return 𝔽(int32bit).
		return Jsnum.wrapInt32(x);
	}

	// PORT: uint32 — returns the uint32 bit pattern in an Int.
	function toShiftCount():Int {
		return toUint32() & 31;
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-signedRightShift
	public function SignedRightShift(y:Number):Number {
		return toInt32() >> y.toShiftCount();
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-unsignedRightShift
	public function UnsignedRightShift(y:Number):Number {
		return Jsnum.uint32ToFloat(toUint32() >>> y.toShiftCount());
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-leftShift
	public function LeftShift(y:Number):Number {
		return go.Math.Shl(toInt32(), y.toShiftCount()); // PORT: python — wraps (plain `<<` elsewhere)
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-bitwiseNOT
	public function BitwiseNOT():Number {
		return ~toInt32();
	}

	// The below are implemented by https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numberbitwiseop.

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-bitwiseOR
	public function BitwiseOR(y:Number):Number {
		return toInt32() | y.toInt32();
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-bitwiseAND
	public function BitwiseAND(y:Number):Number {
		return toInt32() & y.toInt32();
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-bitwiseXOR
	public function BitwiseXOR(y:Number):Number {
		return toInt32() ^ y.toInt32();
	}

	function trunc():Number {
		return Math.Trunc(this);
	}

	public function Floor():Number {
		return Math.Floor(this);
	}

	public function Abs():Number {
		return Math.Abs(this);
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-remainder
	public function Remainder(d:Number):Number {
		final n:Number = this;
		if (n.IsNaN() || d.IsNaN()) {
			return Jsnum.NaN();
		} else if (n.IsInf()) {
			return Jsnum.NaN();
		} else if (d.IsInf()) {
			return n;
		} else if (d == 0) {
			return Jsnum.NaN();
		} else if (n == 0) {
			return n;
		}
		return Math.Mod(n, d);
	}

	// https://tc39.es/ecma262/2024/multipage/ecmascript-data-types-and-values.html#sec-numeric-types-number-exponentiate
	public function Exponentiate(exponent:Number):Number {
		final base:Number = this;
		if ((base == 1 || base == -1) && exponent.IsInf()) {
			return Jsnum.NaN();
		} else if (base == 1 && exponent.IsNaN()) {
			return Jsnum.NaN();
		}

		final b:Float = base;
		final e:Float = exponent;

		// For integer base ** integer exponent where the result exceeds 53 bits,
		// math.Pow can be off by multiple ULPs vs JS engines. Use exact big.Int
		// arithmetic and IEEE 754 round-to-nearest-even conversion instead.
		// The ES spec (§6.1.6.1.3) says exponentiate returns an
		// "implementation-approximated" value, so engines are allowed to differ.
		// This won't exactly match every engine (V8's fdlibm-compiled pow can
		// round halfway ties differently), but will always be within 1 ULP
		// (unit in the last place, i.e. the least significant bit of the result).
		// PORT: math.MinInt64 / math.MaxInt64 / math.MaxFloat64 as float64 constants.
		if (b >= -9223372036854775808.0 && b <= 9223372036854775807.0 && b == Math.Trunc(b) && e >= 0 && e <= 9223372036854775807.0
			&& e == Math.Trunc(e) && !Math.IsInf(e, 0)) {
			final magnitude = e * Math.Log2(Math.Abs(b));
			if (magnitude > 53 && magnitude <= Math.Log2(Math.MaxFloat64)) {
				final ri = new BigInt().Exp(Big.NewInt(Jsnum.int64OfFloat(b)), Big.NewInt(Jsnum.int64OfFloat(e)), null);
				final result = new BigFloat().SetPrec(256).SetInt(ri).Float64();
				return result;
			}
		}

		return Math.Pow(b, e);
	}
}
