package ts.evaluator;

class EvaluatorTestMain {
	static function main() {
		EvaluatorTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
