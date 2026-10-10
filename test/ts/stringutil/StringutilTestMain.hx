package ts.stringutil;

class StringutilTestMain {
	static function main() {
		StringutilTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
