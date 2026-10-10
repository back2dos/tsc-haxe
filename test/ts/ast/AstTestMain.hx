package ts.ast;

class AstTestMain {
	static function main() {
		AstTest.run();
		UtilitiesTest.run();
		UtilitiesGolden.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
