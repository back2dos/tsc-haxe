package ts.stringutil;

import ts.stringutil.Stringutil.*;

// Port of js_case_test.go and util_test.go, plus extra spot checks (expected values
// taken from running the Go code at the pin).
class StringutilTest {
	public static function run() {
		// --- js_case_test.go ---

		T.run("TestJSCasing", () -> {
			final tests:Array<Array<String>> = [
				["ascii lowercase", ToLowerJS("HELLO"), "hello"],
				["ascii uppercase", ToUpperJS("hello"), "HELLO"],
				["lowercase dotted i", ToLowerJS("İSPANYOL"), "i̇spanyol"],
				["lowercase lone sigma", ToLowerJS("Σ"), "σ"],
				["lowercase final sigma", ToLowerJS("ΟΣ"), "ος"],
				["lowercase non-sigma greek", ToLowerJS("Ω"), "ω"],
				["uppercase sharp s", ToUpperJS("ßfoo"), "SSFOO"],
				["uppercase non-ascii simple mapping", ToUpperJS("ω"), "Ω"],
				["uppercase ligature", ToUpperJS("ﬁoo"), "FIOO"],
				["capitalize-style uppercase", ToUpperJS("ß") + "foo", "SSfoo"],
				["uncapitalize-style lowercase", ToLowerJS("İ") + "foo", "i̇foo"],
				["lowercase final sigma after lowercase letter without uppercase mapping", ToLowerJS("ʕΣ"), "ʕς"],
				["lowercase sigma after modifier letter", ToLowerJS("ʰΣ"), "ʰσ"],
				["lowercase sigma after case ignorable ypogegrammeni", ToLowerJS("ͅΣ"), "ͅσ"],
				["lowercase final sigma after feminine ordinal indicator", ToLowerJS("ªΣ"), "ªς"],
				["lowercase final sigma after masculine ordinal indicator", ToLowerJS("ºΣ"), "ºς"],
				["lowercase final sigma after roman numeral", ToLowerJS("ⅠΣ"), "ⅰς"],
				["lowercase sigma after uppercase property added after unicode 15", ToLowerJS("\u{1C89}Σ"), "\u{1C89}σ"],
				["lowercase sigma after uppercase property skewed from local v8 unicode data", ToLowerJS("\u{A7CB}Σ"), "\u{A7CB}σ"],
				["lowercase sigma before immediate latin letter", ToLowerJS("ΣA"), "σa"],
				["lowercase sigma before immediate roman numeral letter", ToLowerJS("ΣⅠ"), "σⅰ"],
				["lowercase sigma before case ignorable then latin letter", ToLowerJS("ΣͅA"), "σͅa"],
				["uppercase lone surrogate", ToUpperJS(EncodeJSStringRune(0xD800)), EncodeJSStringRune(0xD800)],
				[
					"lowercase lone surrogate",
					ToLowerJS("A" + EncodeJSStringRune(0xD800) + "B"),
					"a" + EncodeJSStringRune(0xD800) + "b"
				],
				[
					"uppercase lone low surrogate with text",
					ToUpperJS(EncodeJSStringRune(0xDC00) + "x"),
					EncodeJSStringRune(0xDC00) + "X"
				],
				[
					"lowercase lone surrogate before sigma",
					ToLowerJS(EncodeJSStringRune(0xD800) + "Σ"),
					EncodeJSStringRune(0xD800) + "σ"
				],
			];
			for (tt in tests)
				T.isTrue(tt[1] == tt[2], '${tt[0]}: got ${escape(tt[1])}, want ${escape(tt[2])}');
		});

		// --- util_test.go ---

		T.run("TestEncodeURI", () -> {
			final tests:Array<Array<String>> = [
				["encodes spaces as percent20", "a b", "a%20b"],
				["preserves reserved uri characters", ";/?:@&=+$,#", ";/?:@&=+$,#"],
				[
					"encodes brackets and unicode using utf8 bytes",
					"①Ⅻㄨㄩ U1[abc]",
					"%E2%91%A0%E2%85%AB%E3%84%A8%E3%84%A9%20U1%5Babc%5D"
				],
			];
			for (tt in tests)
				T.isTrue(EncodeURI(tt[1]) == tt[2], '${tt[0]}: EncodeURI(${escape(tt[1])}) = ${escape(EncodeURI(tt[1]))}, expected ${tt[2]}');
		});

		T.run("TestContainsNonASCII", () -> {
			T.eq(false, ContainsNonASCII("abc")); // ascii
			T.eq(true, ContainsNonASCII("é")); // non-ascii
			T.eq(true, ContainsNonASCII(EncodeJSStringRune(0xD800))); // lone surrogate sentinel
		});

		// --- extra (not upstream) ---

		T.run("TestIdentifierTablesSpotCheck", () -> {
			// [code point, start, part] from Go IsUnicodeIdentifierStart/Part at the pin.
			final cases:Array<Array<Int>> = [
				['a'.code, 1, 1], ['Z'.code, 1, 1], ['0'.code, 0, 1], ['9'.code, 0, 1], ['$'.code, 0, 0], ['_'.code, 0, 1],
				[' '.code, 0, 0], [0xAA, 1, 1], [0xB7, 0, 1], [0x300, 0, 1], [0x10400, 1, 1], [0x1F600, 0, 0], [0x2F800, 1, 1],
				[0xE0100, 0, 1], [-1, 0, 0], [0x110000, 0, 0], [0x200C, 0, 1], [0x200D, 0, 1], [0x2118, 1, 1], [0x309B, 1, 1],
				[0x1885, 1, 1],
			];
			for (c in cases) {
				T.isTrue(IsUnicodeIdentifierStart(c[0]) == (c[1] == 1), 'IsUnicodeIdentifierStart(0x${StringTools.hex(c[0])})');
				T.isTrue(IsUnicodeIdentifierPart(c[0]) == (c[2] == 1), 'IsUnicodeIdentifierPart(0x${StringTools.hex(c[0])})');
			}
		});

		// Checksums over every code point, against the same loop run in Go at the pin.
		T.run("TestTablesChecksum", () -> {
			var lo = 0, up = 0, sf = 0, ids = 0, idp = 0, cased = 0, ign = 0;
			for (r in 0...0x110000) {
				lo += (go.Unicode.ToLower(r) - r) * (r % 7 + 1);
				up += (go.Unicode.ToUpper(r) - r) * (r % 7 + 1);
				sf += (go.Unicode.SimpleFold(r) - r) * (r % 7 + 1);
				if (IsUnicodeIdentifierStart(r))
					ids++;
				if (IsUnicodeIdentifierPart(r))
					idp++;
				if (@:privateAccess Stringutil.isSigmaCased(r))
					cased++;
				if (@:privateAccess Stringutil.isUnicodeCaseIgnorable(r))
					ign++;
			}
			T.eq(10505083, lo);
			T.eq(-10720089, up);
			T.eq(37650, sf);
			T.eq(136967, ids);
			T.eq(140108, idp);
			T.eq(4526, cased);
			T.eq(2707, ign);
			var n = 0;
			for (_ in JsCaseGenerated.specialCasingMappings().keys())
				n++;
			T.eq(2927, n);
		});

		T.run("TestCompareSpotCheck", () -> {
			T.eq(-1, CompareStringsCaseSensitive("\u{FFFF}", "\u{10000}"));
			T.eq(-1, CompareStringsCaseSensitive("a\u{E000}", "a\u{10000}"));
			T.eq(1, CompareStringsCaseSensitive("ab", "a"));
			T.eq(-1, CompareStringsCaseSensitive("A", "a"));
			T.eq(true, EquateStringCaseInsensitive("K", "\u{212A}"));
			T.eq(false, EquateStringCaseInsensitive("ß", "SS"));
			T.eq(true, EquateStringCaseInsensitive("σ", "ς"));
			T.eq(true, EquateStringCaseInsensitive("Σ", "ς"));
			T.eq(true, EquateStringCaseInsensitive("ABC", "abc"));
			T.eq(false, EquateStringCaseInsensitive("abc", "abcd"));
			T.eq(true, EquateStringCaseInsensitive("𐐀", "𐐨"));
			T.eq(-1, CompareStringsCaseInsensitive("a", "B"));
			T.eq(0, CompareStringsCaseInsensitive("İ", "i"));
			T.eq(0, CompareStringsCaseInsensitive("ABC", "abc"));
			T.eq(-1, CompareStringsCaseInsensitive("abc", "abcd"));
			T.eq(-1, CompareStringsCaseInsensitive("_", "a"));
			T.eq(-1, CompareStringsCaseInsensitiveThenSensitive("ABC", "abc"));
			T.eq(-1, CompareStringsCaseInsensitiveEslintCompatible("__String", "Foo"));
			T.eq(-1, CompareStringsCaseInsensitive("__String", "Foo"));
			T.eq(true, HasPrefix("FooBar", "foo", false));
			T.eq(false, HasPrefix("FooBar", "foo", true));
			T.eq(true, HasSuffix("FooBar", "BAR", false));
			T.eq(false, HasPrefixAndSuffixWithoutOverlap("abc", "ab", "bc", true));
		});

		T.run("TestUtilSpotCheck", () -> {
			T.eq("ix", LowerFirstChar("İx"));
			T.eq("foo", LowerFirstChar("Foo"));
			T.eq("𐐨a", LowerFirstChar("𐐀a"));
			T.eq(2, GuessIndentation(["    a", "  b", ""]));
			T.eq(2, GuessIndentation(["\u{3000}\u{3000}x"])); // PORT: utf16 — Go: 6 (bytes)
			T.eq(0, GuessIndentation(["", ""]));
			T.eq("a|b|c|d", SplitLines("a\r\nb\rc\nd").join("|"));
			T.eq("x", SplitLines("x\n").join("|"));
			T.eq("hel", TruncateByRunes("hello", 3));
			T.eq("a𐐀", TruncateByRunes("a𐐀bc", 2));
			T.eq("", TruncateByRunes("abc", 0));
			T.eq("abc", StripQuotes("'abc'"));
			T.eq("\"abc'", StripQuotes("\"abc'"));
			T.eq("a'b\\c\\\nd", UnquoteString("'a\\'b\\\\c\\\nd'"));
			T.eq("𐐨ας", ToLowerJS("𐐀ΑΣ"));
			T.eq("𐐀STRASSE", ToUpperJS("𐐨straße"));
			T.eq("a%F0%90%90%80%C3%A9", EncodeURI("a𐐀é"));
			T.eq("x", RemoveByteOrderMark("\u{FEFF}x"));
			T.eq("\u{FEFF}x", AddUTF8ByteOrderMark("x"));
			T.eq("\u{FEFF}x", AddUTF8ByteOrderMark("\u{FEFF}x"));
			final p = CodePointToSurrogatePair(0x10400);
			T.eq(0xD801, p.r1);
			T.eq(0xDC00, p.r2);
			T.eq(0x10400, SurrogatePairToCodePoint(0xD801, 0xDC00));
			T.eq(0x10400, DecodeJSStringRune("a𐐀", 1));
			T.eq(0xD800, DecodeJSStringRune(EncodeJSStringRune(0xD800) + "x", 0));
			T.eq("\u{FFFD}", EncodeJSStringRune(0x110000));
			T.eq("a𐐀", CombineSurrogatePairs("a" + EncodeJSStringRune(0xD801) + EncodeJSStringRune(0xDC00)));
		});
	}

	static function escape(s:String):String {
		final b = new StringBuf();
		b.add('"');
		for (i in 0...s.length) {
			final c = StringTools.fastCodeAt(s, i);
			if (c < 0x20 || c > 0x7e)
				b.add("\\u" + StringTools.hex(c, 4));
			else
				b.addChar(c);
		}
		b.add('"');
		return b.toString();
	}
}
