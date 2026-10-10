package ts.testrunner;

// Port of runner.go (interface Runner; runTests is in Testrunner.hx).
interface Runner {
	function EnumerateTestFiles():Array<String>;
	function RunTests(t:T):Void;
}
