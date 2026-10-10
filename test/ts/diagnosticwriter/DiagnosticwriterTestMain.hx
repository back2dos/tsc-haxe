package ts.diagnosticwriter;

class DiagnosticwriterTestMain {
	static function main() {
		DiagnosticwriterTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
