package ts.tsoptions;

// Port of export_test.go (package tsoptions: test-only exports).
class ExportTest {
	static function getTestParseCommandLineWorkerDiagnostics(decls:Null<Array<CommandLineOption>>):ParseCommandLineWorkerDiagnostics {
		if (Core.len(decls) == 0) {
			return Tsoptions.CompilerOptionsDidYouMeanDiagnostics;
		}
		return Tsoptions.getParseCommandLineWorkerDiagnostics(decls);
	}

	public static function ParseCommandLineTestWorker(decls:Null<Array<CommandLineOption>>, commandLine:Array<String>, fs:FS,
			currentDirectory:String):TestCommandLineParser {
		final parser = new CommandLineParser();
		parser.fs = fs;
		parser.currentDirectory = currentDirectory;
		parser.workerDiagnostics = Tsoptions.CompilerOptionsDidYouMeanDiagnostics;
		parser.fileNames = [];
		parser.options = new OrderedMap<String, Dynamic>();
		parser.errors = [];
		if (Core.len(decls) != 0) {
			parser.workerDiagnostics = getTestParseCommandLineWorkerDiagnostics(decls);
		}

		parser.optionsMap = Tsoptions.GetNameMapFromList(parser.OptionsDeclarations());
		parser.parseStrings(commandLine);
		final r = new TestCommandLineParser();
		r.Fs = fs;
		r.WorkerDiagnostics = parser.workerDiagnostics;
		r.FileNames = parser.fileNames;
		r.Options = parser.options;
		r.Errors = parser.errors;
		return r;
	}
}

class TestCommandLineParser {
	public var Fs:FS = null;
	public var WorkerDiagnostics:ParseCommandLineWorkerDiagnostics = null;
	public var FileNames:Array<String> = null;
	public var Options:OrderedMap<String, Dynamic> = null;
	public var Errors:Array<Diagnostic> = null;

	public function new() {}
}
