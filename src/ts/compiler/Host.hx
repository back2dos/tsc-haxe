package ts.compiler;

import ts.diagnostics.Diagnostics.Message;

// Port of host.go.

// PORT: Go's CompilerHost is also used where a module.ResolutionHost is expected (it has FS and
// GetCurrentDirectory); Haxe interfaces are nominal, so it extends ResolutionHost.
interface CompilerHost extends ResolutionHost {
	function FS():FS;
	function DefaultLibraryPath():std.String;
	function GetCurrentDirectory():RootedDirectoryPath;
	function Trace(msg:Message, ...args:Any):Void;
	function GetSourceFile(opts:SourceFileParseOptions):SourceFile;
	// GetContentMappedSourceFiles produces the source file for a content-mapped (foreign) file by running
	// the given mapper's transform on the file's content. The caller resolves the mapper (and owns the
	// failure accounting), so implementations must use it as-is.
	function GetContentMappedSourceFiles(parseOptions:SourceFileParseOptions, mapper:ts.contentmapper.Contentmapper.Mapper):ValueError<ts.contentmapper.Transform.SourceFiles>;
	// ContentMapperProject returns the project-scoped content mapper used by this host, or nil when the
	// command line has no content mappers.
	function ContentMapperProject():ts.contentmapper.Host.Project;
	function GetResolvedProjectReference(fileName:RootedFilePath, path:PathKey):ParsedCommandLine;
}

// PORT: the Go trace callback `func(msg *diagnostics.Message, args ...any)` → a function taking the
// argument slice (Haxe function types cannot be variadic).
typedef TraceFunc = (msg:Message, args:Array<Any>) -> Void;

// Go type compilerHost (the exported name CompilerHost is the interface).
class CompilerHost_ implements CompilerHost implements ParseConfigHost {
	var currentDirectory:RootedDirectoryPath = cast "";
	var fs:FS = null;
	var defaultLibraryPath:std.String = "";
	var extendedConfigCache:ExtendedConfigCache = null;
	var trace:TraceFunc = null;
	var contentMapperProject:ts.contentmapper.Host.Project = null;

	public function new() {}

	public function FS():FS {
		return this.fs;
	}

	public function DefaultLibraryPath():std.String {
		return this.defaultLibraryPath;
	}

	public function GetCurrentDirectory():RootedDirectoryPath {
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
		return Parser.ParseSourceFile(opts, text, Core.EnsureScriptKindFromFileName(opts.FileName));
	}

	public function GetContentMappedSourceFiles(parseOptions:SourceFileParseOptions,
			mapper:ts.contentmapper.Contentmapper.Mapper):ValueError<ts.contentmapper.Transform.SourceFiles> {
		if (this.contentMapperProject == null) {
			return new ValueError(new ts.contentmapper.Transform.SourceFiles(), ts.contentmapper.Contentmapper.ErrProjectUnavailable);
		}
		final r = this.FS().ReadFile(parseOptions.FileName);
		if (!r.ok) {
			return new ValueError(new ts.contentmapper.Transform.SourceFiles(), null);
		}
		final files = ts.contentmapper.Transform.TransformAndParse(parseOptions, r.value, mapper, this.contentMapperProject);
		if (files.err == null) {
			return new ValueError(files.value, ts.contentmapper.Transform.CheckSupplementalFileNameCollisions(files.value, this.FS().FileExists));
		}
		return files;
	}

	public function ContentMapperProject():ts.contentmapper.Host.Project {
		return this.contentMapperProject;
	}

	public function GetResolvedProjectReference(fileName:RootedFilePath, path:PathKey):ParsedCommandLine {
		final commandLine = Tsoptions.GetParsedCommandLineOfConfigFilePath(fileName, path, null, null /*optionsRaw*/, this, this.extendedConfigCache).a;
		return commandLine;
	}
}
