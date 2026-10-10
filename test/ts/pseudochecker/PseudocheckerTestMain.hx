package ts.pseudochecker;

class PseudocheckerTestMain {
	static function main() {
		PseudocheckerTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
