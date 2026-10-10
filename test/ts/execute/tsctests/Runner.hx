package ts.execute.tsctests;

import go.Context;
import ts.execute.Execute;
import ts.execute.tsc.Compile;
import ts.execute.tsc.Compile.ExitStatus.*;

// Port of internal/execute/tsctests/runner.go (types). Functions: see bottom of this file.
// PORT: Go struct literals → @:structInit classes (fields with an initializer may be omitted,
// like Go zero values).
@:structInit
class TscEdit {
	public var caption:String = "";
	public var commandLineArgs:Null<Array<String>> = null;
	public var edit:Null<(sys:TestSys) -> Void> = null;
	public var expectedDiff:String = "";
}

// FileMap: Go `map[string]any` (string contents, or a vfstest MapFile such as Vfstest.Symlink).
typedef FileMap = Map<String, Any>;

@:structInit
class TscInput {
	public var subScenario:String = "";
	public var commandLineArgs:Null<Array<String>> = null;
	public var files:Null<FileMap> = null;
	public var cwd:String = "";
	public var edits:Null<Array<TscEdit>> = null;
	public var env:Null<Map<String, String>> = null;
	public var ignoreCase:Bool = false;
	public var windowsStyleRoot:String = "";

	function executeCommand(sys:TestSys, baselineBuilder:Builder, commandLineArgs:Null<Array<String>>):CommandLineResult {
		baselineBuilder.WriteString("tsgo " + (commandLineArgs == null ? "" : commandLineArgs.join(" ")) + "\n");
		final result = Execute.CommandLine(Context.Background(), sys, commandLineArgs, sys);
		switch (result.Status) {
			case ExitStatusSuccess:
				baselineBuilder.WriteString("ExitStatus:: Success");
			case ExitStatusDiagnosticsPresent_OutputsSkipped:
				baselineBuilder.WriteString("ExitStatus:: DiagnosticsPresent_OutputsSkipped");
			case ExitStatusDiagnosticsPresent_OutputsGenerated:
				baselineBuilder.WriteString("ExitStatus:: DiagnosticsPresent_OutputsGenerated");
			case ExitStatusInvalidProject_OutputsSkipped:
				baselineBuilder.WriteString("ExitStatus:: InvalidProject_OutputsSkipped");
			case ExitStatusProjectReferenceCycle_OutputsSkipped:
				baselineBuilder.WriteString("ExitStatus:: ProjectReferenceCycle_OutputsSkipped");
			case ExitStatusNotImplemented:
				baselineBuilder.WriteString("ExitStatus:: NotImplemented");
			default:
				throw "UnknownExitStatus " + (result.Status : Int);
		}
		return result;
	}

	// Go `(test *tscInput) run(t, scenario)`.
	// PORT: no testing.T. The subtest is reported to the gate hooks (Runner.Gate): `Gate.Filter` selects
	// subtests by their Go name, `Gate.OnBaseline` receives the baseline (Go baseline.Run), `Gate.OnCrash`
	// a thrown error, `Gate.OnError` the t.Errorf text. Watch and build subtests (tscWatch/tsbuild) are
	// skipped: watch mode and execute/build are not ported.
	public function run(scenario:String):Void {
		final subFolder = this.getBaselineSubFolder();
		final name = subFolder + "/" + scenario + "/" + this.subScenario;
		if (subFolder != "tsc") {
			Gate.OnSkipped(name);
			return;
		}
		if (Gate.Filter != null && !Gate.Filter(name))
			return;
		final baselineFile = Strings.ReplaceAll(this.subScenario, " ", "-") + ".js";
		final baselineSubfolder = subFolder + "/" + scenario;
		final baselineBuilder = new Builder();
		try {
			this.runWorker(baselineBuilder, baselineFile, baselineSubfolder);
		} catch (e:Dynamic) {
			Gate.OnCrash(name, baselineSubfolder + "/" + baselineFile, Std.string(e) + "\n" + haxe.CallStack.toString(haxe.CallStack.exceptionStack()),
				baselineBuilder.String());
		}
	}

	function runWorker(baselineBuilder:Builder, baselineFile:String, baselineSubfolder:String):Void {
		// initial test tsc compile
		final sys = Tsctests.newTestSys(this, false);
		baselineBuilder.WriteString("currentDirectory::" + sys.GetCurrentDirectory() + "\nuseCaseSensitiveFileNames::"
			+ (sys.FS().UseCaseSensitiveFileNames() ? "true" : "false") + "\nInput::\n");
		sys.baselineFSwithDiff(baselineBuilder);
		final result = this.executeCommand(sys, baselineBuilder, this.commandLineArgs);
		sys.serializeState(baselineBuilder);
		// PORT: watch state (result.Watcher / mockWatchBackend) is not ported.
		final unexpectedDiff = new Builder();
		unexpectedDiff.WriteString(sys.baselinePrograms(baselineBuilder, "Initial build"));

		if (this.edits != null) {
			for (index in 0...this.edits.length) {
				final do_ = this.edits[index];
				sys.clearOutput();
				var nonIncrementalSys:TestSys = null;
				final commandLineArgs = Core.IfElse(do_.commandLineArgs == null, this.commandLineArgs, do_.commandLineArgs);
				// PORT: core.WorkGroup with two queued closures → run in order (single-threaded).
				{
					baselineBuilder.WriteString("\n\nEdit [" + index + "]:: " + do_.caption + "\n");
					if (do_.edit != null) {
						do_.edit(sys);
					}
					sys.baselineFSwithDiff(baselineBuilder);

					this.executeCommand(sys, baselineBuilder, commandLineArgs);
					sys.serializeState(baselineBuilder);
					unexpectedDiff.WriteString(sys.baselinePrograms(baselineBuilder, "Edit [" + index + "]:: " + do_.caption + "\n"));
				}
				{
					// Compute build with all the edits
					nonIncrementalSys = Tsctests.newTestSys(this, true);
					for (i in 0...index + 1) {
						if (this.edits[i].edit != null) {
							this.edits[i].edit(nonIncrementalSys);
						}
					}
					Execute.CommandLine(Context.Background(), nonIncrementalSys, commandLineArgs, nonIncrementalSys);
				}

				final diff = Tsctests.getDiffForIncremental(sys, nonIncrementalSys);
				if (diff != "") {
					baselineBuilder.WriteString("\n\nDiff:: "
						+ Core.IfElse(do_.expectedDiff == "", "!!! Unexpected diff, please review and either fix or write explanation as expectedDiff !!!",
							do_.expectedDiff)
						+ "\n");
					baselineBuilder.WriteString(diff);
					if (do_.expectedDiff == "") {
						unexpectedDiff.WriteString("Edit [" + index + "]:: " + do_.caption
							+ "\n!!! Unexpected diff, please review and either fix or write explanation as expectedDiff !!!\n" + diff + "\n");
					}
				} else if (do_.expectedDiff != "") {
					baselineBuilder.WriteString("\n\nDiff:: " + do_.expectedDiff + " !!! Diff not found but explanation present, please review and remove the explanation !!!\n");
					unexpectedDiff.WriteString("Edit [" + index + "]:: " + do_.caption
						+ "\n!!! Diff not found but explanation present, please review and remove the explanation !!!\n");
				}
			}
		}
		Gate.OnBaseline(baselineSubfolder + "/" + baselineFile, baselineBuilder.String());
		if (unexpectedDiff.String() != "") {
			Gate.OnError(baselineSubfolder + "/" + baselineFile, "Test " + this.subScenario + " has unexpected diff " + unexpectedDiff.String()
				+ " with incremental build, please review the baseline file");
		}
	}

	function getBaselineSubFolder():String {
		var commandName = "tsc";
		if (Slices.ContainsFunc(this.commandLineArgs, function(arg:String):Bool {
			return switch (arg) {
				case "-b", "--b", "-build", "--build": true;
				default: false;
			}
		})) {
			commandName = "tsbuild";
		}
		var w = "";
		if (Slices.ContainsFunc(this.commandLineArgs, function(arg:String):Bool {
			return switch (arg) {
				case "-w", "--w", "-watch", "--watch": true;
				default: false;
			}
		})) {
			w = "Watch";
		}
		return commandName + w;
	}
}

// PORT: gate hooks replacing testing.T and baseline.Run (not in Go). The gate main installs them.
class Gate {
	public static var Filter:Null<(name:String) -> Bool> = null;
	public static var OnSkipped:(name:String) -> Void = function(name) {};
	public static var OnBaseline:(path:String, actual:String) -> Void = function(path, actual) {};
	public static var OnError:(path:String, msg:String) -> Void = function(path, msg) {};
	public static var OnCrash:(name:String, path:String, err:String, partial:String) -> Void = function(name, path, err, partial) {};
}
