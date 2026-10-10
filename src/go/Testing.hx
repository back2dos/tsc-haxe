package go;

// Shim for Go package testing: the parts of *testing.T used by the ported test harness
// (internal/testutil/..., internal/testrunner).
// PORT: Go's t.Run starts a goroutine; here the subtest runs synchronously. t.Fatalf / t.Skip end the
// (sub)test with runtime.Goexit in Go; here they throw a TestExit that Run catches. A panic that
// escapes a subtest crashes the whole Go test binary; here Run records it (panicked) and continues,
// so a test runner can count it and go on.
class Testing {}

class T {
	final name:String;
	public final parent:Null<T>;
	public var failed:Bool = false;
	public var skipped:Bool = false;
	// Set when the test ended with a panic (caught by Run, or reported by testutil.RecoverAndFail).
	public var panicked:Bool = false;
	public final messages:Array<String> = [];
	public final children:Array<T> = [];

	public function new(name:String, ?parent:T) {
		this.name = name;
		this.parent = parent;
	}

	public function Name():String {
		return parent == null || parent.name == "" ? name : parent.Name() + "/" + name;
	}

	// The last path element of the name (the argument of t.Run).
	public function ShortName():String {
		return name;
	}

	// Run runs f as a subtest of t called name. It reports whether f succeeded.
	public function Run(name:String, f:(t:T) -> Void):Bool {
		final sub = new T(name, this);
		children.push(sub);
		try {
			f(sub);
		} catch (e:TestExit) {
			// Fatalf, FailNow or Skip
		} catch (e:Dynamic) {
			sub.panicked = true;
			sub.Fail();
			sub.messages.push("panic: " + Std.string(e));
		}
		if (sub.failed) {
			this.Fail();
		}
		return !sub.failed;
	}

	public function Helper():Void {}

	public function Parallel():Void {}

	public function Fail():Void {
		failed = true;
		if (parent != null)
			parent.Fail();
	}

	public function FailNow():Void {
		Fail();
		throw new TestExit();
	}

	public function Failed():Bool {
		return failed;
	}

	public function Skipped():Bool {
		return skipped;
	}

	public function Error(msg:String):Void {
		messages.push(msg);
		Fail();
	}

	public function Errorf(format:String, ...args:Any):Void {
		Error(Fmt.Sprintf(format, args.toArray()));
	}

	public function Fatal(msg:String):Void {
		messages.push(msg);
		FailNow();
	}

	public function Fatalf(format:String, ...args:Any):Void {
		Fatal(Fmt.Sprintf(format, args.toArray()));
	}

	public function Skip(msg:String):Void {
		messages.push(msg);
		skipped = true;
		throw new TestExit();
	}

	public function Skipf(format:String, ...args:Any):Void {
		Skip(Fmt.Sprintf(format, args.toArray()));
	}
}

// Thrown by T.FailNow / T.Skip to end the current (sub)test (Go: runtime.Goexit).
class TestExit {
	public function new() {}

	public function toString():String {
		return "TestExit";
	}
}
