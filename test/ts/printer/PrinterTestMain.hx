package ts.printer;

class PrinterTestMain {
	static function main() {
		PrinterTest.run();
		NamegeneratorTest.run();
		UtilitiesTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
