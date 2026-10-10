package ts.tsoptions;

// Port of diagnostics.go (types; package-level vars are in Tsoptions.hx).
// PORT: module named Diagnostics_ so it does not shadow ts.diagnostics.Diagnostics.
@:allow(ts.tsoptions)
class DidYouMeanOptionsDiagnostics {
	var alternateMode:Null<AlternateModeDiagnostics> = null;
	public var OptionDeclarations:Null<Array<CommandLineOption>> = null;
	public var UnknownOptionDiagnostic:Null<Message> = null;
	public var UnknownDidYouMeanDiagnostic:Null<Message> = null;

	public function new() {}
}

@:allow(ts.tsoptions)
class AlternateModeDiagnostics {
	var diagnostic:Null<Message> = null;
	var optionsNameMap:Null<NameMap> = null;

	public function new(diagnostic:Null<Message>, optionsNameMap:Null<NameMap>) {
		this.diagnostic = diagnostic;
		this.optionsNameMap = optionsNameMap;
	}
}

// PORT: `optionsNameMapOnce sync.Once` omitted (single-threaded; the field is never used).
@:allow(ts.tsoptions)
class ParseCommandLineWorkerDiagnostics {
	var didYouMean:DidYouMeanOptionsDiagnostics = new DidYouMeanOptionsDiagnostics();
	var optionsNameMap:Null<NameMap> = null;
	public var OptionTypeMismatchDiagnostic:Null<Message> = null;

	public function new() {}
}
