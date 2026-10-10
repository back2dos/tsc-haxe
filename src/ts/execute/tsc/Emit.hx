package ts.execute.tsc;

// Port of emit.go (types; package-level funcs are in Tsc.hx).
class EmitInput {
	public var Sys:System = null;
	public var ProgramLike:ProgramLike = null;
	public var Program:Program = null;
	public var Config:ParsedCommandLine = null;
	public var ReportDiagnostic:DiagnosticReporter = null;
	public var ReportErrorSummary:DiagnosticsReporter = null;
	public var Writer:Writer = null;
	public var WriteFile:Null<WriteFile> = null;
	public var CompileTimes:CompileTimes = null;
	public var Testing:Null<CommandLineTesting> = null;
	public var TestingMTimesCache:Null<SyncMap<std.String, Time>> = null;
	public var Tracing:Null<Tracing> = null;

	public function new() {}
}
