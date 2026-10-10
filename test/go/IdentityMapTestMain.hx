package go;

class IdentityMapTestMain {
	static function main() {
		IdentityMapTest.run();
		StringsPrefixTest.run();
		Sys.println('${T.checks} checks, ${T.failures} failures');
		Sys.exit(T.failures == 0 ? 0 : 1);
	}
}
