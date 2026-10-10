package ts.debug;

// Port of debug_test.go.
class DebugTest {
	public static function run() {
		T.run("TestFailEmptyReason", () -> panics(() -> Debug.Fail(""), "Debug failure."));
		T.run("TestFailWithReason", () -> panics(() -> Debug.Fail("something went wrong"), "Debug failure. something went wrong"));
		T.run("TestFailBadSyntaxKindNoMessage",
			() -> panics(() -> Debug.FailBadSyntaxKind(new MockNode("FooNode")), "Debug failure. Unexpected node.\nNode FooNode was unexpected."));
		T.run("TestFailBadSyntaxKindWithMessage",
			() -> panics(() -> Debug.FailBadSyntaxKind(new MockNode("BarNode"), "custom message"), "Debug failure. custom message\nNode BarNode was unexpected."));
		T.run("TestAssertNeverDefaultMessageKindString",
			() -> panics(() -> Debug.AssertNever(new MockNode("TestNode")), "Debug failure. Illegal value: TestNode"));
		T.run("TestAssertNeverCustomMessageKindString",
			() -> panics(() -> Debug.AssertNever(new MockNode("TestNode"), "bad value:"), "Debug failure. bad value: TestNode"));
		T.run("TestAssertNeverStringer", () -> panics(() -> Debug.AssertNever(new MockStringer("hello")), "Debug failure. Illegal value: hello"));
		T.run("TestAssertNeverFallback", () -> panics(() -> Debug.AssertNever(42), "Debug failure. Illegal value: 42"));
		T.run("TestAssertTrue", () -> Debug.Assert(true));
		T.run("TestAssertTrueWithMessage", () -> Debug.Assert(true, "this should not trigger"));
		T.run("TestAssertFalseNoMessage", () -> panics(() -> Debug.Assert(false), "Debug failure. False expression."));
		T.run("TestAssertFalseWithMessage", () -> panics(() -> Debug.Assert(false, "expected x > 0"), "Debug failure. False expression: expected x > 0"));
	}

	static function panics(f:() -> Void, expected:String, ?pos:haxe.PosInfos) {
		try {
			f();
		} catch (e:Dynamic) {
			T.eq(expected, Std.string(e), pos);
			return;
		}
		T.fail("did not panic", pos);
	}
}

private class MockNode {
	final kind:String;
	public function new(kind) this.kind = kind;
	public function KindString():String return kind;
}

private class MockStringer {
	final s:String;
	public function new(s) this.s = s;
	public function String():String return s;
}
