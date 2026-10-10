package ts.scanner;

class ScannerTestMain {
	static function main() {
		ScannerTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
