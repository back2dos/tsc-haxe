package ts.execute;

// Unit tests of lane C (execute, execute/tsc, the tsctests harness).
class ExecuteTestMain {
	static function main() {
		ExecuteTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
