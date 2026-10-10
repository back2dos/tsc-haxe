package ts.tsoptions;

// Port of parsinghelpers.go (types and methods; package-level funcs are in Tsoptions.hx).

interface OptionParser {
	function ParseOption(key:std.String, value:Dynamic):Null<Array<Diagnostic>>;
	function UnknownOptionDiagnostic():Null<Message>;
	function UnknownDidYouMeanDiagnostic():Null<Message>;
}

// PORT: Go embeds *core.CompilerOptions; the embedded pointer is the field CompilerOptions.
class CompilerOptionsParser implements OptionParser {
	public var CompilerOptions:CompilerOptions;

	public function new(CompilerOptions:CompilerOptions) {
		this.CompilerOptions = CompilerOptions;
	}

	public function ParseOption(key:std.String, value:Dynamic):Null<Array<Diagnostic>> {
		return Tsoptions.ParseCompilerOptions(key, value, this.CompilerOptions);
	}

	public function UnknownOptionDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDiagnostics("compilerOptions");
	}

	public function UnknownDidYouMeanDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDidYouMeanDiagnostics("compilerOptions");
	}
}

class WatchOptionsParser implements OptionParser {
	public var WatchOptions:WatchOptions;

	public function new(WatchOptions:WatchOptions) {
		this.WatchOptions = WatchOptions;
	}

	public function ParseOption(key:std.String, value:Dynamic):Null<Array<Diagnostic>> {
		return Tsoptions.ParseWatchOptions(key, value, this.WatchOptions);
	}

	public function UnknownOptionDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDiagnostics("watchOptions");
	}

	public function UnknownDidYouMeanDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDidYouMeanDiagnostics("watchOptions");
	}
}

class TypeAcquisitionParser implements OptionParser {
	public var TypeAcquisition:TypeAcquisition;

	public function new(TypeAcquisition:TypeAcquisition) {
		this.TypeAcquisition = TypeAcquisition;
	}

	public function ParseOption(key:std.String, value:Dynamic):Null<Array<Diagnostic>> {
		return Tsoptions.ParseTypeAcquisition(key, value, this.TypeAcquisition);
	}

	public function UnknownOptionDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDiagnostics("typeAcquisition");
	}

	public function UnknownDidYouMeanDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDidYouMeanDiagnostics("typeAcquisition");
	}
}

class BuildOptionsParser implements OptionParser {
	public var BuildOptions:BuildOptions;

	public function new(BuildOptions:BuildOptions) {
		this.BuildOptions = BuildOptions;
	}

	public function ParseOption(key:std.String, value:Dynamic):Null<Array<Diagnostic>> {
		return Tsoptions.ParseBuildOptions(key, value, this.BuildOptions);
	}

	public function UnknownOptionDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDiagnostics("buildOptions");
	}

	public function UnknownDidYouMeanDiagnostic():Null<Message> {
		return Tsoptions.extraKeyDidYouMeanDiagnostics("buildOptions");
	}
}
