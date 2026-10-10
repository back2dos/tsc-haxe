package go;

class SlicesSortTestMain {
	static function main() {
		SlicesSortTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
