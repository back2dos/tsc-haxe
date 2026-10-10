package ts.vfs.internal;

import haxe.io.Bytes;
import ts.vfs.internal.Internal;

// Not in Go (internal has no tests): checks of the byte decoding that the port re-implements
// (Go keeps raw bytes; see go.Utf8 and Internal.decodeBytes), the same on every target.
class InternalTest {
	static function bytes(a:Array<Int>):Bytes {
		final b = Bytes.alloc(a.length);
		for (i in 0...a.length)
			b.set(i, a[i]);
		return b;
	}

	static function units(s:String):String {
		return [for (i in 0...s.length) StringTools.hex(StringTools.fastCodeAt(s, i), 4)].join(" ");
	}

	public static function run() {
		T.run("decodeBytes (extra)", () -> {
			// UTF-8 with multi-byte runes and a 4-byte rune.
			T.eq("0061 00E9 4E2D D83C DF89", units(Internal.decodeBytes(bytes([0x61, 0xC3, 0xA9, 0xE4, 0xB8, 0xAD, 0xF0, 0x9F, 0x8E, 0x89])).value));
			// Invalid UTF-8: one U+FFFD per rejected byte (Go utf8.DecodeRune width 1).
			T.eq("0061 FFFD 0062", units(Internal.decodeBytes(bytes([0x61, 0xFF, 0x62])).value));
			T.eq("FFFD FFFD FFFD", units(Internal.decodeBytes(bytes([0xED, 0xA0, 0x80])).value));
			T.eq("FFFD FFFD 0061", units(Internal.decodeBytes(bytes([0xE4, 0xB8, 0x61])).value));
			// UTF-8 BOM is dropped.
			T.eq("0061", units(Internal.decodeBytes(bytes([0xEF, 0xBB, 0xBF, 0x61])).value));
			// UTF-16 LE / BE, surrogate pair, lone surrogate → U+FFFD, odd trailing byte ignored.
			T.eq("0061 D83C DF89", units(Internal.decodeBytes(bytes([0xFF, 0xFE, 0x61, 0x00, 0x3C, 0xD8, 0x89, 0xDF])).value));
			T.eq("0061 FFFD", units(Internal.decodeBytes(bytes([0xFE, 0xFF, 0x00, 0x61, 0xD8, 0x3C, 0x7A])).value));
			T.eq("FFFD 0062", units(Internal.decodeBytes(bytes([0xFF, 0xFE, 0x00, 0xDC, 0x62, 0x00])).value));
		});

		T.run("RootLength/SplitPath (extra)", () -> {
			T.eq(1, Internal.RootLength("/a/b"));
			T.eq(3, Internal.RootLength("c:/a"));
			final p = Internal.SplitPath("c:/foo/bar/");
			T.eq("c:/", p.a);
			T.eq("foo/bar", p.b);
		});
	}
}
