package ts.tsoptions;

class TsoptionsTestMain {
	static function main() {
		TsoptionsTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
