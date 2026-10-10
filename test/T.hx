// Minimal test harness: no dependencies, same behaviour on every target.
class T {
	public static var failures = 0;
	public static var checks = 0;
	static var current = "";

	public static function run(name:String, f:() -> Void) {
		current = name;
		try f() catch (e:Dynamic) fail("exception: " + Std.string(e));
	}

	public static function eq<A>(expected:A, actual:A, ?pos:haxe.PosInfos) {
		checks++;
		if (expected != actual)
			fail('expected <$expected> got <$actual>', pos);
	}

	public static function isTrue(v:Bool, ?msg:String, ?pos:haxe.PosInfos) {
		checks++;
		if (!v)
			fail(msg == null ? "expected true" : msg, pos);
	}

	public static function fail(msg:String, ?pos:haxe.PosInfos) {
		failures++;
		final at = pos == null ? "" : ' (${pos.fileName}:${pos.lineNumber})';
		Sys.println('FAIL $current: $msg$at');
	}

	// Path of the pinned upstream checkout (see Makefile `upstream`).
	public static inline final UPSTREAM = "upstream/tsc";
}
