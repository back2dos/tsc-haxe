package ts.locale;

class LocaleTestMain {
	static function main() {
		ts.diagnostics.DiagnosticsTest.run();
		LocaleTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
