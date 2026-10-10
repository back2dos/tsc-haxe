package ts.testutil.tsbaseline;

import ts.tsoptions.Tsconfigparsing.TsConfigSourceFile;

// Port of js_emit_baseline.go: types (the package-level funcs are in Tsbaseline.hx).
@:allow(ts.testutil.tsbaseline)
class DeclarationCompilationContext {
	var declInputFiles:Array<TestFile> = null;
	var declOtherFiles:Array<TestFile> = null;
	var harnessSettings:HarnessOptions = null;
	var options:CompilerOptions = null;
	var currentDirectory:String = "";
	var configFile:TsConfigSourceFile = null;

	public function new() {}
}

@:allow(ts.testutil.tsbaseline)
class DeclarationCompilationResult {
	var declInputFiles:Array<TestFile> = null;
	var declOtherFiles:Array<TestFile> = null;
	var declResult:CompilationResult = null;

	public function new() {}
}

// PORT: Go strings.Builder for jsCode in DoJSEmitBaseline; `strings.HasSuffix(jsCode.String(), "\n")`
// is answered from the last non-empty string written.
class JsCodeBuilder {
	final b = new StringBuf();
	var endsWithNewline = false;

	public function new() {}

	public function WriteString(s:String):Void {
		if (s.length > 0) {
			b.add(s);
			endsWithNewline = StringTools.fastCodeAt(s, s.length - 1) == "\n".code;
		}
	}

	public function Len():Int {
		return b.length;
	}

	public function HasSuffixNewline():Bool {
		return endsWithNewline;
	}

	public function String():String {
		return b.toString();
	}
}
