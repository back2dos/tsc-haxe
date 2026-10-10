package ts.tspath;

class TspathTestMain {
	static function main() {
		TspathTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
