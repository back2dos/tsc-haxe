package ts.execute.incremental;

class IncrementalTestMain {
	static function main() {
		IncrementalTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
