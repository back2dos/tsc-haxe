package ts.testutil;

import go.Testing.T;
import go.Testing.TestExit;

// Port of internal/testutil/testutil.go (the parts used by the harness).
class Testutil {
	// PORT: Go `defer testutil.RecoverAndFail(t, msg)` → call from a catch block with the caught value.
	// A TestExit (t.Fatalf / t.Skip) is not a panic in Go (recover() returns nil): it is rethrown.
	// The caught value is a haxe.Exception (catch (e:haxe.Exception) keeps the stack of the throw).
	public static function RecoverAndFail(t:T, msg:String, e:haxe.Exception):Void {
		final r:Dynamic = Std.isOfType(e, haxe.ValueException) ? (cast e : haxe.ValueException).value : e;
		if (Std.isOfType(r, TestExit)) {
			throw e;
		}
		if (r != null) {
			t.panicked = true;
			final stack = haxe.CallStack.toString(e.stack);
			t.Fatalf("%s:\n%v\n%s", msg, Std.string(r), stack);
		}
	}

	// Leave Program in SingleThreaded mode unless explicitly configured or in race mode.
	// PORT: always true (the port is single-threaded; TS_TEST_PROGRAM_SINGLE_THREADED is not read).
	public static function TestProgramIsSingleThreaded():Bool {
		return true;
	}
}
