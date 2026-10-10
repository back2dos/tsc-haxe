package ts.packagejson;

class PackagejsonTestMain {
	static function main() {
		PackagejsonTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
