package go;

import go.Errors.Error;
import go.Tuple.ValueError;
import haxe.io.Bytes;

// Shim for Go package encoding/base64 (only StdEncoding: standard alphabet, '=' padding).
class Base64 {
	public static final StdEncoding:Encoding = new Encoding();
}

class Encoding {
	static inline final encodeStd = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	public function new() {}

	// EncodeToString: standard alphabet with padding.
	public function EncodeToString(src:Bytes):String {
		return haxe.crypto.Base64.encode(src, true);
	}

	// DecodeString: like Go (non-strict): '\r' and '\n' are ignored; any other character outside
	// the alphabet, a missing or misplaced '=' or data after the padding is a CorruptInputError.
	// Non-zero trailing bits are accepted.
	public function DecodeString(s:String):ValueError<Bytes> {
		final out = new haxe.io.BytesBuffer();
		final dbuf = [0, 0, 0, 0];
		var si = 0;
		final n = s.length;
		inline function corrupt(at:Int):ValueError<Bytes> {
			return new ValueError<Bytes>(out.getBytes(), Errors.New("illegal base64 data at input byte " + at));
		}
		while (true) {
			var j = 0;
			var dlen = 4;
			var padded = false;
			while (j < 4) {
				// skip newlines
				while (si < n && (StringTools.fastCodeAt(s, si) == '\n'.code || StringTools.fastCodeAt(s, si) == '\r'.code))
					si++;
				if (si == n) {
					if (j == 0)
						return new ValueError<Bytes>(out.getBytes(), null);
					return corrupt(si - j);
				}
				final c = StringTools.fastCodeAt(s, si);
				si++;
				if (c == '='.code) {
					// We've reached the end and there's padding
					switch (j) {
						case 0, 1:
							// incorrect padding
							return corrupt(si - 1);
						case 2:
							// "==" is expected, the first "=" is already consumed.
							while (si < n && (StringTools.fastCodeAt(s, si) == '\n'.code || StringTools.fastCodeAt(s, si) == '\r'.code))
								si++;
							if (si == n)
								return corrupt(n);
							if (StringTools.fastCodeAt(s, si) != '='.code)
								return corrupt(si - 1);
							si++;
						default:
					}
					// skip over newlines
					while (si < n && (StringTools.fastCodeAt(s, si) == '\n'.code || StringTools.fastCodeAt(s, si) == '\r'.code))
						si++;
					if (si < n)
						// trailing garbage
						return corrupt(si);
					dlen = j;
					padded = true;
					break;
				}
				final v = encodeStd.indexOf(String.fromCharCode(c));
				if (v < 0 || c > 0x7F)
					return corrupt(si - 1);
				dbuf[j] = v;
				j++;
			}
			// Convert 4x 6bit source bytes into 3 bytes
			final val = (dbuf[0] << 18) | (dbuf[1] << 12) | (dbuf[2] << 6) | dbuf[3];
			dbuf[0] = 0;
			dbuf[1] = 0;
			dbuf[2] = 0;
			dbuf[3] = 0;
			if (dlen >= 2)
				out.addByte((val >> 16) & 0xFF);
			if (dlen >= 3)
				out.addByte((val >> 8) & 0xFF);
			if (dlen >= 4)
				out.addByte(val & 0xFF);
			if (padded)
				return new ValueError<Bytes>(out.getBytes(), null);
		}
	}
}
