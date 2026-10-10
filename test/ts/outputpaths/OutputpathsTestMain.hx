package ts.outputpaths;

class OutputpathsTestMain {
	static function main() {
		OutputpathsTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
