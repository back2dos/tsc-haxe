package ts.execute.build;

class BuildTestMain {
	static function main() {
		BuildTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
