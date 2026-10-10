package ts.diagnostics;

import ts.diagnostics.Diagnostics;

class DiagnosticsTest {
	public static function run() {
		T.run("TestLocalize", testLocalize);
		T.run("GeneratedMatchesUpstream", testGeneratedMatchesUpstream);
	}

	// Port of diagnostics_test.go TestLocalize, English cases only.
	// PORT: the localized cases (de, fr, es, ja, zh, ...) wait for the localization port.
	static function testLocalize() {
		T.eq("Identifier expected.", Diagnostics.Identifier_expected.Localize("en", []));
		T.eq("Identifier expected.", Diagnostics.Identifier_expected.Localize("", []));
		T.eq("')' expected.", Diagnostics.X_0_expected.Localize("en", [")"]));
		T.eq("The parser expected to find a '}' to match the '{' token here.",
			Diagnostics.The_parser_expected_to_find_a_1_to_match_the_0_token_here.Localize("en", ["{", "}"]));
		T.eq("Identifier expected.", Diagnostics.Identifier_expected.Localize("af-ZA", []));
	}

	// Phase 0 gate: every message equals upstream diagnostics_generated.go.
	static function testGeneratedMatchesUpstream() {
		final src = sys.io.File.getContent(T.UPSTREAM + "/internal/diagnostics/diagnostics_generated.go");
		final re = ~/^var (\w+) = &Message\{code: (-?\d+), category: Category(\w+), key: "([^"]*)", text: "((?:[^"\\]|\\.)*)"(.*)\}$/;
		var n = 0;
		for (line in src.split("\n")) {
			if (!re.match(line))
				continue;
			n++;
			final name = re.matched(1);
			final m:Message = Reflect.field(Diagnostics, name);
			if (m == null) {
				T.fail("missing " + name);
				continue;
			}
			final rest = re.matched(6);
			T.eq(Std.parseInt(re.matched(2)), m.code);
			T.eq("Category" + re.matched(3), Std.string(categoryName(m.category)));
			T.eq(re.matched(4), m.key);
			T.eq(unquote(re.matched(5)), m.text);
			T.eq(rest.indexOf("reportsUnnecessary: true") >= 0, m.reportsUnnecessary);
			T.eq(rest.indexOf("elidedInCompatibilityPyramid: true") >= 0, m.elidedInCompatibilityPyramid);
			T.eq(rest.indexOf("reportsDeprecated: true") >= 0, m.reportsDeprecated);
		}
		T.eq(2154, n);
		T.eq(n, @:privateAccess Diagnostics.allMessages.length);
	}

	static function categoryName(c:Category):String {
		return switch c {
			case CategoryWarning: "CategoryWarning";
			case CategoryError: "CategoryError";
			case CategorySuggestion: "CategorySuggestion";
			case CategoryMessage: "CategoryMessage";
		}
	}

	// Go %q escapes used in the generated file.
	static function unquote(s:String):String {
		return ~/\\(u[0-9a-fA-F]{4}|.)/g.map(s, r -> {
			final e = r.matched(1);
			return switch e {
				case "n": "\n";
				case "t": "\t";
				case "\"": "\"";
				case "\\": "\\";
				case _ if (e.charAt(0) == "u"): String.fromCharCode(Std.parseInt("0x" + e.substr(1)));
				case _: throw "unknown escape " + e;
			}
		});
	}
}
