package ts.sourcemap;

class SourcemapTestMain {
	static function main() {
		GeneratorTest.run();
		SourcemapGoldenTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
