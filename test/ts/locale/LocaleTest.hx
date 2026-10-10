package ts.locale;

import go.text.language.Language;

// internal/locale has no upstream tests. These tests check the golang.org/x/text/language port
// (src/go/text/**) that locale.Parse and the diagnostics matcher use, against Go:
// locale.golden.txt is written by locale_golden.go.txt (see its header) with the pinned
// golang.org/x/text v0.38.0. Per input: language.Parse ok/tag (the partial tag on error, which
// locale.Parse returns too), tag == Und, and matcher.Match (index, confidence) of
// internal/diagnostics/loc_generated.go as getLocalizedMessages calls it.
class LocaleTest {
	public static function run() {
		T.run("LocaleParseMatchGolden", testGolden);
		T.run("LocaleParse", testParse);
		T.run("LocaleContext", testContext);
	}

	static function testGolden() {
		final lines = sys.io.File.getContent("test/ts/locale/locale.golden.txt").split("\n");
		var n = 0;
		for (line in lines) {
			if (line == "")
				continue;
			n++;
			final g:Dynamic = haxe.Json.parse(line);
			final input:String = Reflect.field(g, "in");
			final r = Language.Parse(input);
			final got = '${r.err == null} ${r.value.String()} ${r.value.equals(Language.Und)}';
			final want = '${g.ok} ${g.tag} ${g.und}';
			var gotMatch = "-1 -";
			if (!r.value.equals(Language.Und)) {
				final m = ts.diagnostics.LocGenerated.matcher.Match([r.value]);
				gotMatch = '${m.b} ${m.c.String()}';
			}
			final wantMatch = '${g.index} ${g.conf}';
			if (got != want || gotMatch != wantMatch)
				T.fail('${haxe.Json.stringify(input)}: want <$want | $wantMatch> got <$got | $gotMatch>');
			else
				T.checks++;
		}
		T.isTrue(n > 4000, "golden lines: " + n);
	}

	static function testParse() {
		// locale.Parse: ok as Go; the tag is kept even when parsing fails.
		final r = Locale.ParseOk("whoops");
		T.eq(false, r.ok);
		T.eq("und", r.value.String());
		final r2 = Locale.ParseOk("de-whoops");
		T.eq(false, r2.ok);
		T.eq("de", r2.value.String());
		final r3 = Locale.ParseOk("cs");
		T.eq(true, r3.ok);
		T.eq("cs", r3.value.String());
		T.isTrue(Locale.Parse("whoops") == null);
		T.eq("ja-JP", Locale.Parse("ja-jp").String());
		T.eq("und", Locale.Default.String());
	}

	static function testContext() {
		final ctx = go.Context.Background();
		T.eq("und", Locale.FromContext(ctx).String());
		T.eq("cs", Locale.FromContext(Locale.WithLocale(ctx, Locale.Parse("cs"))).String());
	}
}
