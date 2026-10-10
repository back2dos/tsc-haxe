package ts.compiler;

import ts.diagnostics.Diagnostics.Message;

// Port of host.go.

// PORT: Go's CompilerHost is also used where a module.ResolutionHost is expected (it has FS and
// GetCurrentDirectory); Haxe interfaces are nominal, so it extends ResolutionHost.
interface CompilerHost extends ResolutionHost {
	function FS():FS;
	function DefaultLibraryPath():std.String;
	function GetCurrentDirectory():std.String;
	function Trace(msg:Message, ...args:Any):Void;
	function GetSourceFile(opts:SourceFileParseOptions):SourceFile;
	function GetResolvedProjectReference(fileName:std.String, path:Path):ParsedCommandLine;
}

// PORT: the Go trace callback `func(msg *diagnostics.Message, args ...any)` → a function taking the
// argument slice (Haxe function types cannot be variadic).
typedef TraceFunc = (msg:Message, args:Array<Any>) -> Void;

// Go type compilerHost (the exported name CompilerHost is the interface).
class CompilerHost_ implements CompilerHost implements ParseConfigHost {
	var currentDirectory:std.String = "";
	var fs:FS = null;
	var defaultLibraryPath:std.String = "";
	var extendedConfigCache:ExtendedConfigCache = null;
	var trace:TraceFunc = null;

	public function new() {}

	public function FS():FS {
		return this.fs;
	}

	public function DefaultLibraryPath():std.String {
		return this.defaultLibraryPath;
	}

	public function GetCurrentDirectory():std.String {
		return this.currentDirectory;
	}

	public function Trace(msg:Message, ...args:Any):Void {
		this.trace(msg, args.toArray());
	}

	public function GetSourceFile(opts:SourceFileParseOptions):SourceFile {
		final r = this.FS().ReadFile(opts.FileName);
		final text = r.value, ok = r.ok;
		if (!ok) {
			return null;
		}
		return Parser.ParseSourceFile(opts, text, Core.GetScriptKindFromFileName(opts.FileName));
	}

	public function GetResolvedProjectReference(fileName:std.String, path:Path):ParsedCommandLine {
		final commandLine = Tsoptions.GetParsedCommandLineOfConfigFilePath(fileName, path, null, null /*optionsRaw*/, this, this.extendedConfigCache).a;
		return commandLine;
	}
}
