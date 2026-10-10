package ts.module;

// Runs the tests of packages packagejson, module and symlinks.
class ModuleTestMain {
	static function pkg(name:String, run:() -> Void) {
		final c = T.checks;
		final f = T.failures;
		run();
		Sys.println('  $name: ${T.checks - c} checks, ${T.failures - f} failures');
	}

	static function main() {
		pkg("packagejson", ts.packagejson.PackagejsonTest.run);
		pkg("module", ts.module.ModuleTest.run);
		pkg("symlinks", ts.symlinks.SymlinksTest.run);
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
