package ts.modulespecifiers;

class ModulespecifiersTestMain {
	static function main() {
		ModulespecifiersTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
