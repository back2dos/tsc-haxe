package ts.binder;

class BinderTestMain {
	static function main() {
		BinderTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
