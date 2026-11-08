package ts.execute.build;

// Port of compilerHost.go (Go type `compilerHost`; `_` suffix: compiler.CompilerHost is the interface).
@:allow(ts.execute.build)
class CompilerHost_ implements CompilerHost implements ParseConfigHost {
	var host:Host = null;
	var trace:TraceFunc = null;

	public function new(host:Host, trace:TraceFunc) {
		this.host = host;
		this.trace = trace;
	}

	public function FS():FS {
		return this.host.FS();
	}

	public function DefaultLibraryPath():std.String {
		return this.host.DefaultLibraryPath();
	}

	public function GetCurrentDirectory():std.String {
		return this.host.GetCurrentDirectory();
	}

	public function Trace(msg:Message, ...args:Any):Void {
		this.trace(msg, args.toArray());
	}

	public function GetSourceFile(opts:SourceFileParseOptions):SourceFile {
		return this.host.GetSourceFile(opts);
	}

	// PORT: TypeScript main's build compiler host holds the project's content mapper project; the port's
	// tsc --build creates none (content mappers are not supported by the port's CLI).
	public function GetContentMappedSourceFiles(parseOptions:SourceFileParseOptions,
			mapper:ts.contentmapper.Contentmapper.Mapper):go.Tuple.ValueError<ts.contentmapper.Transform.SourceFiles> {
		return new go.Tuple.ValueError(new ts.contentmapper.Transform.SourceFiles(), ts.contentmapper.Contentmapper.ErrProjectUnavailable);
	}

	public function ContentMapperProject():ts.contentmapper.Host.Project {
		return null;
	}

	public function GetResolvedProjectReference(fileName:std.String, path:Path):ParsedCommandLine {
		return this.host.GetResolvedProjectReference(fileName, path);
	}
}
