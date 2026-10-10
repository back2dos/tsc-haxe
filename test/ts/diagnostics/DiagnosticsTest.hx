package ts.diagnostics;

import ts.diagnostics.Diagnostics;
import ts.locale.Locale;
import go.text.language.Language;

class DiagnosticsTest {
	public static function run() {
		T.run("TestLocalize", testLocalize);
		T.run("TestLocalize_ByKey", testLocalizeByKey);
		T.run("GeneratedMatchesUpstream", testGeneratedMatchesUpstream);
		T.run("LocalizedMessagesMatchUpstream", testLocalizedMessagesMatchUpstream);
	}

	static function loc(s:String):Locale {
		return (Language.MustParse(s) : Locale);
	}

	// Port of diagnostics_test.go TestLocalize.
	static function testLocalize() {
		final cases:Array<{name:String, message:Message, locale:Locale, args:Array<Any>, expected:String}> = [
			{name: "english default", message: Diagnostics.Identifier_expected, locale: Language.English, args: [], expected: "Identifier expected."},
			{name: "undefined locale uses english", message: Diagnostics.Identifier_expected, locale: Language.Und, args: [], expected: "Identifier expected."},
			{name: "with single argument", message: Diagnostics.X_0_expected, locale: Language.English, args: [")"], expected: "')' expected."},
			{
				name: "with multiple arguments",
				message: Diagnostics.The_parser_expected_to_find_a_1_to_match_the_0_token_here,
				locale: Language.English,
				args: ["{", "}"],
				expected: "The parser expected to find a '}' to match the '{' token here."
			},
			{name: "fallback to english for unknown locale", message: Diagnostics.Identifier_expected, locale: loc("af-ZA"), args: [], expected: "Identifier expected."},
			{name: "german", message: Diagnostics.Identifier_expected, locale: loc("de-DE"), args: [], expected: "Es wurde ein Bezeichner erwartet."},
			{name: "french", message: Diagnostics.Identifier_expected, locale: loc("fr-FR"), args: [], expected: "Identificateur attendu."},
			{name: "spanish", message: Diagnostics.Identifier_expected, locale: loc("es-ES"), args: [], expected: "Se esperaba un identificador."},
			{name: "japanese", message: Diagnostics.Identifier_expected, locale: loc("ja-JP"), args: [], expected: "識別子が必要です。"},
			{name: "chinese simplified", message: Diagnostics.Identifier_expected, locale: loc("zh-CN"), args: [], expected: "应为标识符。"},
			{name: "korean", message: Diagnostics.Identifier_expected, locale: loc("ko-KR"), args: [], expected: "식별자가 필요합니다."},
			{name: "russian", message: Diagnostics.Identifier_expected, locale: loc("ru-RU"), args: [], expected: "Ожидался идентификатор."},
			{name: "german with args", message: Diagnostics.X_0_expected, locale: loc("de-DE"), args: [")"], expected: "\")\" wurde erwartet."},
		];
		for (tt in cases)
			T.run("TestLocalize/" + tt.name, () -> T.eq(tt.expected, tt.message.Localize(tt.locale, tt.args)));
	}

	// Port of diagnostics_test.go TestLocalize_ByKey.
	static function testLocalizeByKey() {
		T.run("TestLocalize_ByKey/by key without args",
			() -> T.eq("Identifier expected.", Diagnostics.Localize(Language.English, null, "Identifier_expected_1003", [])));
		T.run("TestLocalize_ByKey/by key with args", () -> T.eq("')' expected.", Diagnostics.Localize(Language.English, null, "_0_expected_1005", [")"])));
	}

	// The embedded loc/*.json.gz (tools/gen/diagnostics/GenLoc.hx) give, per locale, exactly the
	// keys and texts of upstream internal/diagnostics/loc/*.json.gz, in the matcher's order.
	static function testLocalizedMessagesMatchUpstream() {
		final tags = ["zh-CN", "zh-TW", "cs-CZ", "de-DE", "es-ES", "fr-FR", "it-IT", "ja-JP", "ko-KR", "pl-PL", "pt-BR", "ru-RU", "tr-TR"];
		T.eq(tags.length + 1, LocGenerated.localeFuncs.length);
		T.isTrue(LocGenerated.localeFuncs[0] == null);
		for (i in 0...tags.length) {
			final got = LocGenerated.localeFuncs[i + 1]();
			final want = readUpstreamLoc(T.UPSTREAM + "/internal/diagnostics/loc/" + tags[i] + ".json.gz");
			var n = 0;
			var bad = 0;
			for (k => v in want) {
				n++;
				if (got.get(k) != v)
					bad++;
			}
			var m = 0;
			for (_ in got.keys())
				m++;
			T.eq(n, m);
			T.eq(0, bad);
			T.isTrue(n > 2000, tags[i] + " has " + n + " messages");
			// The locale resolves to its own table.
			final r = LocGenerated.matcher.Match([Language.MustParse(tags[i])]);
			T.eq(i + 1, r.b);
			T.eq("Exact", r.c.String());
		}
	}

	static function readUpstreamLoc(path:String):haxe.ds.StringMap<String> {
		final data = sys.io.File.getBytes(path);
		// gzip member: skip the header (Go writes no optional fields), inflate the raw deflate data.
		T.eq(0x1f, data.get(0));
		T.eq(0x8b, data.get(1));
		T.eq(0, data.get(3));
		final raw = LocGenerated.inflateRaw(new haxe.io.BytesInput(data, 10, data.length - 18));
		final obj:haxe.DynamicAccess<String> = haxe.Json.parse(raw.toString());
		final m = new haxe.ds.StringMap<String>();
		for (k => v in obj)
			m.set(k, v);
		return m;
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
