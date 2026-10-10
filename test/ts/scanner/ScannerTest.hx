package ts.scanner;

import ts.ast.KindGenerated.Kind;
import ts.stringutil.Stringutil;

// Port of internal/scanner/scanner_test.go.
class ScannerTest {
	public static function run() {
		T.run("TestScanStringPreservesLoneSurrogates", TestScanStringPreservesLoneSurrogates);
	}

	static function TestScanStringPreservesLoneSurrogates() {
		final s = Scanner.NewScanner();
		s.SetText('"🦀\\ud7ff\\ud800\\ud801\\uD83E\\uDD80"');
		T.eq(s.Scan(), KindStringLiteral);
		T.eq(s.TokenValue(), "🦀"
			+ Stringutil.EncodeJSStringRune(0xD7FF)
			+ Stringutil.EncodeJSStringRune(0xD800)
			+ Stringutil.EncodeJSStringRune(0xD801)
			+ "🦀");
	}
}
