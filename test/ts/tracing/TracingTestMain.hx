package ts.tracing;

class TracingTestMain {
	static function main() {
		TracingTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
