package go;

// go.Strings.Prefix: behaves like Go s[:n] (= substring(0, n)) for the operations the parser uses
// on it: length, character reads, substring, indexOf, equality; ASCII and UTF-16 text.
class StringsPrefixTest {
	public static function run() {
		T.run("TestStringsPrefix", () -> {
			for (s in ["/** a */ let x = 1; /** b */", "/** é\u{1F600} */ x /** c */"]) {
				final full = s + s; // a run-time (GC) string, not a literal
				for (n in [0, 1, 5, s.length, full.length - 2, full.length]) {
					final p = Strings.Prefix(full, n);
					final ref = full.substring(0, n);
					T.eq(ref.length, p.length);
					T.isTrue(p == ref, 'equal at $n');
					T.eq(ref.indexOf("*/"), p.indexOf("*/"));
					T.eq(ref.lastIndexOf("/**"), p.lastIndexOf("/**"));
					if (n > 3) {
						T.eq(ref.substring(2, n - 1), p.substring(2, n - 1));
						T.eq(StringTools.fastCodeAt(ref, n - 1), StringTools.fastCodeAt(p, n - 1));
						T.eq(Utf16.DecodeRuneInString(ref, n - 1), Utf16.DecodeRuneInString(p, n - 1));
					}
					T.eq(ref + "!", p + "!");
				}
			}
		});

		// go.Strings.IndexAnyFrom(s, chars, from) == strings.IndexAny(s[from:], chars)
		T.run("TestStringsIndexAnyFrom", () -> {
			final s = "x import é\u{1F600} require r";
			for (from in 0...s.length + 1) {
				if (from > 0 && StringTools.fastCodeAt(s, from - 1) >= 0xD800 && StringTools.fastCodeAt(s, from - 1) < 0xDC00)
					continue; // not a code-point boundary
				for (chars in ["ir", "\u{1F600}", "", "zq"])
					T.eq(Strings.IndexAny(s.substring(from), chars), Strings.IndexAnyFrom(s, chars, from));
			}
		});
		// go.Strings.FromASCIIBytes keeps NUL bytes and long inputs
		T.run("TestStringsFromASCIIBytes", () -> {
			for (n in [0, 1, 3, 9000, 20000]) {
				final b = haxe.io.Bytes.alloc(n + 5);
				final ref = new StringBuf();
				for (i in 0...n + 5) {
					b.set(i, (i * 7) & 0x7F);
					if (i < n)
						ref.addChar((i * 7) & 0x7F);
				}
				final s = Strings.FromASCIIBytes(b, n);
				T.eq(n, s.length);
				T.isTrue(s == ref.toString(), 'equal at $n');
			}
		});
	}
}
