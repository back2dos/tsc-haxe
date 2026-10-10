package ts.nodebuilder;

class NodebuilderTestMain {
	static function main() {
		NodebuilderTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
