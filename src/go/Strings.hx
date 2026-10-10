package go;

// Shims for Go package strings, on UTF-16 Haxe strings.
// Where Go decodes UTF-8 runes, these decode UTF-16; a lone surrogate plays the role of
// Go's invalid UTF-8 byte (utf8.RuneError).
class Strings {
	// Go `s[:n]` (0 <= n <= len(s)) without copying, for a long-lived text that is cut repeatedly.
	// PORT: perf — Go slices share the bytes; hxcpp's substring copies (the parser cuts the
	// source text before every JSDoc comment: measured 0.3 s and 330 MB on a 193k-line project).
	// On hxcpp the result shares s's buffer, which is not NUL-terminated at n and whose cached
	// hash belongs to s. Use it only as scanner/parser text: never as a map key, in a `switch`,
	// or with code that reads past its length (c_str, file or console output). hxcpp keeps a
	// string in UTF-16 form only if it has a character above 127 (String.eq relies on that), so
	// an all-ASCII prefix of a UTF-16 string is cut from a narrow copy (made once per text). JS: substring (V8 shares the characters).
	public static function Prefix(s:String, n:Int):String {
		#if cpp
		if (n >= s.length)
			return s;
		if (n <= 0)
			return "";
		if (untyped __cpp__("{0}.isUTF16Encoded()", s)) {
			if (!untyped __cpp__("({0}.raw_ptr() == {1}.raw_ptr() && {0}.length == {1}.length)", s, prefixText)) {
				var i = 0;
				while (i < s.length && StringTools.fastCodeAt(s, i) <= 127)
					i++;
				prefixText = s;
				prefixAscii = s.substring(0, i); // narrow copy of the all-ASCII start, made once
			}
			if (n <= prefixAscii.length)
				return n == prefixAscii.length ? prefixAscii : untyped __cpp__("::String({0}.raw_ptr(), {1})", prefixAscii, n);
			return untyped __cpp__("::String({0}.raw_wptr(), {1})", s, n);
		}
		return untyped __cpp__("::String({0}.raw_ptr(), {1})", s, n);
		#else
		return s.substring(0, n);
		#end
	}

	#if cpp
	// The last UTF-16 text cut by Prefix and a narrow copy of its start up to the first
	// character above 127.
	static var prefixText:String = "";
	static var prefixAscii:String = "";
	#end

	// strings.Compare: Go compares bytes, i.e. code-point order. UTF-16 code-unit order differs
	// for supplementary characters against U+E000..U+FFFF, so compare code points at the first
	// difference. Lone surrogates compare as their own value (Go WTF-8 bytes sort the same way).
	public static function Compare(a:String, b:String):Int {
		if (a == b)
			return 0;
		final n = a.length < b.length ? a.length : b.length;
		var i = 0;
		while (i < n && StringTools.fastCodeAt(a, i) == StringTools.fastCodeAt(b, i))
			i++;
		// Back up into a shared high surrogate so the pair is compared as one code point.
		if (i > 0) {
			final p = StringTools.fastCodeAt(a, i - 1);
			if (p >= 0xD800 && p < 0xDC00)
				i--;
		}
		if (i >= a.length)
			return i >= b.length ? 0 : -1;
		if (i >= b.length)
			return 1;
		// U+FFFE stands for Go's byte 0xFE (ast.InternalSymbolNamePrefix), which sorts above every
		// UTF-8 lead byte, so it sorts above every code point here.
		var ca = Utf16.CodePointAt(a, i);
		var cb = Utf16.CodePointAt(b, i);
		if (ca == 0xFFFE)
			ca = 0x110000;
		if (cb == 0xFFFE)
			cb = 0x110000;
		if (ca == cb) {
			// Same code point here (cannot happen after a backed-up high surrogate unless one side ends).
			return a.length < b.length ? -1 : (a.length > b.length ? 1 : 0);
		}
		return ca < cb ? -1 : 1;
	}

	// strings.EqualFold
	public static function EqualFold(s:String, t:String):Bool {
		// ASCII fast path
		var i = 0;
		final n = s.length < t.length ? s.length : t.length;
		var hasUnicode = false;
		while (i < n) {
			var sr = StringTools.fastCodeAt(s, i);
			var tr = StringTools.fastCodeAt(t, i);
			if ((sr | tr) >= Utf16.RuneSelf) {
				hasUnicode = true;
				break;
			}

			// Easy case.
			if (tr == sr) {
				i++;
				continue;
			}

			// Make sr < tr to simplify what follows.
			if (tr < sr) {
				final tmp = tr;
				tr = sr;
				sr = tmp;
			}
			// ASCII only, sr/tr must be upper/lower case
			if ('A'.code <= sr && sr <= 'Z'.code && tr == sr + 'a'.code - 'A'.code) {
				i++;
				continue;
			}
			return false;
		}
		if (!hasUnicode) {
			// Check if we've exhausted both strings.
			return s.length == t.length;
		}

		var si = i;
		var ti = i;
		while (si < s.length) {
			var sr = Utf16.DecodeRuneInString(s, si);
			si += Utf16.RuneLen(sr);
			// If t is exhausted the strings are not equal.
			if (ti >= t.length)
				return false;

			// Extract first rune from second string.
			var tr = Utf16.DecodeRuneInString(t, ti);
			ti += Utf16.RuneLen(tr);

			// Easy case.
			if (tr == sr)
				continue;

			// Make sr < tr to simplify what follows.
			if (tr < sr) {
				final tmp = tr;
				tr = sr;
				sr = tmp;
			}
			// Fast check for ASCII.
			if (tr < Utf16.RuneSelf) {
				// ASCII only, sr/tr must be upper/lower case
				if ('A'.code <= sr && sr <= 'Z'.code && tr == sr + 'a'.code - 'A'.code)
					continue;
				return false;
			}

			// General case. SimpleFold(x) returns the next equivalent rune > x
			// or wraps around to smaller values.
			var r = Unicode.SimpleFold(sr);
			while (r != sr && r < tr)
				r = Unicode.SimpleFold(r);
			if (r == tr)
				continue;
			return false;
		}

		// First string is empty, so check if the second one is also empty.
		return ti >= t.length;
	}

	// strings.ToLower
	public static function ToLower(s:String):String {
		var isASCII = true, hasUpper = false;
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c >= Utf16.RuneSelf) {
				isASCII = false;
				break;
			}
			hasUpper = hasUpper || ('A'.code <= c && c <= 'Z'.code);
		}

		if (isASCII) { // optimize for ASCII-only strings.
			if (!hasUpper)
				return s;
			final b = new StringBuf();
			for (i in 0...s.length) {
				var c = StringTools.fastCodeAt(s, i);
				if ('A'.code <= c && c <= 'Z'.code)
					c += 'a'.code - 'A'.code;
				b.addChar(c);
			}
			return b.toString();
		}
		return Map(Unicode.ToLower, s);
	}

	// strings.Map. A lone surrogate decodes to RuneError and is written as U+FFFD, like an
	// invalid UTF-8 byte in Go.
	public static function Map(mapping:Int->Int, s:String):String {
		var b:StringBuf = null;
		var i = 0;
		while (i < s.length) {
			final c = Utf16.DecodeRuneInString(s, i);
			final size = Utf16.RuneLen(c);
			final r = mapping(c);
			if (b == null) {
				if (r == c && (c != Utf16.RuneError || StringTools.fastCodeAt(s, i) == Utf16.RuneError)) {
					i += size;
					continue;
				}
				b = new StringBuf();
				b.add(s.substring(0, i));
			}
			if (r >= 0)
				Utf16.WriteRune(b, r);
			i += size;
		}
		if (b == null)
			return s;
		return b.toString();
	}

	// strings.TrimSpace: trims unicode.IsSpace runes from both ends.
	public static function TrimSpace(s:String):String {
		var start = 0;
		var end = s.length;
		while (start < end && isSpaceTrim(StringTools.fastCodeAt(s, start)))
			start++;
		while (end > start && isSpaceTrim(StringTools.fastCodeAt(s, end - 1)))
			end--;
		return s.substring(start, end);
	}

	// unicode.IsSpace (all such runes are in the BMP).
	static function isSpaceTrim(c:Int):Bool {
		if (c <= 0xFF)
			return c == 0x20 || (c >= 0x09 && c <= 0x0D) || c == 0x85 || c == 0xA0;
		return c == 0x1680 || (c >= 0x2000 && c <= 0x200A) || c == 0x2028 || c == 0x2029 || c == 0x202F || c == 0x205F || c == 0x3000;
	}

	// strings.IndexAny: UTF-16 index of the first code point of s that is in chars, or -1.
	// A lone surrogate matches only the same lone surrogate.
	public static function IndexAny(s:String, chars:String):Int {
		return IndexAnyFrom(s, chars, 0);
	}

	// strings.IndexAny(s[from:], chars) without the copy (hxcpp `substring` copies: a loop that cuts
	// the rest of a big text per match is quadratic). `from` must be on a code-point boundary.
	// Returns the index relative to `from`, or -1.
	public static function IndexAnyFrom(s:String, chars:String, from:Int):Int {
		if (chars.length == 0)
			return -1;
		final start = from < 0 ? 0 : from;
		var i = start;
		while (i < s.length) {
			final r = Utf16.CodePointAt(s, i);
			var j = 0;
			while (j < chars.length) {
				final c = Utf16.CodePointAt(chars, j);
				if (c == r)
					return i - start;
				j += Utf16.RuneLen(c);
			}
			i += Utf16.RuneLen(r);
		}
		return -1;
	}

	// s itself as a value; on hxcpp a process-wide deduplicated copy with its hash stored
	// (String.makePermanent: never collected), so map lookups with it skip hashing the characters.
	// PORT: perf helper for long-lived strings that are looked up very often (parser identifiers).
	public static function Intern(s:String):String {
		#if cpp
		return untyped __cpp__("{0}.makePermanent()", s);
		#else
		return s;
		#end
	}

	// The string of the first n bytes of b, each byte (0..127, NUL included) one character.
	// PORT: perf helper for checker.KeyHasher. haxe.io.Bytes.getString stops at a NUL byte on JS.
	public static function FromASCIIBytes(b:haxe.io.Bytes, n:Int):String {
		#if js
		final u = new js.lib.Uint8Array(b.getData(), 0, n);
		var s = "";
		var i = 0;
		while (i < n) { // apply() takes a bounded number of arguments
			final end = i + 8192 < n ? i + 8192 : n;
			s += js.Syntax.code("String.fromCharCode.apply(null, {0})", u.subarray(i, end));
			i = end;
		}
		return s;
		#else
		return b.getString(0, n);
		#end
	}

	// strings.ReplaceAll. Returns s itself (no allocation) when old does not occur.
	// An empty old matches at the start and after each code point, like Go after each rune.
	public static function ReplaceAll(s:String, old:String, new_:String):String {
		if (old.length == 0) {
			final b = new StringBuf();
			b.add(new_);
			var i = 0;
			while (i < s.length) {
				final n = Utf16.RuneLen(Utf16.CodePointAt(s, i));
				b.add(s.substring(i, i + n));
				b.add(new_);
				i += n;
			}
			return b.toString();
		}
		if (s.indexOf(old) < 0)
			return s;
		return StringTools.replace(s, old, new_);
	}

	// strings.Split. Same result on every target (Haxe's "".split(sep) is not).
	// An empty sep splits after each code point.
	public static function Split(s:String, sep:String):Array<String> {
		if (sep.length == 0) {
			final a = [];
			var i = 0;
			while (i < s.length) {
				final n = Utf16.RuneLen(Utf16.CodePointAt(s, i));
				a.push(s.substring(i, i + n));
				i += n;
			}
			return a;
		}
		if (s.length == 0)
			return [""];
		return s.split(sep);
	}

	// strings.Count: non-overlapping occurrences of substr; an empty substr counts code points + 1.
	public static function Count(s:String, substr:String):Int {
		if (substr.length == 0) {
			var n = 1;
			var i = 0;
			while (i < s.length) {
				i += Utf16.RuneLen(Utf16.CodePointAt(s, i));
				n++;
			}
			return n;
		}
		var n = 0;
		var i = s.indexOf(substr);
		while (i >= 0) {
			n++;
			i = s.indexOf(substr, i + substr.length);
		}
		return n;
	}

	// strings.TrimPrefix
	public static inline function TrimPrefix(s:String, prefix:String):String {
		return StringTools.startsWith(s, prefix) ? s.substring(prefix.length) : s;
	}

	// strings.TrimSuffix
	public static inline function TrimSuffix(s:String, suffix:String):String {
		return StringTools.endsWith(s, suffix) ? s.substring(0, s.length - suffix.length) : s;
	}

	// strings.TrimFunc: removes leading and trailing runes r with f(r). A lone surrogate is
	// passed to f as RuneError (Go: invalid UTF-8 byte).
	public static function TrimFunc(s:String, f:Int->Bool):String {
		var start = 0;
		while (start < s.length) {
			final r = Utf16.DecodeRuneInString(s, start);
			if (!f(r))
				break;
			start += Utf16.RuneLen(r);
		}
		var end = s.length;
		while (end > start) {
			final r = Utf16.DecodeLastRuneInString(s.substring(start, end));
			if (!f(r))
				break;
			end -= Utf16.RuneLen(r);
		}
		return s.substring(start, end);
	}

	// strings.TrimLeft: removes leading runes contained in cutset.
	public static function TrimLeft(s:String, cutset:String):String {
		return TrimLeftFunc(s, r -> IndexRune(cutset, r) >= 0);
	}

	// strings.TrimRight: removes trailing runes contained in cutset.
	public static function TrimRight(s:String, cutset:String):String {
		return TrimRightFunc(s, r -> IndexRune(cutset, r) >= 0);
	}

	// strings.TrimLeftFunc
	public static function TrimLeftFunc(s:String, f:Int->Bool):String {
		var start = 0;
		while (start < s.length) {
			final r = Utf16.DecodeRuneInString(s, start);
			if (!f(r))
				break;
			start += Utf16.RuneLen(r);
		}
		return s.substring(start);
	}

	// strings.TrimRightFunc
	public static function TrimRightFunc(s:String, f:Int->Bool):String {
		var end = s.length;
		while (end > 0) {
			final r = Utf16.DecodeLastRuneInString(s.substring(0, end));
			if (!f(r))
				break;
			end -= Utf16.RuneLen(r);
		}
		return s.substring(0, end);
	}

	// strings.IndexRune: UTF-16 index of the first occurrence of rune r in s, or -1.
	public static function IndexRune(s:String, r:Int):Int {
		var i = 0;
		while (i < s.length) {
			final c = Utf16.DecodeRuneInString(s, i);
			if (c == r)
				return i;
			i += Utf16.RuneLen(c);
		}
		return -1;
	}

	// strings.Repeat (count >= 0).
	public static function Repeat(s:String, count:Int):String {
		if (count < 0)
			throw "strings: negative Repeat count";
		final b = new StringBuf();
		for (_ in 0...count)
			b.add(s);
		return b.toString();
	}

	// strings.Replace: replaces the first n non-overlapping instances of old (all if n < 0).
	// PORT: an empty old (insertion at every rune boundary) is not supported.
	public static function Replace(s:String, old:String, new_:String, n:Int):String {
		if (old == "" )
			throw "strings.Replace with an empty old string is not ported";
		if (n == 0)
			return s;
		final b = new StringBuf();
		var start = 0;
		var done = 0;
		while (n < 0 || done < n) {
			final i = s.indexOf(old, start);
			if (i < 0)
				break;
			b.add(s.substring(start, i));
			b.add(new_);
			start = i + old.length;
			done++;
		}
		b.add(s.substring(start));
		return b.toString();
	}
}

// strings.Builder: a StringBuf plus its length in UTF-16 code units. Len() is O(1) (hxcpp's
// StringBuf.length sums all chunks). The zero value is an empty builder (`new Builder()`).
class Builder {
	var b:StringBuf = new StringBuf();
	var n:Int = 0;

	public function new() {}

	public inline function WriteString(s:String):Void {
		b.add(s);
		n += s.length;
	}

	// strings.Builder.WriteByte for an ASCII byte (one code unit).
	public inline function WriteByte(c:Int):Void {
		b.addChar(c);
		n++;
	}

	// strings.Builder.WriteRune (Go `string(r)` semantics, see Utf16.WriteRune).
	public function WriteRune(r:Int):Void {
		final s = Utf16.RuneString(r);
		b.add(s);
		n += s.length;
	}

	public inline function Len():Int {
		return n;
	}

	public function String():String {
		return b.toString();
	}

	public function Reset():Void {
		b = new StringBuf();
		n = 0;
	}

	// strings.Builder.Grow: capacity hint only.
	public inline function Grow(size:Int):Void {}
}

// PORT: Go `*strings.Builder` used as an io.Writer (`Write` appends). Haxe's Builder has no Write
// method, so this adapter wraps it; create one adapter per builder so identity comparisons of
// writers (`w == sys.Writer()`) behave like Go's pointer comparison.
class BuilderWriter implements go.Io.Writer {
	public final b:Builder;

	public function new(b:Builder) {
		this.b = b;
	}

	public function Write(p:String):go.Tuple.ValueError<Int> {
		this.b.WriteString(p);
		return new go.Tuple.ValueError<Int>(p.length, null);
	}
}
