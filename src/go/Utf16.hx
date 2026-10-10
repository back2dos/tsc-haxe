package go;

// Two runes: result of utf16.EncodeRune.
final class RunePair {
	public final r1:Int;
	public final r2:Int;

	public inline function new(r1:Int, r2:Int) {
		this.r1 = r1;
		this.r2 = r2;
	}
}

// Shims for Go package unicode/utf16, plus the UTF-16 string decoding helpers that replace
// Go's UTF-8 rune decoding (PORTING.md §5): Haxe strings are UTF-16 code units on every target.
class Utf16 {
	public static inline final RuneError = 0xFFFD; // utf8.RuneError
	public static inline final RuneSelf = 0x80; // utf8.RuneSelf
	public static inline final MaxRune = 0x10FFFF;

	static inline final surr1 = 0xd800;
	static inline final surr2 = 0xdc00;
	static inline final surr3 = 0xe000;
	static inline final surrSelf = 0x10000;

	// --- Go unicode/utf16 API ---

	// utf16.IsSurrogate
	public static inline function IsSurrogate(r:Int):Bool {
		return surr1 <= r && r < surr3;
	}

	// utf16.DecodeRune
	public static function DecodeRune(r1:Int, r2:Int):Int {
		if (surr1 <= r1 && r1 < surr2 && surr2 <= r2 && r2 < surr3)
			return (((r1 - surr1) << 10) | (r2 - surr2)) + surrSelf;
		return RuneError;
	}

	// utf16.EncodeRune
	public static function EncodeRune(r:Int):RunePair {
		if (r < surrSelf || r > MaxRune)
			return new RunePair(RuneError, RuneError);
		r -= surrSelf;
		return new RunePair(surr1 + ((r >> 10) & 0x3ff), surr2 + (r & 0x3ff));
	}

	// --- UTF-16 string helpers (not Go API) ---

	// Code point at UTF-16 index i. A valid surrogate pair is combined; a lone surrogate is
	// returned as is (like a JS string / Go DecodeJSStringRune). At or past the end: RuneError.
	public static inline function CodePointAt(s:String, i:Int):Int {
		var r = RuneError;
		if (i < s.length) {
			r = StringTools.fastCodeAt(s, i);
			if (r >= surr1 && r < surr2 && i + 1 < s.length) {
				final d = StringTools.fastCodeAt(s, i + 1);
				if (d >= surr2 && d < surr3)
					r = ((r - surr1) << 10) + (d - surr2) + surrSelf;
			}
		}
		return r;
	}

	// UTF-16 analogue of utf8.DecodeRuneInString(s[i:]) (rune only): like CodePointAt, but a
	// lone surrogate (the UTF-16 form of invalid input) decodes to RuneError.
	public static inline function DecodeRuneInString(s:String, i:Int):Int {
		final r = CodePointAt(s, i);
		return IsSurrogate(r) ? RuneError : r;
	}

	// UTF-16 length of rune r as returned by CodePointAt / DecodeRuneInString at a position
	// before the end of the string: 2 for supplementary code points, else 1.
	public static inline function RuneLen(r:Int):Int {
		return r >= surrSelf ? 2 : 1;
	}

	// UTF-16 analogue of utf8.DecodeLastRuneInString (rune only).
	public static function DecodeLastRuneInString(s:String):Int {
		final n = s.length;
		if (n == 0)
			return RuneError;
		final d = StringTools.fastCodeAt(s, n - 1);
		if (d >= surr2 && d < surr3 && n >= 2) {
			final c = StringTools.fastCodeAt(s, n - 2);
			if (c >= surr1 && c < surr2)
				return ((c - surr1) << 10) + (d - surr2) + surrSelf;
		}
		return IsSurrogate(d) ? RuneError : d;
	}

	// UTF-16 analogue of utf8.DecodeLastRuneInString(s[:end]) (rune only), without the slice.
	public static function DecodeLastRuneBefore(s:String, end:Int):Int {
		if (end <= 0)
			return RuneError;
		final d = StringTools.fastCodeAt(s, end - 1);
		if (d >= surr2 && d < surr3 && end >= 2) {
			final c = StringTools.fastCodeAt(s, end - 2);
			if (c >= surr1 && c < surr2)
				return ((c - surr1) << 10) + (d - surr2) + surrSelf;
		}
		return IsSurrogate(d) ? RuneError : d;
	}

	// Go `string(r)`: invalid code points (negative, surrogates, > MaxRune) become U+FFFD.
	public static function RuneString(r:Int):String {
		if (r < 0 || r > MaxRune || IsSurrogate(r))
			r = RuneError;
		return String.fromCharCode(r);
	}

	// Appends Go `string(r)` to b (strings.Builder.WriteRune).
	public static inline function WriteRune(b:StringBuf, r:Int):Void {
		if (r >= 0 && r < surr1)
			b.addChar(r);
		else
			b.add(RuneString(r));
	}

	// The single UTF-16 code unit c (0..0xFFFF) as a string, also for a lone surrogate.
	// hxcpp's String.fromCharCode / StringBuf.addChar replace lone surrogates with U+FFFD,
	// so on cpp the char16_t buffer is built directly.
	public static function CodeUnitString(c:Int):String {
		#if cpp
		return IsSurrogate(c) ? cppCodeUnit(c) : String.fromCharCode(c);
		#else
		return String.fromCharCode(c);
		#end
	}

	#if cpp
	@:functionCode('char16_t *p = ::String::allocChar16Ptr(1); p[0] = (char16_t)c; return ::String(p, 1);')
	static function cppCodeUnit(c:Int):String {
		return null;
	}
	#end
}
