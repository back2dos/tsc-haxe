package ts.compiler;

// Runs the tests of package compiler and of the ported test harness (testrunner, testutil/baseline).
class CompilerTestMain {
	static function pkg(name:String, run:() -> Void) {
		final c = T.checks;
		final f = T.failures;
		run();
		Sys.println('  $name: ${T.checks - c} checks, ${T.failures - f} failures');
	}

	static function main() {
		pkg("compiler", ts.compiler.CompilerTest.run);
		pkg("testrunner", ts.testrunner.TestrunnerTest.run);
		pkg("testutil/baseline", ts.testutil.baseline.BaselineTest.run);
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
