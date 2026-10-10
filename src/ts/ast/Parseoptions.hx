package ts.ast;

// Port of parseoptions.go (types; the functions are in Ast.hx).

class SourceFileParseOptions {
	public var FileName:String = "";
	public var Path:Path = "";
	public var ExternalModuleIndicatorOptions:ExternalModuleIndicatorOptions = new ExternalModuleIndicatorOptions();

	public function new() {}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():SourceFileParseOptions {
		final r = new SourceFileParseOptions();
		r.FileName = FileName;
		r.Path = Path;
		r.ExternalModuleIndicatorOptions = ExternalModuleIndicatorOptions.copy();
		return r;
	}
}

class ExternalModuleIndicatorOptions {
	public var JSX:Bool = false;
	public var Force:Bool = false;

	public function new(JSX = false, Force = false) {
		this.JSX = JSX;
		this.Force = Force;
	}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():ExternalModuleIndicatorOptions {
		return new ExternalModuleIndicatorOptions(JSX, Force);
	}
}
