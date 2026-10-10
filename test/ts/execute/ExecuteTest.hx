package ts.execute;

import ts.execute.tsctests.Runner.Gate;

// Unit tests of lane C. Besides the ported Go unit tests, this runs the tsctests scenarios of
// TestTscCommandline, TestTscMissingFiles and TestShowConfig (help, version, init, showConfig,
// invalid command lines, config errors — little checker logic) and compares their baselines with
// the upstream references (tools/gate/tsc.sh runs all 191 tsc scenarios).
class ExecuteTest {
	// Known differences (see tools/gate/tsc.sh report):
	// - show-help...: the reference was generated with a 9-character version string (header padding
	//   is computed before the version is replaced by FakeTSVersion); core.Version() is "7.0.2" at the pin.
	// - locale / bad-locale: localized messages and BCP 47 validation are not ported (ts.locale).
	static final expectedFailures = [
		"tsc/commandLine/show-help-with-ExitStatus.DiagnosticsPresent_OutputsSkipped.js",
		"tsc/commandLine/locale.js",
		"tsc/commandLine/bad-locale.js",
	];

	public static function run() {
		ts.execute.tsc.ExtendedconfigcacheTest.run();
		T.run("TscScenarios/commandLine+showConfig", function() {
			var compared = 0;
			Gate.OnBaseline = function(path:String, actual:String) {
				compared++;
				final ref = T.UPSTREAM + "/testdata/baselines/reference/" + path;
				final expected = sys.FileSystem.exists(ref) ? sys.io.File.getContent(ref) : null;
				if (expected != actual && expectedFailures.indexOf(path) < 0)
					T.fail("baseline differs: " + path);
				else
					T.isTrue(true);
			};
			Gate.OnCrash = function(name:String, path:String, err:String, partial:String) {
				T.fail("crash: " + path + ": " + err.split("\n")[0]);
			};
			ts.execute.tsctests.TscTest.TestTscCommandline();
			ts.execute.tsctests.TscTest.TestTscMissingFiles();
			ts.execute.tsctests.ShowconfigTest.TestShowConfig();
			T.eq(31 + 17, compared);
			Gate.OnBaseline = function(path, actual) {};
			Gate.OnCrash = function(name, path, err, partial) {};
		});
	}
}
