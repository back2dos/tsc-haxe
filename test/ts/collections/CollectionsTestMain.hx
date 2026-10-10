package ts.collections;

class CollectionsTestMain {
	static function main() {
		CollectionsTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
