package ts.bundled;

class BundledTestMain {
	static function main() {
		BundledTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
