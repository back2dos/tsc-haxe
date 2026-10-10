package ts.glob;

class GlobTestMain {
	static function main() {
		GlobTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
