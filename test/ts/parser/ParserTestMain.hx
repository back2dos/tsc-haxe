package ts.parser;

class ParserTestMain {
	static function main() {
		ParserTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
