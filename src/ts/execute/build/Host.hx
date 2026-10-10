package ts.execute.build;

// Port of host.go (Go type `host`).
// PORT: Go satisfies compiler.CompilerHost, incremental.BuildInfoReader, incremental.Host and (where
// passed to tsoptions) tsoptions.ParseConfigHost structurally; Haxe declares them.
@:allow(ts.execute.build)
class Host implements CompilerHost implements ParseConfigHost implements BuildInfoReader implements ts.execute.incremental.Host.Host {
	var orchestrator:Orchestrator = null;
	var host:CompilerHost = null;

	// Caches that last only for build cycle and then cleared out
	var extendedConfigCache:ExtendedConfigCache = new ExtendedConfigCache();
	var sourceFiles:ParseCache<SourceFileParseOptions, SourceFile> = new ParseCache(sourceFileParseOptionsKey);
	// PORT: collections.SyncMap value field → SyncMap with Go's zero Duration.
	var configTimes:SyncMap<Path, Duration> = new SyncMap<Path, Duration>(0);

	// caches that stay as long as they are needed
	var resolvedReferences:ParseCache<Path, ParsedCommandLine> = new ParseCache(pathKey);
	var mTimes:SyncMap<Path, Time> = null;

	public function new() {}

	// PORT: ast.SourceFileParseOptions is a comparable Go struct used as a map key; encoded as a String.
	static function sourceFileParseOptionsKey(opts:SourceFileParseOptions):std.String {
		return opts.FileName + "\x00" + opts.Path + "\x00" + (opts.ExternalModuleIndicatorOptions.JSX ? "1" : "0")
			+ (opts.ExternalModuleIndicatorOptions.Force ? "1" : "0");
	}

	static function pathKey(path:Path):std.String {
		return path;
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
		throw "build.Orchestrator.host does not support tracing, use a different host for tracing";
	}

	public function GetSourceFile(opts:SourceFileParseOptions):SourceFile {
		if (Tspath.IsDeclarationFileName(opts.FileName) || Tspath.FileExtensionIs(opts.FileName, Tspath.ExtensionJson)) {
			// Cache dts and json files as they will be reused
			return this.sourceFiles.loadOrStore(opts, this.host.GetSourceFile, false /* allowZero */);
		}
		return this.host.GetSourceFile(opts);
	}

	public function GetResolvedProjectReference(fileName:std.String, path:Path):ParsedCommandLine {
		return this.resolvedReferences.loadOrStore(path, function(path:Path):ParsedCommandLine {
			final configStart = this.orchestrator.opts.Sys.Now();
			// Wrap command line options in "compilerOptions" key to match tsconfig.json structure
			var commandLineRaw:Null<OrderedMap<std.String, Dynamic>> = null;
			if (Std.isOfType(this.orchestrator.opts.Command.Raw, OrderedMap)) {
				final raw:OrderedMap<std.String, Dynamic> = this.orchestrator.opts.Command.Raw;
				final wrapped = new OrderedMap<std.String, Dynamic>();
				wrapped.Set("compilerOptions", raw);
				commandLineRaw = wrapped;
			}
			final commandLine = Tsoptions.GetParsedCommandLineOfConfigFilePath(fileName, path, this.orchestrator.opts.Command.CompilerOptions, commandLineRaw,
				this, this.extendedConfigCache).a;
			final configTime = this.orchestrator.opts.Sys.Now().Sub(configStart);
			this.configTimes.Store(path, configTime);
			return commandLine;
		}, true /* allowZero */);
	}

	public function ReadBuildInfo(config:ParsedCommandLine):BuildInfo {
		final configPath = this.orchestrator.toPath(config.ConfigName());
		final task = this.orchestrator.getTask(configPath);
		final buildInfo = task.loadOrStoreBuildInfo(this.orchestrator, this.orchestrator.toPath(config.ConfigName()), config.GetBuildInfoFileName()).a;
		return buildInfo;
	}

	public function GetMTime(file:std.String):Time {
		return this.loadOrStoreMTime(file, null, true);
	}

	public function SetMTime(file:std.String, mTime:Time):Null<Error> {
		return this.FS().Chtimes(file, Time.Zero(), mTime);
	}

	function loadOrStoreMTime(file:std.String, oldCache:Null<SyncMap<Path, Time>>, store:Bool):Time {
		final path = this.orchestrator.toPath(file);
		final existing = this.mTimes.Load(path);
		if (existing.ok) {
			return existing.value;
		}
		var found = false;
		var mTime:Time = Time.Zero();
		if (oldCache != null) {
			final r = oldCache.Load(path);
			mTime = r.value;
			found = r.ok;
		}
		if (!found) {
			mTime = Incremental.GetMTime(this.host, file);
		}
		if (store) {
			mTime = this.mTimes.LoadOrStore(path, mTime).value;
		}
		return mTime;
	}

	function storeMTime(file:std.String, mTime:Time):Void {
		final path = this.orchestrator.toPath(file);
		this.mTimes.Store(path, mTime);
	}

	function storeMTimeFromOldCache(file:std.String, oldCache:SyncMap<Path, Time>):Void {
		final path = this.orchestrator.toPath(file);
		final r = oldCache.Load(path);
		if (r.ok) {
			this.mTimes.Store(path, r.value);
		}
	}
}
