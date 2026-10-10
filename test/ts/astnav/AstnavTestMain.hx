package ts.astnav;

class AstnavTestMain {
	static function main() {
		AstnavTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
