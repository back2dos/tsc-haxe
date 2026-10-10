package ts.jsnum;

class JsnumTestMain {
	static function main() {
		JsnumTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
