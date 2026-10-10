package ts.vfs;

// Helpers shared by the vfs package tests (gotest.tools assert equivalents).
class VfsTestUtil {
	// Go-like rendering of a []string: nil → "nil", else [a b c] (elements quoted).
	public static function strs(a:Null<Array<String>>):String {
		if (a == null)
			return "nil";
		return "[" + [for (s in a) go.Strconv.Quote(s)].join(" ") + "]";
	}

	// assert.DeepEqual for []string.
	public static function eqStrings(expected:Null<Array<String>>, actual:Null<Array<String>>, ?pos:haxe.PosInfos) {
		T.eq(strs(expected), strs(actual), pos);
	}

	// assert.NilError
	public static function nilError(err:Null<go.Errors.Error>, ?pos:haxe.PosInfos) {
		T.isTrue(err == null, err == null ? null : "unexpected error: " + err.Error(), pos);
	}

	// assert.Error(t, err, msg)
	public static function error(err:Null<go.Errors.Error>, msg:String, ?pos:haxe.PosInfos) {
		if (err == null) {
			T.fail("expected error <" + msg + ">, got nil", pos);
			return;
		}
		T.eq(msg, err.Error(), pos);
	}

	// assert.ErrorContains
	public static function errorContains(err:Null<go.Errors.Error>, substr:String, ?pos:haxe.PosInfos) {
		if (err == null) {
			T.fail("expected error containing <" + substr + ">, got nil", pos);
			return;
		}
		T.isTrue(err.Error().indexOf(substr) >= 0, "error <" + err.Error() + "> does not contain <" + substr + ">", pos);
	}

	// testutil.AssertPanics
	public static function assertPanics(fn:() -> Void, expected:String, ?pos:haxe.PosInfos) {
		var got:Dynamic = null;
		try {
			fn();
		} catch (e:Dynamic) {
			got = e;
		}
		T.isTrue(got != null, "did not panic", pos);
		if (got != null)
			T.eq(expected, Std.isOfType(got, go.Errors.Error) ? (got : go.Errors.Error).Error() : Std.string(got), pos);
	}

	// Go string(bytes) for test data.
	public static function bytesStr(b:haxe.io.Bytes):String {
		return b == null ? "nil" : go.Utf8.BytesToString(b, 0, b.length);
	}
}
