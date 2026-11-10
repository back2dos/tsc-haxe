package ts.testrunner;

// Port of runner.go (interface Runner; runTests is in Testrunner.hx).
interface Runner {
	function EnumerateTestFiles():Slice<String>;
	function RunTests(t:T):Void;
}
