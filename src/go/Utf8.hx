package go;

import haxe.io.Bytes;

// Conversions between Go byte strings (UTF-8) and Haxe UTF-16 strings, for the places where
// the port reads or writes bytes (file contents, embedded files).
// PORT: Go keeps invalid UTF-8 bytes in a string as they are; Haxe cannot. BytesToString maps
// every byte that utf8.DecodeRune rejects to U+FFFD, which is the rune Go's decoders produce
// for it later (one RuneError per invalid byte, utf8.DecodeRune width 1).
class Utf8 {
	// utf8 first-byte classification, as in Go unicode/utf8 (accept ranges for the 2nd byte).
	static inline function seqLen(b0:Int):Int {
		return b0 < 0x80 ? 1 : (b0 < 0xC2 ? 0 : (b0 < 0xE0 ? 2 : (b0 < 0xF0 ? 3 : (b0 < 0xF5 ? 4 : 0))));
	}

	static inline function lo(b0:Int):Int {
		return b0 == 0xE0 ? 0xA0 : (b0 == 0xF0 ? 0x90 : 0x80);
	}

	static inline function hi(b0:Int):Int {
		return b0 == 0xED ? 0x9F : (b0 == 0xF4 ? 0x8F : 0xBF);
	}

	// Length of the valid UTF-8 sequence at b[i] (i < end), or 0 if invalid (Go: RuneError, 1).
	static function validAt(b:Bytes, i:Int, end:Int):Int {
		final b0 = b.get(i);
		final n = seqLen(b0);
		if (n <= 1)
			return n;
		if (i + n > end)
			return 0;
		final b1 = b.get(i + 1);
		if (b1 < lo(b0) || b1 > hi(b0))
			return 0;
		for (k in 2...n) {
			final bk = b.get(i + k);
			if (bk < 0x80 || bk > 0xBF)
				return 0;
		}
		return n;
	}

	// Go `string(b[pos:pos+len])`, decoded to UTF-16 (see PORT note above).
	public static function BytesToString(b:Bytes, pos:Int, len:Int):String {
		final end = pos + len;
		var i = pos;
		var valid = true;
		while (i < end) {
			final c = b.get(i);
			if (c < 0x80) {
				i++;
				continue;
			}
			final n = validAt(b, i, end);
			if (n == 0) {
				valid = false;
				break;
			}
			i += n;
		}
		if (valid) {
			#if nodejs
			return js.node.Buffer.hxFromBytes(b).toString("utf8", pos, end);
			#else
			return b.getString(pos, len, UTF8);
			#end
		}
		final buf = new StringBuf();
		i = pos;
		while (i < end) {
			final c = b.get(i);
			if (c < 0x80) {
				buf.addChar(c);
				i++;
				continue;
			}
			final n = validAt(b, i, end);
			if (n == 0) {
				buf.addChar(0xFFFD);
				i++;
				continue;
			}
			var r = n == 2 ? c & 0x1F : (n == 3 ? c & 0x0F : c & 0x07);
			for (k in 1...n) {
				r = (r << 6) | (b.get(i + k) & 0x3F);
			}
			buf.addChar(r);
			i += n;
		}
		return buf.toString();
	}

	// Go `[]byte(s)`: UTF-8 bytes of s (a lone surrogate becomes U+FFFD, like Go's WTF-8 would
	// not; such strings do not occur in file contents).
	public static function StringToBytes(s:String):Bytes {
		return Bytes.ofString(s, UTF8);
	}

	// len(s) in Go: the UTF-8 byte length of s.
	public static function ByteLen(s:String):Int {
		var n = 0;
		var i = 0;
		final l = s.length;
		while (i < l) {
			final c = StringTools.fastCodeAt(s, i);
			if (c < 0x80)
				n += 1;
			else if (c < 0x800)
				n += 2;
			else if (c >= 0xD800 && c < 0xDC00 && i + 1 < l && StringTools.fastCodeAt(s, i + 1) >= 0xDC00
				&& StringTools.fastCodeAt(s, i + 1) < 0xE000) {
				n += 4;
				i++;
			} else
				n += 3;
			i++;
		}
		return n;
	}
}
