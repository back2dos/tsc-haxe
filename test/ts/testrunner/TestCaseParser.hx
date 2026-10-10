package ts.testrunner;

// Port of test_case_parser.go: types (the package-level funcs are in Testrunner.hx).

// This maps a compiler setting to its value as written in the test file. For example, if a test file contains:
//
//	// @target: esnext, es2015
//
// Then the map will map "target" to "esnext, es2015"
typedef RawCompilerSettings = StringMap<String>;

// All the necessary information to turn a multi file test into useful units for later compilation
@:allow(ts.testrunner)
class TestUnit {
	var content:String = "";
	var name:String = "";

	public function new(content:String = "", name:String = "") {
		this.content = content;
		this.name = name;
	}
}

@:allow(ts.testrunner)
class TestCaseContent {
	var testUnitData:Array<TestUnit> = null;
	var tsConfig:ParsedCommandLine = null;
	var tsConfigFileUnitData:TestUnit = null;
	var symlinks:StringMap<String> = null;

	public function new() {}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():TestCaseContent {
		final r = new TestCaseContent();
		r.testUnitData = testUnitData;
		r.tsConfig = tsConfig;
		r.tsConfigFileUnitData = tsConfigFileUnitData;
		r.symlinks = symlinks;
		return r;
	}
}

class ParseTestFilesOptions {
	// If true, allows test content to appear before the first @Filename directive.
	// In this case, an implicit first file is created using the fileName parameter.
	// This matches the behavior of the TypeScript fourslash test harness.
	public var AllowImplicitFirstFile:Bool = false;

	public function new() {}
}

// PORT: the 5 results of ParseTestFilesAndSymlinks (units, symlinks, currentDir, globalOptions, e).
class ParseTestFilesResult<X> {
	public var units:Array<X>;
	public var symlinks:StringMap<String>;
	public var currentDir:String;
	public var globalOptions:StringMap<String>;
	public var e:Null<Error>;

	public function new(units, symlinks, currentDir, globalOptions, e) {
		this.units = units;
		this.symlinks = symlinks;
		this.currentDir = currentDir;
		this.globalOptions = globalOptions;
		this.e = e;
	}
}
