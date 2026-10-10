package ts.execute.tsc;

// Port of compile.go (types; package-level funcs are in Tsc.hx).

// PORT: Go passes a tsc.System wherever a tsoptions.ParseConfigHost is expected (structural
// interfaces); Haxe interfaces are nominal, so System extends ParseConfigHost (FS, GetCurrentDirectory).
interface System extends ParseConfigHost {
	function Writer():Writer;
	function FS():FS;
	function DefaultLibraryPath():std.String;
	function GetCurrentDirectory():std.String;
	function WriteOutputIsTTY():Bool;
	function GetWidthOfTerminal():Int;
	function GetEnvironmentVariable(name:std.String):std.String;

	function Now():Time;
	function SinceStart():Duration;
}

enum abstract ExitStatus(Int) from Int to Int {
	var ExitStatusSuccess = 0;
	var ExitStatusDiagnosticsPresent_OutputsSkipped = 1;
	var ExitStatusDiagnosticsPresent_OutputsGenerated = 2;
	var ExitStatusInvalidProject_OutputsSkipped = 3;
	var ExitStatusProjectReferenceCycle_OutputsSkipped = 4;
	var ExitStatusNotImplemented = 5;
}

interface Watcher {
	function DoCycle():Void;
}

class CommandLineResult {
	public var Status:ExitStatus = ExitStatusSuccess;
	public var Watcher:Null<Watcher> = null;

	public function new(Status:ExitStatus = ExitStatusSuccess, ?Watcher:Watcher) {
		this.Status = Status;
		this.Watcher = Watcher;
	}
}

interface CommandLineTesting {
	// Ensure that all emitted files are timestamped in order to ensure they are deterministic for test baseline
	// PORT: mTimesCache (collections.SyncMap[tspath.Path, time.Time]) → SyncMap<String, Time>.
	function OnEmittedFiles(result:Null<EmitResult>, mTimesCache:Null<SyncMap<std.String, Time>>):Void;
	function OnListFilesStart(w:Writer):Void;
	function OnListFilesEnd(w:Writer):Void;
	function OnStatisticsStart(w:Writer):Void;
	function OnStatisticsEnd(w:Writer):Void;
	function OnBuildStatusReportStart(w:Writer):Void;
	function OnBuildStatusReportEnd(w:Writer):Void;
	function OnWatchStatusReportStart():Void;
	function OnWatchStatusReportEnd():Void;
	function GetTrace(w:Writer, locale:Locale):TraceFunc;
	function OnProgram(program:ts.execute.incremental.Program.Program):Void;
}

// PORT: time.Duration fields → go.Time.Duration (Int64 nanoseconds), zero = 0.
class CompileTimes {
	public var ConfigTime:Duration = 0;
	public var ParseTime:Duration = 0;
	public var bindTime:Duration = 0;
	public var checkTime:Duration = 0;
	public var totalTime:Duration = 0;
	public var emitTime:Duration = 0;
	public var BuildInfoReadTime:Duration = 0;
	public var ChangesComputeTime:Duration = 0;

	public function new() {}
}

class CompileAndEmitResult {
	public var Diagnostics:Null<Array<Diagnostic>> = null;
	public var EmitResult:Null<EmitResult> = null;
	public var Status:ExitStatus = ExitStatusSuccess;
	public var times:Null<CompileTimes> = null;

	public function new() {}
}
