package ts.tsoptions;

// Runs the ported tests of package tsoptions (one module per Go *_test.go file).
// testmain_test.go (TestMain: debug stack limit, baseline tracking) has no test functions.
class TsoptionsTest {
	public static function run() {
		CommandlineparserTest.run();
		DeclsTest.run();
		ParsedcommandlineTest.run();
		ParsinghelpersTest.run();
		TsconfigparsingTest.run();
		WildcarddirectoriesTest.run();
		ShowconfigGoldenTest.run(); // PORT: extra (not upstream)
	}
}
