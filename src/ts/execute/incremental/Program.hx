package ts.execute.incremental;

// Port of program.go (types and methods). NewProgram and normalizePackageJsons are in Incremental.hx.

enum abstract SignatureUpdateKind(Int) from Int to Int {
	var SignatureUpdateKindComputedDts = 0;
	var SignatureUpdateKindStoredAtEmit = 1;
	var SignatureUpdateKindUsedVersion = 2;
}

@:allow(ts.execute.incremental)
class Program implements ProgramLike {
	var snapshot:Snapshot = null;
	var program:CompilerProgram = null;
	var host:Host = null;

	// Testing data
	var testingData:TestingData = null;

	public function new() {}

	public function GetTestingData():TestingData {
		return this.testingData;
	}

	function panicIfNoProgram(method:std.String):Void {
		if (this.program == null) {
			throw method + ": should not be called without program";
		}
	}

	public function GetProgram():CompilerProgram {
		this.panicIfNoProgram("GetProgram");
		return this.program;
	}

	public function HasChangedDtsFile():Bool {
		return this.snapshot.hasChangedDtsFile;
	}

	// Options implements compiler.AnyProgram interface.
	public function Options():CompilerOptions {
		return this.snapshot.options;
	}

	// CommonSourceDirectory implements compiler.AnyProgram interface.
	public function CommonSourceDirectory():std.String {
		this.panicIfNoProgram("CommonSourceDirectory");
		return this.program.CommonSourceDirectory();
	}

	// Program implements compiler.AnyProgram interface.
	public function Program():CompilerProgram {
		this.panicIfNoProgram("Program");
		return this.program;
	}

	// IsSourceFileDefaultLibrary implements compiler.AnyProgram interface.
	public function IsSourceFileDefaultLibrary(path:Path):Bool {
		this.panicIfNoProgram("IsSourceFileDefaultLibrary");
		return this.program.IsSourceFileDefaultLibrary(path);
	}

	// GetSourceFiles implements compiler.AnyProgram interface.
	public function GetSourceFiles():Array<SourceFile> {
		this.panicIfNoProgram("GetSourceFiles");
		return this.program.GetSourceFiles();
	}

	// GetSourceFile implements compiler.AnyProgram interface.
	public function GetSourceFile(path:std.String):SourceFile {
		this.panicIfNoProgram("GetSourceFile");
		return this.program.GetSourceFile(path);
	}

	// GetConfigFileParsingDiagnostics implements compiler.AnyProgram interface.
	public function GetConfigFileParsingDiagnostics():Array<Diagnostic> {
		this.panicIfNoProgram("GetConfigFileParsingDiagnostics");
		return this.program.GetConfigFileParsingDiagnostics();
	}

	// GetSyntacticDiagnostics implements compiler.AnyProgram interface.
	public function GetSyntacticDiagnostics(ctx:Context, file:SourceFile):Array<Diagnostic> {
		this.panicIfNoProgram("GetSyntacticDiagnostics");
		return this.program.GetSyntacticDiagnostics(ctx, file);
	}

	// GetBindDiagnostics implements compiler.AnyProgram interface.
	public function GetBindDiagnostics(ctx:Context, file:SourceFile):Array<Diagnostic> {
		this.panicIfNoProgram("GetBindDiagnostics");
		return this.program.GetBindDiagnostics(ctx, file);
	}

	public function GetProgramDiagnostics():Array<Diagnostic> {
		this.panicIfNoProgram("GetProgramDiagnostics");
		return this.program.GetProgramDiagnostics();
	}

	public function GetGlobalDiagnostics(ctx:Context):Array<Diagnostic> {
		this.panicIfNoProgram("GetGlobalDiagnostics");
		return this.program.GetGlobalDiagnostics(ctx);
	}

	// GetSemanticDiagnostics implements compiler.AnyProgram interface.
	public function GetSemanticDiagnostics(ctx:Context, file:SourceFile):Array<Diagnostic> {
		this.panicIfNoProgram("GetSemanticDiagnostics");
		if (this.snapshot.options.NoCheck.IsTrue()) {
			return null;
		}

		// Ensure all the diagnsotics are cached
		this.collectSemanticDiagnosticsOfAffectedFiles(ctx, file);
		if (ctx.Err() != null) {
			return null;
		}

		// Return result from cache
		if (file != null) {
			return this.getSemanticDiagnosticsOfFile(file);
		}

		var diagnostics:Array<Diagnostic> = null;
		for (file in this.program.GetSourceFiles()) {
			final d = this.getSemanticDiagnosticsOfFile(file);
			if (d != null && d.length > 0) {
				if (diagnostics == null)
					diagnostics = [];
				for (x in d)
					diagnostics.push(x);
			}
		}
		return diagnostics;
	}

	function getSemanticDiagnosticsOfFile(file:SourceFile):Array<Diagnostic> {
		final r = this.snapshot.semanticDiagnosticsPerFile.Load(file.Path());
		if (!r.ok) {
			throw "After handling all the affected files, there shouldnt be more changes";
		}
		final cachedDiagnostics = r.value;
		return Slices.Concat(Compiler.FilterNoEmitSemanticDiagnostics(cachedDiagnostics.getDiagnostics(this.program, file), this.snapshot.options),
			this.program.GetIncludeProcessorDiagnostics(file));
	}

	// GetDeclarationDiagnostics implements compiler.AnyProgram interface.
	public function GetDeclarationDiagnostics(ctx:Context, file:SourceFile):Array<Diagnostic> {
		this.panicIfNoProgram("GetDeclarationDiagnostics");
		final options = new EmitOptions();
		options.TargetSourceFile = file;
		final result = Incremental.emitFiles(ctx, this, options, true);
		if (result != null) {
			return result.Diagnostics;
		}
		return null;
	}

	// GetSuggestionDiagnostics implements compiler.AnyProgram interface.
	public function GetSuggestionDiagnostics(ctx:Context, file:SourceFile):Array<Diagnostic> {
		this.panicIfNoProgram("GetSuggestionDiagnostics");
		return this.program.GetSuggestionDiagnostics(ctx, file); // TODO: incremental suggestion diagnostics (only relevant in editor incremental builder?)
	}

	// GetModeForUsageLocation implements compiler.AnyProgram interface.
	public function Emit(ctx:Context, options:EmitOptions):EmitResult {
		this.panicIfNoProgram("Emit");

		var result:EmitResult = null;
		if (this.snapshot.options.NoEmit.IsTrue()) {
			result = new EmitResult();
			result.EmitSkipped = true;
		} else {
			result = Compiler.HandleNoEmitOnError(ctx, this, options.TargetSourceFile);
			if (ctx.Err() != null) {
				return null;
			}
		}
		if (result != null) {
			if (options.TargetSourceFile != null) {
				return result;
			}

			// Emit buildInfo and combine result
			final buildInfoResult = this.emitBuildInfo(ctx, options);
			if (buildInfoResult != null) {
				result.Diagnostics = Incremental.appendAll(result.Diagnostics, buildInfoResult.Diagnostics);
				result.EmittedFiles = Incremental.appendAll(result.EmittedFiles, buildInfoResult.EmittedFiles);
			}
			return result;
		}
		return Incremental.emitFiles(ctx, this, options, false);
	}

	// Handle affected files and cache the semantic diagnostics for all of them or the file asked for
	function collectSemanticDiagnosticsOfAffectedFiles(ctx:Context, file:SourceFile):Void {
		if (this.snapshot.canUseIncrementalState()) {
			// Get all affected files
			Incremental.collectAllAffectedFiles(ctx, this);
			if (ctx.Err() != null) {
				return;
			}

			if (this.snapshot.semanticDiagnosticsPerFile.Size() == this.program.GetSourceFiles().length) {
				// If we have all the files,
				return;
			}
		}

		var affectedFiles:Array<SourceFile> = null;
		if (file != null) {
			if (this.snapshot.semanticDiagnosticsPerFile.Load(file.Path()).ok) {
				return;
			}
			affectedFiles = [file];
		} else {
			for (file in this.program.GetSourceFiles()) {
				if (!this.snapshot.semanticDiagnosticsPerFile.Load(file.Path()).ok) {
					if (affectedFiles == null)
						affectedFiles = [];
					affectedFiles.push(file);
				}
			}
		}

		// Get their diagnostics and cache them
		final diagnosticsPerFile = this.program.GetSemanticDiagnosticsWithoutNoEmitFiltering(ctx, affectedFiles);
		// commit changes if no err
		if (ctx.Err() != null) {
			return;
		}

		// Commit changes to snapshot
		for (file in diagnosticsPerFile.keys()) {
			final diagnostics = diagnosticsPerFile.get(file);
			this.snapshot.semanticDiagnosticsPerFile.Store(file.Path(), new DiagnosticsOrBuildInfoDiagnosticsWithFileName(diagnostics));
		}
		if (this.snapshot.semanticDiagnosticsPerFile.Size() == this.program.GetSourceFiles().length
			&& this.snapshot.checkPending
			&& !this.snapshot.options.NoCheck.IsTrue()) {
			this.snapshot.checkPending = false;
		}
		this.snapshot.buildInfoEmitPending = true;
	}

	function emitBuildInfo(ctx:Context, options:EmitOptions):EmitResult {
		final tr = this.program.Tracing();
		if (tr != null) {
			final done = tr.Push(PhaseEmit, "emitBuildInfo", null, true);
			final r = try this.emitBuildInfoWorker(ctx, options) catch (e:Dynamic) {
				done();
				throw e;
			};
			done();
			return r;
		}
		return this.emitBuildInfoWorker(ctx, options);
	}

	// PORT: body of emitBuildInfo after the tracing defer.
	function emitBuildInfoWorker(ctx:Context, options:EmitOptions):EmitResult {
		final buildInfoFileName = Outputpaths.GetBuildInfoFileName(this.snapshot.options,
			new ComparePathsOptions(this.program.UseCaseSensitiveFileNames(), this.program.GetCurrentDirectory()));
		if (buildInfoFileName == "" || this.program.IsEmitBlocked(buildInfoFileName)) {
			return null;
		}
		if (this.snapshot.hasErrors == TSUnknown) {
			this.ensureHasErrorsForState(ctx, this.program);
			if (this.snapshot.hasErrors != this.snapshot.hasErrorsFromOldState
				|| this.snapshot.hasSemanticErrors != this.snapshot.hasSemanticErrorsFromOldState) {
				this.snapshot.buildInfoEmitPending = true;
			}
		}
		if (this.snapshot.packageJsons == null) {
			this.ensurePackageJsonsForState();
			if (!Slices.Equal(this.snapshot.packageJsons, this.snapshot.packageJsonsFromOldState)
				|| !Slices.Equal(this.snapshot.missingPackageJsons, this.snapshot.missingPackageJsonsFromOldState)) {
				this.snapshot.buildInfoEmitPending = true;
			}
		}
		if (!this.snapshot.buildInfoEmitPending) {
			return null;
		}
		if (ctx.Err() != null) {
			return null;
		}
		final buildInfo = Incremental.snapshotToBuildInfo(this.snapshot, this.program, buildInfoFileName);
		final text = Json.MarshalOrdered(buildInfo);
		var err:Null<Error>;
		if (options.WriteFile != null) {
			final data = new WriteFileData();
			data.BuildInfo = buildInfo;
			err = options.WriteFile(buildInfoFileName, text, data);
		} else {
			err = this.program.Host().FS().WriteFile(buildInfoFileName, text);
		}
		if (err != null) {
			final r = new EmitResult();
			r.EmitSkipped = true;
			r.Diagnostics = [
				Ast.NewCompilerDiagnostic(Diagnostics.Could_not_write_file_0_Colon_1, buildInfoFileName, err.Error())
			];
			return r;
		}
		this.snapshot.buildInfoEmitPending = false;
		final r = new EmitResult();
		r.EmitSkipped = false;
		r.EmittedFiles = [buildInfoFileName];
		return r;
	}

	function ensureHasErrorsForState(ctx:Context, program:CompilerProgram):Void {
		var hasIncludeProcessingDiagnostics:() -> Bool = null;
		var hasEmitDiagnostics = false;
		if (this.snapshot.canUseIncrementalState()) {
			if (Slices.ContainsFunc(program.GetSourceFiles(), function(file:SourceFile):Bool {
				if (this.snapshot.emitDiagnosticsPerFile.Load(file.Path()).ok) {
					// emit diagnostics will be encoded in buildInfo;
					return true;
				}
				if (hasIncludeProcessingDiagnostics == null && Core.len(this.program.GetIncludeProcessorDiagnostics(file)) > 0) {
					hasIncludeProcessingDiagnostics = function() return true;
				}
				return false;
			})) {
				hasEmitDiagnostics = true;
			}
			if (hasIncludeProcessingDiagnostics == null) {
				hasIncludeProcessingDiagnostics = function() return false;
			}
		} else {
			hasEmitDiagnostics = this.snapshot.hasEmitDiagnostics;
			hasIncludeProcessingDiagnostics = function():Bool {
				return Slices.ContainsFunc(program.GetSourceFiles(), function(file:SourceFile):Bool {
					return Core.len(this.program.GetIncludeProcessorDiagnostics(file)) > 0;
				});
			};
		}

		if (hasEmitDiagnostics) {
			// Record this for only non incremental build info
			this.snapshot.hasErrors = Core.IfElse(this.snapshot.options.IsIncremental(), TSFalse, TSTrue);
			// Dont need to encode semantic errors state since the emit diagnostics are encoded
			this.snapshot.hasSemanticErrors = false;
			return;
		}

		if (hasIncludeProcessingDiagnostics()
			|| Core.len(program.GetConfigFileParsingDiagnostics()) > 0
			|| Core.len(program.GetSyntacticDiagnostics(ctx, null)) > 0
			|| Core.len(program.GetProgramDiagnostics()) > 0
			|| Core.len(program.GetGlobalDiagnostics(ctx)) > 0) {
			this.snapshot.hasErrors = TSTrue;
			// Dont need to encode semantic errors state since the syntax and program diagnostics are encoded as present
			this.snapshot.hasSemanticErrors = false;
			return;
		}

		this.snapshot.hasErrors = TSFalse;
		// Check semantic and emit diagnostics first as we dont need to ask program about it
		if (Slices.ContainsFunc(this.program.GetSourceFiles(), function(file:SourceFile):Bool {
			final r = this.snapshot.semanticDiagnosticsPerFile.Load(file.Path());
			if (!r.ok) {
				// Missing semantic diagnostics in cache will be encoded in incremental buildInfo
				return this.snapshot.options.IsIncremental();
			}
			final semanticDiagnostics = r.value;
			if (Core.len(semanticDiagnostics.diagnostics) > 0 || Core.len(semanticDiagnostics.buildInfoDiagnostics) > 0) {
				// cached semantic diagnostics will be encoded in buildInfo
				return true;
			}
			return false;
		})) {
			// Because semantic diagnostics are recorded in buildInfo, we dont need to encode hasErrors in incremental buildInfo
			// But encode as errors in non incremental buildInfo
			this.snapshot.hasSemanticErrors = !this.snapshot.options.IsIncremental();
		}
	}

	function ensurePackageJsonsForState():Void {
		final config = Tspath.GetDirectoryPath(this.program.CommandLine().ConfigName());
		if (config != "") {
			this.program.PackageJsonCacheEntries(function(key:Path, value:InfoCacheEntry):Bool {
				if (value == null) {
					return true;
				}
				var packageJson = Tspath.CombinePaths(value.PackageDirectory, "package.json");
				if (value.Exists() || value.DirectoryExists) {
					packageJson = this.program.Host().FS().Realpath(packageJson);
				}
				if (value.Exists()) {
					if (this.snapshot.packageJsons == null)
						this.snapshot.packageJsons = [];
					this.snapshot.packageJsons.push(packageJson);
				} else if (packageJson.indexOf("/node_modules/") >= 0) {
					if (this.snapshot.missingPackageJsons == null)
						this.snapshot.missingPackageJsons = [];
					this.snapshot.missingPackageJsons.push(packageJson);
				}
				return true;
			});
		}
		this.snapshot.packageJsons = Incremental.normalizePackageJsons(this.snapshot.packageJsons);
		this.snapshot.missingPackageJsons = Incremental.normalizePackageJsons(this.snapshot.missingPackageJsons);
	}

	public function PackageJsonLookupPaths():Array<std.String> {
		final config = Tspath.GetDirectoryPath(this.program.CommandLine().ConfigName());
		if (config == "") {
			return null;
		}

		var packageJsons:Array<std.String> = null;
		this.program.PackageJsonCacheEntries(function(key:Path, value:InfoCacheEntry):Bool {
			if (value == null) {
				return true;
			}
			var packageJson = Tspath.CombinePaths(value.PackageDirectory, "package.json");
			if (value.Exists() || value.DirectoryExists) {
				packageJson = this.program.Host().FS().Realpath(packageJson);
			}
			if (packageJsons == null)
				packageJsons = [];
			packageJsons.push(packageJson);
			return true;
		});
		Slices.SortStrings(packageJsons);
		return Core.Deduplicate(packageJsons);
	}
}

@:allow(ts.execute.incremental)
class TestingData {
	public var SemanticDiagnosticsPerFile:SyncMap<Path, DiagnosticsOrBuildInfoDiagnosticsWithFileName> = null;
	public var OldProgramSemanticDiagnosticsPerFile:SyncMap<Path, DiagnosticsOrBuildInfoDiagnosticsWithFileName> = null;
	public var UpdatedSignatureKinds:StringMap<SignatureUpdateKind> = null;

	public function new() {}
}
