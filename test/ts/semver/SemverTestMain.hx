package ts.semver;

class SemverTestMain {
	static function main() {
		SemverTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
