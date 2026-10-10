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
	}
}
