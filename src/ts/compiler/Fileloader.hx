package ts.compiler;

import ts.diagnostics.Diagnostics.Message;

// Port of fileloader.go (types and methods; the package-level funcs are in Compiler.hx).

@:allow(ts.compiler)
class LibResolution {
	var libraryName:std.String = "";
	var resolution:ResolvedModule = null;
	var trace:Array<DiagAndArgs> = null;

	public function new(libraryName:std.String = "", resolution:ResolvedModule = null, trace:Array<DiagAndArgs> = null) {
		this.libraryName = libraryName;
		this.resolution = resolution;
		this.trace = trace;
	}
}

@:allow(ts.compiler)
class LibFile {
	public var Name:std.String = "";
	var path:std.String = "";
	public var Replaced:Bool = false;

	public function new(Name:std.String = "", path:std.String = "", Replaced:Bool = false) {
		this.Name = Name;
		this.path = path;
		this.Replaced = Replaced;
	}
}

@:allow(ts.compiler)
class SourceFileFromReferenceDiagnostic {
	var message:Message = null;
	var args:Array<Any> = null;

	public function new(message:Message = null, args:Array<Any> = null) {
		this.message = message;
		this.args = args;
	}
}

@:allow(ts.compiler)
class FileLoader {
	var opts:ProgramOptions = null;
	var resolver:Resolver = null;
	var defaultLibraryPath:std.String = "";
	var comparePathsOptions:ComparePathsOptions = new ComparePathsOptions();
	var supportedExtensions:Array<Array<std.String>> = null;
	var supportedExtensionsWithJsonIfResolveJsonModule:Array<Array<std.String>> = null;
	var contentMapperExtensions:Array<std.String> = null;

	var filesParser:FilesParser = null;
	var rootTasks:Array<ParseTask> = null;

	var totalFileCount:Int = 0; // PORT: atomic.Int32 → Int
	var libFileCount:Int = 0; // PORT: atomic.Int32 → Int

	var factory:NodeFactory = new NodeFactory(); // PORT: factoryMu dropped (single-threaded)
	#if tshx_parallel
	// PORT: hxmc (-D tshx-parallel) — factoryMu, the counters' atomics, the lib file SyncMaps
	final factoryMutex = new sys.thread.Mutex();
	final countMutex = new sys.thread.Mutex();
	final libMutex = new sys.thread.Mutex();
	#end

	var projectReferenceFileMapper:ProjectReferenceFileMapper = null;
	var dtsDirectories:Set<Path> = new Set<Path>();

	var pathForLibFileCache:StringMap<LibFile> = new StringMap(); // PORT: SyncMap[string, *LibFile] → StringMap
	var pathForLibFileResolutions:StringMap<LibResolution> = new StringMap(); // PORT: SyncMap[tspath.Path, *libResolution] → StringMap

	// contentMapperMu guards the content-mapper bookkeeping below. PORT: the in-process content mapper host is
	// not thread-safe either, so with -D tshx-parallel the whole content-mapped parse runs under the lock.
	#if tshx_parallel
	final contentMapperMutex = new sys.thread.Mutex();
	#end
	var contentMapperFailures:go.IdentityMap<Mapper, Int> = null;
	var contentMapperInitFailed:go.IdentityMap<Mapper, Bool> = new go.IdentityMap();
	var contentMapperDiagnostics:Array<Diagnostic> = null;

	public function new() {}

	// PORT: perf — toPath by file name, memoized: every parse task (FilesParser.start) and import resolution
	// normalizes long node_modules paths again (main's typed paths, #64159, avoid most of it); the current
	// directory and case sensitivity are fixed for a loader. Parse tasks run on threads (a lock).
	final toPathCache = new StringMap<Path>();
	#if tshx_parallel
	final toPathMutex = new sys.thread.Mutex();
	#end

	function toPath(file:std.String):Path {
		#if tshx_parallel
		toPathMutex.acquire();
		#end
		var path = toPathCache.get(file);
		#if tshx_parallel
		toPathMutex.release();
		#end
		if (path == null) {
			path = Tspath.ToPath(file, this.opts.Host.GetCurrentDirectory(), this.opts.Host.FS().UseCaseSensitiveFileNames());
			#if tshx_parallel
			toPathMutex.acquire();
			#end
			toPathCache.set(file, path);
			#if tshx_parallel
			toPathMutex.release();
			#end
		}
		return path;
	}

	function addRootTask(fileName:std.String, libFile:LibFile, includeReason:FileIncludeReason):Void {
		final absPath = Tspath.GetNormalizedAbsolutePath(fileName, this.opts.Host.GetCurrentDirectory());
		if (this.opts.Config.CompilerOptions().AllowNonTsExtensions.IsTrue() || Tspath.HasExtension(absPath)) {
			final t = new ParseTask();
			t.normalizedFilePath = absPath;
			t.libFile = libFile;
			t.includeReason = includeReason;
			this.rootTasks.push(t);
		}
	}

	function addRootFileTask(fileName:std.String, libFile:LibFile, includeReason:FileIncludeReason):Void {
		final currDir = this.opts.Host.GetCurrentDirectory();
		final absPath = Tspath.GetNormalizedAbsolutePath(fileName, currDir);
		var containingFile = currDir;
		if (this.opts.Config.ConfigFile != null) {
			containingFile = Tspath.GetNormalizedAbsolutePath(this.opts.Config.ConfigFile.SourceFile.FileName(), currDir);
		}
		final r = this.getSourceFileFromReference(absPath, fileName, containingFile, includeReason);
		final resolvedFile = r.a, diagnostic = r.b;
		final rootTask = new ParseTask();
		rootTask.normalizedFilePath = resolvedFile;
		rootTask.libFile = libFile;
		rootTask.includeReason = includeReason;
		if (diagnostic != null) {
			rootTask.normalizedFilePath = absPath;
			rootTask.failedLookup = true;
			rootTask.processingDiagnostics = [
				new ProcessingDiagnostic(processingDiagnosticKindExplainingFileInclude,
					new IncludeExplainingDiagnostic("", includeReason, diagnostic.message, diagnostic.args))
			];
		}
		this.rootTasks.push(rootTask);
	}

	function addAutomaticTypeDirectiveTasks():Void {
		var containingDirectory:std.String;
		final compilerOptions = this.opts.Config.CompilerOptions();
		if (compilerOptions.ConfigFilePath != "") {
			containingDirectory = Tspath.GetDirectoryPath(compilerOptions.ConfigFilePath);
		} else {
			containingDirectory = this.opts.Host.GetCurrentDirectory();
		}
		final containingFileName = Tspath.CombinePaths(containingDirectory, Module.InferredTypesContainingFile);
		final t = new ParseTask();
		t.normalizedFilePath = containingFileName;
		t.isForAutomaticTypeDirective = true;
		this.rootTasks.push(t);
	}

	// PORT: 4 results → ResolveAutomaticTypeDirectivesResult
	function resolveAutomaticTypeDirectives(containingFileName:std.String):ResolveAutomaticTypeDirectivesResult {
		var toParse:Array<ResolvedRef> = null;
		var typeResolutionsInFile:ModeAwareCache<ResolvedTypeReferenceDirective> = null;
		var typeResolutionsTrace:Array<DiagAndArgs> = null;
		var pDiagnostics:Array<ProcessingDiagnostic> = null;
		final automaticTypeDirectiveNames = Module.GetAutomaticTypeDirectiveNames(this.opts.Config.CompilerOptions(), this.opts.Host);
		if (Core.len(automaticTypeDirectiveNames) != 0) {
			toParse = [];
			typeResolutionsInFile = new ModeAwareCache<ResolvedTypeReferenceDirective>();
			for (name in automaticTypeDirectiveNames) {
				// Under node16/nodenext module resolution, load `types`/ata include names as cjs resolution results by passing an `undefined` mode.
				// Under bundler module resolution, this also triggers the "import" condition to be used.
				final resolutionMode = Core.ResolutionModeNone;
				final rr = this.resolver.ResolveTypeReferenceDirective(name, containingFileName, resolutionMode, null);
				final resolved = rr.a, trace = rr.b;
				var traceDone:() -> Void = null;
				if (this.opts.Tracing != null) {
					final args = new StringMap<Any>();
					args.set("directive", name);
					args.set("hasResolved", resolved.IsResolved());
					args.set("refKind", (fileIncludeKindAutomaticTypeDirectiveFile : Int));
					traceDone = this.opts.Tracing.Push(PhaseProgram, "processTypeReferenceDirective", args, false);
				}
				typeResolutionsInFile.set(new ModeAwareCacheKey(name, resolutionMode).Key(), resolved);
				if (trace != null) {
					if (typeResolutionsTrace == null)
						typeResolutionsTrace = [];
					for (x in trace)
						typeResolutionsTrace.push(x);
				}
				if (resolved.IsResolved()) {
					final ref = new ResolvedRef();
					ref.fileName = resolved.ResolvedFileName;
					ref.increaseDepth = resolved.IsExternalLibraryImport;
					ref.elideOnDepth = false;
					ref.includeReason = new FileIncludeReason(fileIncludeKindAutomaticTypeDirectiveFile, new AutomaticTypeDirectiveFileData(name, resolved.PackageId));
					ref.packageId = resolved.PackageId;
					toParse.push(ref);
				} else {
					if (pDiagnostics == null)
						pDiagnostics = [];
					pDiagnostics.push(new ProcessingDiagnostic(processingDiagnosticKindExplainingFileInclude,
						new IncludeExplainingDiagnostic("",
							new FileIncludeReason(fileIncludeKindAutomaticTypeDirectiveFile, new AutomaticTypeDirectiveFileData(name)),
							Diagnostics.Cannot_find_type_definition_file_for_0, [name])));
				}
				if (traceDone != null) {
					traceDone();
				}
			}
		}
		return new ResolveAutomaticTypeDirectivesResult(toParse, typeResolutionsInFile, typeResolutionsTrace, pDiagnostics);
	}

	function addProjectReferenceTasks(singleThreaded:Bool):Void {
		this.projectReferenceFileMapper = new ProjectReferenceFileMapper();
		this.projectReferenceFileMapper.opts = this.opts;
		this.projectReferenceFileMapper.host = this.opts.Host;
		final projectReferences = this.opts.Config.ResolvedProjectReferencePaths();
		if (Core.len(projectReferences) == 0) {
			return;
		}

		final parser = new ProjectReferenceParser();
		parser.loader = this;
		parser.wg = Core.NewWorkGroup(singleThreaded);
		final rootTasks = Compiler.createProjectReferenceParseTasks(projectReferences);
		parser.parse(rootTasks);
	}

	function sortLibs(libFiles:Array<SourceFile>):Void {
		Slices.SortStableFunc(libFiles, function(f1:SourceFile, f2:SourceFile):Int {
			return go.Cmp.Compare(this.getDefaultLibFilePriority(f1), this.getDefaultLibFilePriority(f2));
		});
	}

	function getDefaultLibFilePriority(a:SourceFile):Int {
		// defaultLibraryPath and a.FileName() are absolute and normalized; a prefix check should suffice.
		final defaultLibraryPath = Tspath.RemoveTrailingDirectorySeparator(this.defaultLibraryPath);
		final aFileName = a.FileName();

		if (StringTools.startsWith(aFileName, defaultLibraryPath)
			&& aFileName.length > defaultLibraryPath.length
			&& StringTools.fastCodeAt(aFileName, defaultLibraryPath.length) == Tspath.DirectorySeparator) {
			// avoid tspath.GetBaseFileName; we know these paths are already absolute and normalized.
			final basename = aFileName.substring(aFileName.lastIndexOf("/") + 1);
			if (basename == "lib.d.ts" || basename == "lib.es6.d.ts") {
				return 0;
			}
			final name = Strings.TrimSuffix(Strings.TrimPrefix(basename, "lib."), ".d.ts");
			final index = Tsoptions.Libs.indexOf(name);
			if (index != -1) {
				return index + 1;
			}
		}
		return Tsoptions.Libs.length + 2;
	}

	function loadSourceFileMetaData(fileName:std.String):SourceFileMetaData {
		final packageJsonScope = this.resolver.GetPackageScopeForPath(Tspath.GetDirectoryPath(fileName));
		final moduleResolutionKind = this.opts.Config.CompilerOptions().GetModuleResolutionKind();

		var packageJsonType = "", packageJsonDirectory = "";
		if (packageJsonScope.Exists()) {
			packageJsonDirectory = packageJsonScope.PackageDirectory;
			final v = packageJsonScope.Contents.Type.GetValue();
			final value = v.value, ok = v.ok;
			if (ok) {
				if (!Tspath.FileExtensionIsOneOf(fileName, [Tspath.ExtensionMts, Tspath.ExtensionCts, Tspath.ExtensionMjs, Tspath.ExtensionCjs])
					&& (ModuleResolutionKindNode16 : Int) <= (moduleResolutionKind : Int)
					&& (moduleResolutionKind : Int) <= (ModuleResolutionKindNodeNext : Int)
					|| fileName.indexOf("/node_modules/") >= 0) {
					packageJsonType = value;
				}
			}
		}

		final impliedNodeFormat = Ast.GetImpliedNodeFormatForFile(fileName, packageJsonType);
		final m = new SourceFileMetaData();
		m.PackageJsonType = packageJsonType;
		m.PackageJsonDirectory = packageJsonDirectory;
		m.ImpliedNodeFormat = impliedNodeFormat;
		return m;
	}

	function parseSourceFile(t:ParseTask):SourceFile {
		var done:() -> Void = null;
		if (this.opts.Tracing != null) {
			final args = new StringMap<Any>();
			args.set("path", t.normalizedFilePath);
			done = this.opts.Tracing.Push(PhaseParse, "createSourceFile", args, true);
		}
		final path = this.toPath(t.normalizedFilePath);
		final options = this.projectReferenceFileMapper.getCompilerOptionsForFile(t);
		final opts = new SourceFileParseOptions();
		opts.FileName = t.normalizedFilePath;
		opts.Path = path;
		opts.ExternalModuleIndicatorOptions = Ast.GetExternalModuleIndicatorOptions(t.normalizedFilePath, options, t.metadata);
		final sourceFile = try {
			if (Tspath.FileExtensionIsOneOf(t.normalizedFilePath, this.contentMapperExtensions)) {
				#if tshx_parallel
				this.contentMapperMutex.acquire();
				final f = try this.parseContentMappedFile(opts) catch (e:Dynamic) {
					this.contentMapperMutex.release();
					throw e;
				}
				this.contentMapperMutex.release();
				f;
				#else
				this.parseContentMappedFile(opts);
				#end
			} else {
				this.opts.Host.GetSourceFile(opts);
			}
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
		return sourceFile;
	}

	// parseContentMappedFile produces a content-mapped virtual source file via the host's content
	// mapper, preserving the original file name and retaining the untransformed text on the
	// source file. Content mapper extensions only reach the parser when content mappers are configured.
	//
	// When initialization fails, one program diagnostic is reported and the mapper is not attempted for
	// subsequent files. Other failures produce per-file diagnostics and count toward a failure budget; after
	// maxContentMapperFailures, one program diagnostic reports that the mapper was disabled and subsequent
	// files are silently substituted with empty files. It returns nil only if the file cannot be read.
	function parseContentMappedFile(opts:SourceFileParseOptions):SourceFile {
		final mapper = this.opts.Config.GetContentMapperForFileName(opts.FileName);
		final label = mapper.DiagnosticName();
		final transformIdentity = this.getContentMapperTransformIdentity(mapper);
		if (this.contentMapperUnavailable(mapper)) {
			// The mapper failed initialization or exceeded its failure budget; add the file empty without re-reporting.
			return this.emptyContentMappedFile(opts, mapper.Identity(), transformIdentity);
		}
		final r = this.opts.Host.GetContentMappedSourceFiles(opts, mapper);
		final err = r.err;
		if (err != null) {
			final sourceFile = this.emptyContentMappedFile(opts, mapper.Identity(), transformIdentity);
			final transformError = Std.downcast(err, ts.contentmapper.Host.TransformError);
			if (transformError != null && transformError.Kind == TransformErrorKindInitialize) {
				this.recordContentMapperInitializationFailure(mapper, label, transformError);
				return sourceFile;
			}
			if (this.recordContentMapperFailure(mapper, label)) {
				var diagnostic:Diagnostic;
				final problem = Errors.AsType(err, ts.spanmap.Spanmap.MappingError);
				if (problem != null) {
					diagnostic = Compiler.contentMapperMappingDiagnostic(sourceFile, label, problem);
				} else {
					diagnostic = Compiler.contentMapperTransformDiagnostic(sourceFile, label, err);
				}
				final diags = sourceFile.Diagnostics() == null ? [] : sourceFile.Diagnostics().copy();
				diags.push(diagnostic);
				sourceFile.SetDiagnostics(diags);
			}
			return sourceFile;
		}
		return r.value.Canonical;
	}

	function getContentMapperTransformIdentity(mapper:Mapper):std.String {
		final project = this.opts.Host.ContentMapperProject();
		if (project != null) {
			final identity = project.Identity(mapper);
			if (identity.err == null) {
				return identity.value;
			}
		}
		return mapper.TransformIdentity(this.opts.Config.CompilerOptions());
	}

	// emptyContentMappedFile produces an empty TypeScript source file for a content-mapped file whose
	// transform could not be used, retaining the original content for diagnostics.
	function emptyContentMappedFile(opts:SourceFileParseOptions, mapperIdentity:std.String, transformIdentity:std.String):SourceFile {
		final content = this.opts.Host.FS().ReadFile(opts.FileName).value;
		final sourceFile = Parser.ParseSourceFile(opts, "", ScriptKindTS);
		final info = new ContentMapperSourceFileInfo();
		info.ContentMapper = mapperIdentity;
		info.TransformIdentity = transformIdentity;
		info.ParseOptions = opts;
		info.VirtualFileName = opts.FileName + Tspath.ExtensionTs;
		info.OriginalText = content == null ? "" : content;
		sourceFile.SetContentMapperInfo(info);
		return sourceFile;
	}

	// contentMapperUnavailable reports whether mapper failed initialization or exceeded its failure budget.
	function contentMapperUnavailable(mapper:Mapper):Bool {
		if (mapper == null) {
			return false;
		}
		final failures = this.contentMapperFailures == null ? null : this.contentMapperFailures.get(mapper);
		return this.contentMapperInitFailed.exists(mapper) || (failures != null && failures >= Compiler.maxContentMapperFailures);
	}

	function recordContentMapperInitializationFailure(mapper:Mapper, label:std.String, err:go.Errors.Error):Void {
		if (this.contentMapperInitFailed.exists(mapper)) {
			return;
		}
		this.contentMapperInitFailed.set(mapper, true);
		if (this.contentMapperDiagnostics == null)
			this.contentMapperDiagnostics = [];
		this.contentMapperDiagnostics.push(Compiler.ContentMapperInitializationDiagnostic(label, err));
	}

	// recordContentMapperFailure counts a transform failure for mapper. It returns whether the failure
	// should be reported for this file (false once the mapper is already disabled).
	function recordContentMapperFailure(mapper:Mapper, label:std.String):Bool {
		if (this.contentMapperFailures == null) {
			this.contentMapperFailures = new go.IdentityMap();
		}
		var failures = this.contentMapperFailures.get(mapper);
		if (failures == null)
			failures = 0;
		if (failures >= Compiler.maxContentMapperFailures) {
			return false;
		}
		failures++;
		this.contentMapperFailures.set(mapper, failures);
		if (failures >= Compiler.maxContentMapperFailures) {
			if (this.contentMapperDiagnostics == null)
				this.contentMapperDiagnostics = [];
			this.contentMapperDiagnostics.push(Ast.NewCompilerDiagnostic(Diagnostics.The_content_mapper_0_failed_1_times_and_will_not_be_used, label,
				Compiler.maxContentMapperFailures));
		}
		return true;
	}

	function isSupportedExtension(canonicalFileName:std.String):Bool {
		for (group in this.supportedExtensionsWithJsonIfResolveJsonModule) {
			if (Tspath.FileExtensionIsOneOf(canonicalFileName, group)) {
				return true;
			}
		}
		return false;
	}

	// PORT: (string, *sourceFileFromReferenceDiagnostic) → Pair
	function getSourceFileFromReference(fileName:std.String, referenceText:std.String, containingFile:std.String,
			includeReason:FileIncludeReason):Pair<std.String, SourceFileFromReferenceDiagnostic> {
		final options = this.opts.Config.CompilerOptions();
		final allowNonTsExtensions = options.AllowNonTsExtensions.IsTrue();
		final diagnosticFileName = Tspath.NormalizeSlashes(referenceText);

		if (ts.nativepath.Nativepath.IsNetworkPath(fileName)) {
			return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.Network_path_0_is_not_supported, [diagnosticFileName]));
		}

		if (Tspath.HasExtension(fileName)) {
			final canonicalFileName = Tspath.GetCanonicalFileName(fileName, this.opts.Host.FS().UseCaseSensitiveFileNames());
			if (!allowNonTsExtensions && !this.isSupportedExtension(canonicalFileName)) {
				if (Tspath.HasJSFileExtension(canonicalFileName)) {
					return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.File_0_is_a_JavaScript_file_Did_you_mean_to_enable_the_allowJs_option, [diagnosticFileName]));
				}
				return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.File_0_has_an_unsupported_extension_The_only_supported_extensions_are_1, [
					diagnosticFileName,
					"'" + Core.Flatten(this.supportedExtensions).join("', '") + "'"
				]));
			}

			if (!this.opts.Host.FS().FileExists(fileName)) {
				return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.File_0_not_found, [diagnosticFileName]));
			}

			if (includeReason.isReferencedFile()
				&& Tspath.GetCanonicalFileName(containingFile, this.opts.Host.FS().UseCaseSensitiveFileNames()) == canonicalFileName) {
				return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.A_file_cannot_have_a_reference_to_itself));
			}
			return new Pair(fileName, null);
		}

		if (allowNonTsExtensions && this.opts.Host.FS().FileExists(fileName)) {
			return new Pair(fileName, null);
		}

		if (allowNonTsExtensions) {
			return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.File_0_not_found, [diagnosticFileName]));
		}

		for (ext in this.supportedExtensions[0]) {
			final candidate = fileName + ext;
			if (this.opts.Host.FS().FileExists(candidate)) {
				return new Pair(candidate, null);
			}
		}

		return new Pair("", new SourceFileFromReferenceDiagnostic(Diagnostics.Could_not_resolve_the_path_0_with_the_extensions_Colon_1, [
			diagnosticFileName,
			"'" + Core.Flatten(this.supportedExtensions).join("', '") + "'"
		]));
	}

	// PORT: (*resolvedRef, *processingDiagnostic) → Pair
	function resolveTripleslashPathReference(moduleName:std.String, containingFile:std.String, index:Int):Pair<ResolvedRef, ProcessingDiagnostic> {
		final basePath = Tspath.GetDirectoryPath(containingFile);
		var referencedFileName = moduleName;

		if (!Tspath.IsRootedDiskPath(moduleName)) {
			referencedFileName = Tspath.CombinePaths(basePath, moduleName);
		}
		final normalizedFileName = Tspath.NormalizePath(referencedFileName);
		final includeReason = new FileIncludeReason(fileIncludeKindReferenceFile, new ReferencedFileData(this.toPath(containingFile), index));

		final r = this.getSourceFileFromReference(normalizedFileName, moduleName, containingFile, includeReason);
		final resolvedFileName = r.a, diagnostic = r.b;
		if (diagnostic != null) {
			return new Pair(null, new ProcessingDiagnostic(processingDiagnosticKindExplainingFileInclude,
				new IncludeExplainingDiagnostic("", includeReason, diagnostic.message, diagnostic.args)));
		}

		final ref = new ResolvedRef();
		ref.fileName = resolvedFileName;
		ref.includeReason = includeReason;
		return new Pair(ref, null);
	}

	function resolveTypeReferenceDirectives(t:ParseTask):Void {
		final file = t.file;
		if (Core.len(file.TypeReferenceDirectives) == 0) {
			return;
		}
		var done:() -> Void = null;
		if (this.opts.Tracing != null) {
			final args = new StringMap<Any>();
			args.set("containingFileName", file.FileName());
			done = this.opts.Tracing.Push(PhaseProgram, "resolveTypeReferenceDirectiveNamesWorker", args, false);
		}
		try {
			final meta = t.metadata;

			final typeResolutionsInFile = new ModeAwareCache<ResolvedTypeReferenceDirective>();
			var typeResolutionsTrace:Array<DiagAndArgs> = null;
			for (index in 0...file.TypeReferenceDirectives.length) {
				final ref = file.TypeReferenceDirectives[index];
				final rd = this.projectReferenceFileMapper.getRedirectForResolution(ts.modulespecifiers.Types.SourceFileAdapter.Of(file));
				final redirect = rd.a, fileName = rd.b;
				final resolutionMode = Compiler.getModeForTypeReferenceDirectiveInFile(ref, file, meta,
					Module.GetCompilerOptionsWithRedirect(this.opts.Config.CompilerOptions(), redirect));
				final rr = this.resolver.ResolveTypeReferenceDirective(ref.FileName, fileName, resolutionMode, redirect);
				final resolved = rr.a, trace = rr.b;
				var traceDone:() -> Void = null;
				if (this.opts.Tracing != null) {
					final args = new StringMap<Any>();
					args.set("directive", ref.FileName);
					args.set("hasResolved", resolved.IsResolved());
					args.set("refKind", (fileIncludeKindTypeReferenceDirective : Int));
					args.set("refPath", (t.path : std.String));
					traceDone = this.opts.Tracing.Push(PhaseProgram, "processTypeReferenceDirective", args, false);
				}
				typeResolutionsInFile.set(new ModeAwareCacheKey(ref.FileName, resolutionMode).Key(), resolved);
				final includeReason = new FileIncludeReason(fileIncludeKindTypeReferenceDirective, new ReferencedFileData(t.path, index));
				if (trace != null) {
					if (typeResolutionsTrace == null)
						typeResolutionsTrace = [];
					for (x in trace)
						typeResolutionsTrace.push(x);
				}

				if (resolved.IsResolved()) {
					final r = new ResolvedRef();
					r.fileName = resolved.ResolvedFileName;
					r.increaseDepth = resolved.IsExternalLibraryImport;
					r.elideOnDepth = false;
					r.includeReason = includeReason;
					r.packageId = resolved.PackageId;
					t.addSubTask(r, null);
				} else {
					if (t.processingDiagnostics == null)
						t.processingDiagnostics = [];
					t.processingDiagnostics.push(new ProcessingDiagnostic(processingDiagnosticKindUnknownReference, includeReason));
				}
				if (traceDone != null) {
					traceDone();
				}
			}

			t.typeResolutionsInFile = typeResolutionsInFile;
			t.typeResolutionsTrace = typeResolutionsTrace;
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	function resolveImportsAndModuleAugmentations(t:ParseTask):Void {
		var done:() -> Void = null;
		if (this.opts.Tracing != null) {
			final args = new StringMap<Any>();
			args.set("containingFileName", t.file.FileName());
			done = this.opts.Tracing.Push(PhaseProgram, "resolveModuleNamesWorker", args, false);
		}
		try {
			resolveImportsAndModuleAugmentationsWorker(t);
		} catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
	}

	// PORT: body of resolveImportsAndModuleAugmentations (split off for the tracing defer).
	function resolveImportsAndModuleAugmentationsWorker(t:ParseTask):Void {
		final file = t.file;
		final meta = t.metadata;

		final moduleNames:Array<Node> = [];

		final isJavaScriptFile = Ast.IsSourceFileJS(file);
		final isExternalModuleFile = Ast.IsExternalModule(file);

		final rd = this.projectReferenceFileMapper.getRedirectForResolution(ts.modulespecifiers.Types.SourceFileAdapter.Of(file));
		final redirect = rd.a, fileName = rd.b;
		final optionsForFile = Module.GetCompilerOptionsWithRedirect(this.opts.Config.CompilerOptions(), redirect);
		if (isJavaScriptFile || (!file.IsDeclarationFile && (optionsForFile.GetIsolatedModules() || isExternalModuleFile))) {
			if (optionsForFile.ImportHelpers.IsTrue()) {
				final specifier = this.createSyntheticImport(Compiler.externalHelpersModuleNameText, file);
				moduleNames.push(specifier);
				t.importHelpersImportSpecifier = specifier;
			}
		}

		if (isJavaScriptFile || file.ScriptKind == ScriptKindTSX) {
			final jsxImport = Ast.GetJSXRuntimeImport(Ast.GetJSXImplicitImportBase(optionsForFile, file), optionsForFile);
			if (jsxImport != "") {
				final specifier = this.createSyntheticImport(jsxImport, file);
				moduleNames.push(specifier);
				final s = new JsxRuntimeImportSpecifier();
				s.moduleReference = jsxImport;
				s.specifier = specifier;
				t.jsxRuntimeImportSpecifier = s;
			}
		}

		final importsStart = moduleNames.length;

		if (file.Imports() != null) {
			for (imp in file.Imports())
				moduleNames.push(imp);
		}
		if (file.ModuleAugmentations != null) {
			for (imp in file.ModuleAugmentations) {
				if (imp.Kind == KindStringLiteral) {
					moduleNames.push(imp);
				}
				// Do nothing if it's an Identifier; we don't need to do module resolution for `declare global`.
			}
		}

		if (moduleNames.length != 0) {
			final resolutionsInFile = new ModeAwareCache<ResolvedModule>();
			var resolutionsTrace:Array<DiagAndArgs> = null;

			for (index in 0...moduleNames.length) {
				final entry = moduleNames[index];
				final moduleName = entry.Text();
				if (moduleName == "" || Ast.IsSourcePhaseImport(entry.Parent)) {
					continue;
				}

				final mode = Compiler.getModeForUsageLocation(file.FileName(), meta, entry, optionsForFile);
				// We know moduleName resolves to an ambient module provided that moduleName:
				// - is in the list of ambient modules locally declared in the current source file.
				if (Slices.Contains(file.AmbientModuleNames, moduleName)) {
					if (optionsForFile.TraceResolution.IsTrue()) {
						if (resolutionsTrace == null) {
							resolutionsTrace = [];
						}
						resolutionsTrace.push(new DiagAndArgs(Diagnostics.Module_0_was_resolved_as_locally_declared_ambient_module_in_file_1, [moduleName, file.FileName()]));
					}
					resolutionsInFile.set(new ModeAwareCacheKey(moduleName, mode).Key(), new ResolvedModule());
					continue;
				}
				final rr = this.resolver.ResolveModuleName(moduleName, fileName, mode, redirect);
				final resolvedModule = rr.a, trace = rr.b;
				resolutionsInFile.set(new ModeAwareCacheKey(moduleName, mode).Key(), resolvedModule);
				if (trace != null) {
					if (resolutionsTrace == null)
						resolutionsTrace = [];
					for (x in trace)
						resolutionsTrace.push(x);
				}

				if (!resolvedModule.IsResolved()) {
					continue;
				}

				final resolvedFileName = resolvedModule.ResolvedFileName;
				final isFromNodeModulesSearch = resolvedModule.IsExternalLibraryImport;
				// Don't treat redirected files as JS files.
				final isJsFile = !Tspath.FileExtensionIsOneOf(resolvedFileName, Tspath.SupportedTSExtensionsWithJsonFlat)
					&& this.projectReferenceFileMapper.getRedirectParsedCommandLineForResolution(Ast.NewHasFileName(resolvedFileName,
						this.toPath(resolvedFileName))) == null;
				final isJsFileFromNodeModules = isFromNodeModulesSearch && isJsFile && resolvedFileName.indexOf("/node_modules/") >= 0;

				// add file to program only if:
				// - resolution was successful
				// - noResolve is falsy
				// - module name comes from the list of imports
				// - it's not a top level JavaScript module that exceeded the search max

				final importIndex = index - importsStart;

				final shouldAddFile = moduleName != ""
					&& Module.GetResolutionDiagnostic(optionsForFile, resolvedModule, file) == null
					&& !optionsForFile.NoResolve.IsTrue()
					&& !(isJsFile && !optionsForFile.GetAllowJS())
					&& (importIndex < 0
						|| (importIndex < Core.len(file.Imports())
							&& (Ast.IsInJSFile(file.Imports()[importIndex]) || (file.Imports()[importIndex].Flags & NodeFlagsJSDoc) == 0)));

				if (shouldAddFile) {
					final r = new ResolvedRef();
					r.fileName = resolvedFileName;
					r.increaseDepth = resolvedModule.IsExternalLibraryImport;
					r.elideOnDepth = isJsFileFromNodeModules;
					r.includeReason = new FileIncludeReason(fileIncludeKindImport,
						new ReferencedFileData(t.path, importIndex, Core.IfElse(importIndex < 0, entry, null)));
					r.packageId = resolvedModule.PackageId;
					t.addSubTask(r, null);
				}
			}

			t.resolutionsInFile = resolutionsInFile;
			t.resolutionsTrace = resolutionsTrace;
		}
	}

	function createSyntheticImport(text:std.String, file:SourceFile):Node {
		#if tshx_parallel
		factoryMutex.acquire();
		final r = createSyntheticImportLocked(text, file);
		factoryMutex.release();
		return r;
	}

	function createSyntheticImportLocked(text:std.String, file:SourceFile):Node {
		#end
		final externalHelpersModuleReference = this.factory.NewStringLiteral(text, TokenFlagsNone);
		final importDecl = this.factory.NewImportDeclaration(null, null, externalHelpersModuleReference, null);
		externalHelpersModuleReference.Parent = importDecl;
		importDecl.Parent = file.AsNode();
		return externalHelpersModuleReference;
	}

	function pathForLibFile(name:std.String):LibFile {
		#if tshx_parallel
		libMutex.acquire();
		final r = pathForLibFileLocked(name);
		libMutex.release();
		return r;
	}

	function pathForLibFileLocked(name:std.String):LibFile {
		#end
		final cached = this.pathForLibFileCache.get(name);
		if (cached != null) {
			return cached;
		}

		var path = Tspath.CombinePaths(this.defaultLibraryPath, name);
		var replaced = false;
		if (this.opts.Config.CompilerOptions().LibReplacement.IsTrue() && name != "lib.d.ts") {
			final libraryName = Compiler.getLibraryNameFromLibFileName(name);
			final resolveFrom = Compiler.getInferredLibraryNameResolveFrom(this.opts.Config.CompilerOptions(), this.opts.Host.GetCurrentDirectory(), name);
			final rr = this.resolveLibrary(libraryName, resolveFrom);
			final resolution = rr.a, trace = rr.b;
			if (resolution.IsResolved()) {
				path = resolution.ResolvedFileName;
				replaced = true;
			}
			final key:std.String = this.toPath(resolveFrom);
			if (!this.pathForLibFileResolutions.exists(key)) {
				this.pathForLibFileResolutions.set(key, new LibResolution(libraryName, resolution, trace));
			}
		}

		final libPath = new LibFile(name, path, replaced);
		this.pathForLibFileCache.set(name, libPath);
		return libPath;
	}

	function resolveLibrary(libraryName:std.String, resolveFrom:std.String):Pair<ResolvedModule, Null<Array<DiagAndArgs>>> {
		var done:() -> Void = null;
		final tr = this.opts.Tracing;
		if (tr != null) {
			final args = new StringMap<Any>();
			args.set("resolveFrom", resolveFrom);
			done = tr.Push(PhaseProgram, "resolveLibrary", args, false);
		}
		final r = try this.resolver.ResolveModuleName(libraryName, resolveFrom, ModuleKindCommonJS, null) catch (e:Dynamic) {
			if (done != null)
				done();
			throw e;
		}
		if (done != null)
			done();
		return r;
	}
}

// PORT: the 4 results of fileLoader.resolveAutomaticTypeDirectives.
@:allow(ts.compiler)
class ResolveAutomaticTypeDirectivesResult {
	var toParse:Array<ResolvedRef>;
	var typeResolutionsInFile:ModeAwareCache<ResolvedTypeReferenceDirective>;
	var typeResolutionsTrace:Array<DiagAndArgs>;
	var pDiagnostics:Array<ProcessingDiagnostic>;

	public function new(toParse, typeResolutionsInFile, typeResolutionsTrace, pDiagnostics) {
		this.toParse = toParse;
		this.typeResolutionsInFile = typeResolutionsInFile;
		this.typeResolutionsTrace = typeResolutionsTrace;
		this.pDiagnostics = pDiagnostics;
	}
}

@:allow(ts.compiler)
class RedirectsFile implements HasFileName {
	// Index of file at which this redirect file needs to be iterated
	var index:Int = 0;
	var fileName:std.String = "";
	var path:Path = "";
	var target:Path = "";

	public function new() {}

	public function FileName():std.String {
		return this.fileName;
	}

	public function Path():Path {
		return this.path;
	}
}

class DuplicateSourceFile {
	public var ParseOptions:SourceFileParseOptions = new SourceFileParseOptions();
	// PORT: `Hash xxh3.Uint128` omitted: SourceFile.Hash is not ported (see ts.ast.SourceFile).
	public var ScriptKind:ScriptKind = ScriptKindUnknown;

	public function new() {}
}

@:allow(ts.compiler)
class ProcessedFiles {
	var resolver:Resolver = null;
	var files:Array<SourceFile> = null;
	// duplicateSourceFiles tracks parsed files loaded during program construction
	// that were later dropped from the final program, such as losing filename
	// casing variants for the same path or files hidden behind package redirect
	// deduplication. Their parse-cache acquires still need to be balanced when
	// the program is disposed.
	var duplicateSourceFiles:Array<DuplicateSourceFile> = null;
	var filesByPath:StringMap<SourceFile> = null;
	var projectReferenceFileMapper:ProjectReferenceFileMapper = null;
	var missingFiles:Array<std.String> = null;
	var resolvedModules:StringMap<ModeAwareCache<ResolvedModule>> = null;
	var typeResolutionsInFile:StringMap<ModeAwareCache<ResolvedTypeReferenceDirective>> = null;
	var sourceFileMetaDatas:StringMap<SourceFileMetaData> = null;
	var jsxRuntimeImportSpecifiers:StringMap<JsxRuntimeImportSpecifier> = null;
	var importHelpersImportSpecifiers:StringMap<Node> = null;
	var libFiles:StringMap<LibFile> = null;
	// List of present unsupported extensions
	var sourceFilesFoundSearchingNodeModules:Set<Path> = new Set<Path>();
	var includeProcessor:IncludeProcessor = null;
	// if file was included using source file and its output is actually part of program
	// this contains mapping from output to source file
	var outputFileToProjectReferenceSource:StringMap<std.String> = null;
	// Key is a file path. Value is the list of files that redirect to it (same package, different install location)
	var redirectTargetsMap:StringMap<Array<std.String>> = null;
	// filesByPath for redirect files
	var redirectFilesByPath:StringMap<RedirectsFile> = null;
	// Program-level diagnostics reported when a content mapper fails fatally (reported once per mapper).
	var contentMapperDiagnostics:Array<Diagnostic> = null;
	var finishedProcessing:Bool = false;

	public function new() {}

	// PORT: Go value struct; copy before mutating a copy (PORTING.md §3).
	public function copy():ProcessedFiles {
		final r = new ProcessedFiles();
		r.resolver = resolver;
		r.files = files;
		r.duplicateSourceFiles = duplicateSourceFiles;
		r.filesByPath = filesByPath;
		r.projectReferenceFileMapper = projectReferenceFileMapper;
		r.missingFiles = missingFiles;
		r.resolvedModules = resolvedModules;
		r.typeResolutionsInFile = typeResolutionsInFile;
		r.sourceFileMetaDatas = sourceFileMetaDatas;
		r.jsxRuntimeImportSpecifiers = jsxRuntimeImportSpecifiers;
		r.importHelpersImportSpecifiers = importHelpersImportSpecifiers;
		r.libFiles = libFiles;
		r.sourceFilesFoundSearchingNodeModules = sourceFilesFoundSearchingNodeModules;
		r.includeProcessor = includeProcessor;
		r.outputFileToProjectReferenceSource = outputFileToProjectReferenceSource;
		r.redirectTargetsMap = redirectTargetsMap;
		r.redirectFilesByPath = redirectFilesByPath;
		r.finishedProcessing = finishedProcessing;
		return r;
	}
}

@:allow(ts.compiler)
class JsxRuntimeImportSpecifier {
	var moduleReference:std.String = "";
	var specifier:Node = null;

	public function new() {}
}
