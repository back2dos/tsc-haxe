package ts.execute.incremental;

// Port of internal/execute/incremental: package-level funcs of all files, in Go file order, plus
// the types of incremental.go (BuildInfoReader, buildInfoReader) at the end of this module.
@:allow(ts.execute.incremental)
class Incremental {
	// --- incremental.go ---

	public static function NewBuildInfoReader(host:CompilerHost):BuildInfoReader {
		return new BuildInfoReader_(host);
	}

	public static function ReadBuildInfoProgram(config:ParsedCommandLine, reader:BuildInfoReader, host:CompilerHost):Program {
		// Read buildInfo file
		final buildInfo = reader.ReadBuildInfo(config);
		if (buildInfo == null || !buildInfo.IsValidVersion() || !buildInfo.IsIncremental()) {
			return null;
		}

		// Convert to information that can be used to create incremental program
		final incrementalProgram = new Program();
		incrementalProgram.snapshot = buildInfoToSnapshot(buildInfo, config, host);
		return incrementalProgram;
	}

	// PORT: Go `json.Unmarshal([]byte(text), &buildInfo)`; null where Go returns an error.
	public static function UnmarshalBuildInfo(text:std.String):Null<BuildInfo> {
		try {
			return BuildInfo.fromJSONValue(Json.UnmarshalOrdered(text));
		} catch (e:Dynamic) {
			return null;
		}
	}

	// --- host.go ---

	public static function CreateHost(compilerHost:CompilerHost):Host {
		return new Host_(compilerHost);
	}

	public static function GetMTime(host:CompilerHost, fileName:std.String):Time {
		final stat = host.FS().Stat(fileName);
		var mTime = Time.Zero();
		if (stat != null) {
			mTime = stat.ModTime();
		}
		return mTime;
	}

	// --- buildInfo.go ---

	static function newBuildInfoFileInfo(fileInfo:FileInfo):BuildInfoFileInfo {
		final b = new BuildInfoFileInfo();
		if (fileInfo.version == fileInfo.signature) {
			if (!fileInfo.affectsGlobalScope && fileInfo.impliedNodeFormat == Core.ResolutionModeCommonJS) {
				b.signature = fileInfo.signature;
				return b;
			}
		} else if (fileInfo.signature == "") {
			final n = new BuildInfoFileInfoNoSignature();
			n.Version = fileInfo.version;
			n.NoSignature = true;
			n.AffectsGlobalScope = fileInfo.affectsGlobalScope;
			n.ImpliedNodeFormat = fileInfo.impliedNodeFormat;
			b.noSignature = n;
			return b;
		}
		final f = new BuildInfoFileInfoWithSignature();
		f.Version = fileInfo.version;
		f.Signature = Core.IfElse(fileInfo.signature == fileInfo.version, "", fileInfo.signature);
		f.AffectsGlobalScope = fileInfo.affectsGlobalScope;
		f.ImpliedNodeFormat = fileInfo.impliedNodeFormat;
		b.fileInfo = f;
		return b;
	}

	public static function IsBuildInfoFileNameDefaultLibrary(fileName:std.String):Bool {
		return !Tspath.PathIsRelative(fileName) && !Tspath.PathIsAbsolute(fileName);
	}

	// PORT: iter.Seq[string] → Iterator
	static function getNormalizedPaths(paths:Array<std.String>, buildInfoDirectory:std.String):Iterator<std.String> {
		final result:Array<std.String> = [];
		for (path in paths) {
			result.push(Tspath.GetNormalizedAbsolutePath(path, buildInfoDirectory));
		}
		return result.iterator();
	}

	// --- snapshot.go ---

	public static function ComputeHash(text:std.String, hashWithText:Bool):std.String {
		final hashBytes = go.Xxh3.HashString128(text).Bytes();
		var hash = hashBytes.toHex();
		if (hashWithText) {
			hash += "-" + text;
		}
		return hash;
	}

	public static function GetFileEmitKind(options:CompilerOptions):FileEmitKind {
		var result = FileEmitKindJs;
		if (options.SourceMap.IsTrue()) {
			result = result | FileEmitKindJsMap;
		}
		if (options.InlineSourceMap.IsTrue()) {
			result = result | FileEmitKindJsInlineMap;
		}
		if (options.GetEmitDeclarations()) {
			result = result | FileEmitKindDts;
		}
		if (options.DeclarationMap.IsTrue()) {
			result = result | FileEmitKindDtsMap;
		}
		if (options.EmitDeclarationOnly.IsTrue()) {
			result = result & FileEmitKindAllDts;
		}
		return result;
	}

	static function getPendingEmitKindWithOptions(options:CompilerOptions, oldOptions:CompilerOptions):FileEmitKind {
		final oldEmitKind = GetFileEmitKind(oldOptions);
		final newEmitKind = GetFileEmitKind(options);
		return getPendingEmitKind(newEmitKind, oldEmitKind);
	}

	static function getPendingEmitKind(emitKind:FileEmitKind, oldEmitKind:FileEmitKind):FileEmitKind {
		if (oldEmitKind == emitKind) {
			return FileEmitKindNone;
		}
		if (oldEmitKind == 0 || emitKind == 0) {
			return emitKind;
		}
		final diff = oldEmitKind ^ emitKind;
		var result = FileEmitKindNone;
		// If there is diff in Js emit, pending emit is js emit flags
		if ((diff & FileEmitKindAllJs) != 0) {
			result = result | (emitKind & FileEmitKindAllJs);
		}
		// If dts errors pending, add dts errors flag
		if ((diff & FileEmitKindDtsErrors) != 0) {
			result = result | (emitKind & FileEmitKindAllDts);
		}
		// If there is diff in Dts emit, pending emit is dts emit flags
		if ((diff & FileEmitKindAllDtsEmit) != 0) {
			result = result | (emitKind & FileEmitKindAllDtsEmit);
		}
		return result;
	}

	// repopulateDiagnosticChain recomputes a diagnostic chain entry that depends on
	// program state which may have changed between incremental builds.
	static function repopulateDiagnosticChain(b:BuildInfoDiagnosticWithFileName, p:CompilerProgram, file:SourceFile):Diagnostic {
		final info = b.repopulateInfo;
		switch (info.Kind) {
			case RepopulateModeMismatch:
				return repopulateModeMismatchChain(b, p, file);
			case RepopulateModuleNotFound:
				return repopulateModuleNotFoundChain(b, p, file, info);
			default:
				// Fall back to using the stored (possibly stale) data
				return b.toDiagnosticWithoutRepopulate(p, file);
		}
	}

	static function repopulateModeMismatchChain(b:BuildInfoDiagnosticWithFileName, p:CompilerProgram, file:SourceFile):Diagnostic {
		if (file == null) {
			return b.toDiagnosticWithoutRepopulate(p, file);
		}

		final details = Checker.CreateModeMismatchDetails(p, file);

		var nextChain:Array<Diagnostic> = null;
		for (msg in b.messageChain) {
			if (nextChain == null)
				nextChain = [];
			nextChain.push(msg.toDiagnostic(p, file));
		}

		return Ast.NewDiagnosticFromSerialized(file, Core.NewTextRange(b.pos, b.end), details.Message.Code(), details.Message.Category(),
			details.Message.Key(), Diagnostics.StringifyArgs(details.Args), nextChain, null, false, false, false);
	}

	static function repopulateModuleNotFoundChain(b:BuildInfoDiagnosticWithFileName, p:CompilerProgram, file:SourceFile,
			info:RepopulateDiagnosticInfo):Diagnostic {
		if (file == null) {
			return b.toDiagnosticWithoutRepopulate(p, file);
		}

		var packageName = info.PackageName;
		if (packageName == "") {
			packageName = info.ModuleReference;
		}

		final details = Checker.CreateModuleNotFoundChain(p, file, info.ModuleReference, info.Mode, packageName);

		var nextChain:Array<Diagnostic> = null;
		for (msg in b.messageChain) {
			if (nextChain == null)
				nextChain = [];
			nextChain.push(msg.toDiagnostic(p, file));
		}

		return Ast.NewDiagnosticFromSerialized(file, Core.NewTextRange(b.pos, b.end), details.Message.Code(), details.Message.Category(),
			details.Message.Key(), Diagnostics.StringifyArgs(details.Args), nextChain, null, false, false, false);
	}

	static function getTextHandlingSourceMapForSignature(text:std.String, data:WriteFileData):std.String {
		if (data.SourceMapUrlPos != -1) {
			return text.substring(0, data.SourceMapUrlPos);
		}
		return text;
	}

	static function diagnosticToStringBuilder(diagnostic:Diagnostic, file:SourceFile, builder:go.Strings.Builder):Void {
		if (diagnostic == null) {
			return;
		}
		builder.WriteString("\n");
		if (diagnostic.File() != file) {
			builder.WriteString(Tspath.EnsurePathIsNonModuleName(Tspath.GetRelativePathFromDirectory(Tspath.GetDirectoryPath(file.Path()),
				diagnostic.File().Path(), new ComparePathsOptions())));
		}
		if (diagnostic.File() != null) {
			builder.WriteString(Fmt.Sprintf("(%d,%d): ", [diagnostic.Pos(), diagnostic.Len()]));
		}
		builder.WriteString(diagnostic.Category().Name());
		builder.WriteString(Fmt.Sprintf("%d: ", [diagnostic.Code()]));
		builder.WriteString(diagnostic.MessageKey());
		builder.WriteString("\n");
		for (arg in diagnostic.MessageArgs()) {
			builder.WriteString(arg);
			builder.WriteString("\n");
		}
		for (chain in diagnostic.MessageChain()) {
			diagnosticToStringBuilder(chain, file, builder);
		}
		for (info in diagnostic.RelatedInformation()) {
			diagnosticToStringBuilder(info, file, builder);
		}
	}

	// --- program.go ---

	public static function NewProgram(program:CompilerProgram, oldProgram:Program, host:Host, testing:Bool):Program {
		final incrementalProgram = new Program();
		incrementalProgram.snapshot = programToSnapshot(program, oldProgram, testing);
		incrementalProgram.program = program;
		incrementalProgram.host = host;

		if (testing) {
			incrementalProgram.testingData = new TestingData();
			incrementalProgram.testingData.SemanticDiagnosticsPerFile = incrementalProgram.snapshot.semanticDiagnosticsPerFile;
			if (oldProgram != null) {
				incrementalProgram.testingData.OldProgramSemanticDiagnosticsPerFile = oldProgram.snapshot.semanticDiagnosticsPerFile;
			} else {
				incrementalProgram.testingData.OldProgramSemanticDiagnosticsPerFile = new SyncMap<Path, DiagnosticsOrBuildInfoDiagnosticsWithFileName>();
			}
			incrementalProgram.testingData.UpdatedSignatureKinds = new StringMap<SignatureUpdateKind>();
		}
		return incrementalProgram;
	}

	static function normalizePackageJsons(packageJsons:Array<std.String>):Array<std.String> {
		if (packageJsons == null) {
			return [];
		}
		Slices.SortStrings(packageJsons);
		return Core.Deduplicate(packageJsons);
	}

	// --- programtosnapshot.go ---

	static function programToSnapshot(program:CompilerProgram, oldProgram:Program, hashWithText:Bool):Snapshot {
		if (oldProgram != null && oldProgram.program == program) {
			return oldProgram.snapshot;
		}
		final snapshot = new Snapshot();
		snapshot.options = program.Options();
		snapshot.hashWithText = hashWithText;
		snapshot.checkPending = program.Options().NoCheck.IsTrue();
		final to = new ToProgramSnapshot(program, oldProgram, snapshot);

		if (to.snapshot.canUseIncrementalState()) {
			to.reuseFromOldProgram();
			to.computeProgramFileChanges();
			to.handleFileDelete();
			to.handlePendingEmit();
			to.handlePendingCheck();
		}
		return snapshot;
	}

	static function fileAffectsGlobalScope(file:SourceFile):Bool {
		Binder.BindSourceFile(file);
		// if file contains anything that augments to global scope we need to build them as if
		// they are global files as well as module
		if (Core.Some(file.ModuleAugmentations, function(augmentation:ModuleName):Bool {
			return Ast.IsGlobalScopeAugmentation(augmentation.Parent);
		})) {
			return true;
		}

		if (Ast.IsExternalOrCommonJSModule(file) || Ast.IsJsonSourceFile(file)) {
			return false;
		}

		// For script files that contains only ambient external modules, although they are not actually external module files,
		// they can only be consumed via importing elements from them. Regular script files cannot consume them. Therefore,
		// there are no point to rebuild all script files if these special files have changed. However, if any statement
		// in the file is not ambient external module, we treat it as a regular script file.
		return file.Statements != null && file.Statements.Nodes != null && Core.Some(file.Statements.Nodes, function(stmt:Node):Bool {
			return !Ast.IsModuleWithStringLiteralName(stmt);
		});
	}

	static function addReferencedFilesFromSymbol(file:SourceFile, referencedFiles:Set<Path>, symbol:Symbol):Void {
		if (symbol == null) {
			return;
		}
		for (declaration in symbol.Declarations) {
			final fileOfDecl = Ast.GetSourceFileOfNode(declaration);
			if (fileOfDecl == null) {
				continue;
			}
			if (file != fileOfDecl) {
				referencedFiles.Add(fileOfDecl.Path());
			}
		}
	}

	// Get the module source file and all augmenting files from the import name node from file
	static function addReferencedFilesFromImportLiteral(file:SourceFile, referencedFiles:Set<Path>, checker:Checker, importName:LiteralLikeNode):Void {
		final symbol = checker.GetSymbolAtLocation(importName);
		addReferencedFilesFromSymbol(file, referencedFiles, symbol);
	}

	// Gets the path to reference file from file name, it could be resolvedPath if present otherwise path
	static function addReferencedFileFromFileName(program:CompilerProgram, fileName:std.String, referencedFiles:Set<Path>,
			sourceFileDirectory:std.String):Void {
		final redirect = program.GetParseFileRedirect(fileName);
		if (redirect != "") {
			referencedFiles.Add(Tspath.ToPath(redirect, program.GetCurrentDirectory(), program.UseCaseSensitiveFileNames()));
		} else {
			referencedFiles.Add(Tspath.ToPath(fileName, sourceFileDirectory, program.UseCaseSensitiveFileNames()));
		}
	}

	// Gets the referenced files for a file from the program with values for the keys as referenced file's path to be true
	static function getReferencedFiles(program:CompilerProgram, file:SourceFile):Set<Path> {
		final referencedFiles = new Set<Path>();

		// We need to use a set here since the code can contain the same import twice,
		// but that will only be one dependency.
		// To avoid invernal conversion, the key of the referencedFiles map must be of type Path
		final r = program.GetTypeCheckerForFileExclusive(Context.TODO(), file);
		final checker = r.a, done = r.b;
		final result = try getReferencedFilesWorker(program, file, referencedFiles, checker) catch (e:Dynamic) {
			done();
			throw e;
		};
		done();
		return result;
	}

	// PORT: body of getReferencedFiles after `defer done()`.
	static function getReferencedFilesWorker(program:CompilerProgram, file:SourceFile, referencedFiles:Set<Path>, checker:Checker):Set<Path> {
		for (importName in file.Imports()) {
			addReferencedFilesFromImportLiteral(file, referencedFiles, checker, importName);
		}

		final sourceFileDirectory = Tspath.GetDirectoryPath(file.FileName());
		// Handle triple slash references
		for (referencedFile in file.ReferencedFiles) {
			addReferencedFileFromFileName(program, referencedFile.FileName, referencedFiles, sourceFileDirectory);
		}

		// Handle type reference directives
		final typeRefsInFile = program.GetResolvedTypeReferenceDirectives().get(file.Path());
		if (typeRefsInFile != null) {
			for (typeRef in typeRefsInFile) {
				if (typeRef.ResolvedFileName != "") {
					addReferencedFileFromFileName(program, typeRef.ResolvedFileName, referencedFiles, sourceFileDirectory);
				}
			}
		}

		// Add module augmentation as references
		for (moduleName in file.ModuleAugmentations) {
			if (!Ast.IsStringLiteral(moduleName)) {
				continue;
			}
			addReferencedFilesFromImportLiteral(file, referencedFiles, checker, moduleName);
		}

		// From ambient modules
		for (ambientModule in checker.GetAmbientModules()) {
			addReferencedFilesFromSymbol(file, referencedFiles, ambientModule);
		}
		return Core.IfElse(referencedFiles.Len() > 0, referencedFiles, null);
	}

	// repopulateDiagnosticsOfFile repopulates diagnostic chains that depend on program state.
	// When diagnostics are copied from a previous build, their message chains may reference
	// stale program state (e.g., resolved module alternate results, package.json scope).
	// This function recomputes those chains using the current program's state.
	static function repopulateDiagnosticsOfFile(diags:DiagnosticsOrBuildInfoDiagnosticsWithFileName, p:CompilerProgram,
			file:SourceFile):DiagnosticsOrBuildInfoDiagnosticsWithFileName {
		if (diags.diagnostics != null) {
			final repopulated = repopulateDiagnosticsList(diags.diagnostics, p, file);
			if (repopulated == null) {
				return diags;
			}
			return new DiagnosticsOrBuildInfoDiagnosticsWithFileName(repopulated);
		}
		// buildInfoDiagnostics will be repopulated via toDiagnostic's repopulateInfo handling
		return diags;
	}

	// repopulateDiagnosticsList repopulates diagnostic chains in a list of diagnostics.
	// Returns nil if no diagnostics needed repopulation (i.e., no changes were made).
	static function repopulateDiagnosticsList(diags:Array<Diagnostic>, p:CompilerProgram, file:SourceFile):Array<Diagnostic> {
		var changed = false;
		final result:Array<Diagnostic> = [for (_ in 0...diags.length) null];
		for (i in 0...diags.length) {
			final d = diags[i];
			final repopulated = repopulateDiagnosticMessageChain(d.MessageChain(), p, file);
			if (repopulated != null) {
				final clone = d.Clone();
				clone.SetMessageChain(repopulated);
				result[i] = clone;
				changed = true;
			} else {
				result[i] = d;
			}
		}
		if (!changed) {
			return null;
		}
		return result;
	}

	// repopulateDiagnosticMessageChain repopulates chains that have repopulate info.
	// Returns nil if no changes were made.
	static function repopulateDiagnosticMessageChain(chain:Array<Diagnostic>, p:CompilerProgram, file:SourceFile):Array<Diagnostic> {
		if (Core.len(chain) == 0) {
			return null;
		}
		var changed = false;
		final result:Array<Diagnostic> = [for (_ in 0...chain.length) null];
		for (i in 0...chain.length) {
			final c = chain[i];
			if (c.RepopulateInfo() != null) {
				// Convert to buildInfoDiagnosticWithFileName and repopulate
				final b = new BuildInfoDiagnosticWithFileName();
				b.pos = c.Pos();
				b.end = c.End();
				b.code = c.Code();
				b.category = c.Category();
				b.messageKey = c.MessageKey();
				b.messageArgs = c.MessageArgs();
				b.repopulateInfo = c.RepopulateInfo();
				// Recursively handle nested chains
				for (nested in c.MessageChain()) {
					if (b.messageChain == null)
						b.messageChain = [];
					b.messageChain.push(astDiagToBuildInfoDiag(nested));
				}
				result[i] = repopulateDiagnosticChain(b, p, file);
				changed = true;
			} else {
				// Check nested chains
				final nested = repopulateDiagnosticMessageChain(c.MessageChain(), p, file);
				if (nested != null) {
					final clone = c.Clone();
					clone.SetMessageChain(nested);
					result[i] = clone;
					changed = true;
				} else {
					result[i] = c;
				}
			}
		}
		if (!changed) {
			return null;
		}
		return result;
	}

	static function astDiagToBuildInfoDiag(d:Diagnostic):BuildInfoDiagnosticWithFileName {
		final b = new BuildInfoDiagnosticWithFileName();
		b.pos = d.Pos();
		b.end = d.End();
		b.code = d.Code();
		b.category = d.Category();
		b.messageKey = d.MessageKey();
		b.messageArgs = d.MessageArgs();
		b.repopulateInfo = d.RepopulateInfo();
		for (nested in d.MessageChain()) {
			if (b.messageChain == null)
				b.messageChain = [];
			b.messageChain.push(astDiagToBuildInfoDiag(nested));
		}
		return b;
	}

	// --- snapshottobuildinfo.go ---

	static function snapshotToBuildInfo(snapshot:Snapshot, program:CompilerProgram, buildInfoFileName:std.String):BuildInfo {
		final buildInfo = new BuildInfo();
		buildInfo.Version = Core.Version();
		final to = new ToBuildInfo();
		to.snapshot = snapshot;
		to.program = program;
		to.buildInfo = buildInfo;
		to.buildInfoDirectory = Tspath.GetDirectoryPath(buildInfoFileName);
		to.comparePathsOptions = new ComparePathsOptions(program.UseCaseSensitiveFileNames(), program.GetCurrentDirectory());

		if (snapshot.options.IsIncremental()) {
			to.collectRootFiles();
			to.setFileInfoAndEmitSignatures();
			to.setRootOfIncrementalProgram();
			to.setCompilerOptions();
			to.setReferencedMap();
			to.setChangeFileSet();
			to.setSemanticDiagnostics();
			to.setEmitDiagnostics();
			to.setAffectedFilesPendingEmit();
			if (snapshot.latestChangedDtsFile != "") {
				buildInfo.LatestChangedDtsFile = to.relativeToBuildInfo(snapshot.latestChangedDtsFile);
			}
		} else {
			to.setRootOfNonIncrementalProgram();
		}
		buildInfo.Errors = snapshot.hasErrors.IsTrue();
		buildInfo.SemanticErrors = snapshot.hasSemanticErrors;
		buildInfo.CheckPending = snapshot.checkPending;
		to.setPackageJsons();
		return buildInfo;
	}

	static function toBuildInfoRepopulateInfo(info:RepopulateDiagnosticInfo):BuildInfoRepopulateInfo {
		if (info == null) {
			return null;
		}
		final r = new BuildInfoRepopulateInfo();
		r.Kind = info.Kind;
		r.ModuleReference = info.ModuleReference;
		r.Mode = info.Mode;
		r.PackageName = info.PackageName;
		return r;
	}

	// PORT: Go `value.Interface()` of a core.CompilerOptions field, as json.Marshal sees it:
	// core.Tristate marshals as a bool (null when unknown), int32 enums and *int as numbers.
	static function optionValueForJSON(field:ts.tsoptions.Tsoptions.CompilerOptionsField, value:Dynamic):Dynamic {
		switch (field.Kind) {
			case FieldTristate:
				final t:Tristate = value;
				return t == TSTrue ? true : (t == TSFalse ? false : null);
			default:
				return value;
		}
	}

	// --- buildinfotosnapshot.go ---

	static function buildInfoToSnapshot(buildInfo:BuildInfo, config:ParsedCommandLine, host:CompilerHost):Snapshot {
		final to = new ToSnapshot();
		to.buildInfo = buildInfo;
		to.buildInfoDirectory = Tspath.GetDirectoryPath(Tspath.GetNormalizedAbsolutePath(config.GetBuildInfoFileName(), config.GetCurrentDirectory()));
		to.filePaths = Core.Map(buildInfo.FileNames, function(fileName:std.String):Path {
			if (IsBuildInfoFileNameDefaultLibrary(fileName)) {
				return Tspath.ToPath(Tspath.CombinePaths(host.DefaultLibraryPath(), fileName), host.GetCurrentDirectory(), host.FS().UseCaseSensitiveFileNames());
			}
			return Tspath.ToPath(fileName, to.buildInfoDirectory, config.UseCaseSensitiveFileNames());
		});
		to.filePathSet = Core.Map(buildInfo.FileIdsList, function(fileIdList:Array<BuildInfoFileId>):Set<Path> {
			final fileSet = new Set<Path>();
			for (fileId in fileIdList) {
				fileSet.Add(to.toFilePath(fileId));
			}
			return fileSet;
		});
		to.setCompilerOptions();
		to.setFileInfoAndEmitSignatures();
		to.setReferencedMap();
		to.setChangeFileSet();
		to.setSemanticDiagnostics();
		to.setEmitDiagnostics();
		to.setAffectedFilesPendingEmit();
		if (buildInfo.LatestChangedDtsFile != "") {
			to.snapshot.latestChangedDtsFile = to.toAbsolutePath(buildInfo.LatestChangedDtsFile);
		}
		to.snapshot.hasErrors = Core.IfElse(buildInfo.Errors, TSTrue, TSFalse);
		to.snapshot.hasSemanticErrors = buildInfo.SemanticErrors;
		to.snapshot.checkPending = buildInfo.CheckPending;
		to.setPackageJsons();
		return to.snapshot;
	}

	static function fromBuildInfoRepopulateInfo(info:BuildInfoRepopulateInfo):RepopulateDiagnosticInfo {
		if (info == null) {
			return null;
		}
		final r = new RepopulateDiagnosticInfo();
		r.Kind = info.Kind;
		r.ModuleReference = info.ModuleReference;
		r.Mode = info.Mode;
		r.PackageName = info.PackageName;
		return r;
	}

	// --- affectedfileshandler.go ---

	static function collectAllAffectedFiles(ctx:Context, program:Program):Void {
		if (program.snapshot.changedFilesSet.Size() == 0) {
			return;
		}

		final handler = new AffectedFilesHandler(ctx, program);
		var wg = Core.NewWorkGroup(handler.program.program.SingleThreaded());
		// PORT: collections.SyncSet[*ast.SourceFile] → an ObjectMap keyed by identity plus the
		// insertion order (Go: random order; the result does not depend on it).
		final resultSet = new ObjectMap<SourceFile, Bool>();
		final result:Array<SourceFile> = [];
		program.snapshot.changedFilesSet.Range(function(file:Path):Bool {
			wg.Queue(function() {
				for (affectedFile in handler.getFilesAffectedBy(file)) {
					if (!resultSet.exists(affectedFile)) {
						resultSet.set(affectedFile, true);
						result.push(affectedFile);
					}
				}
			});
			return true;
		});
		wg.RunAndWait();

		if (ctx.Err() != null) {
			return;
		}

		// For all the affected files, get all the files that would need to change their dts or js files,
		// update their diagnostics
		wg = Core.NewWorkGroup(program.program.SingleThreaded());
		final emitKind = GetFileEmitKind(program.snapshot.options);
		for (file in result) {
			// remove the cached semantic diagnostics and handle dts emit and js emit if needed
			final dtsMayChange = handler.getDtsMayChange(file.Path(), emitKind);
			wg.Queue(function() {
				handler.handleDtsMayChangeOfAffectedFile(dtsMayChange, file);
			});
		}
		wg.RunAndWait();

		// Update the snapshot with the new state
		handler.updateSnapshot();
	}

	// --- emitfileshandler.go ---

	static function emitFiles(ctx:Context, program:Program, options:EmitOptions, isForDtsErrors:Bool):EmitResult {
		final emitHandler = new EmitFilesHandler(ctx, program, isForDtsErrors);

		// Single file emit - do direct from program
		if (!isForDtsErrors && options.TargetSourceFile != null) {
			final result = program.program.Emit(ctx, emitHandler.getEmitOptions(options));
			emitHandler.updateHasEmitDiagnostics(result);
			if (ctx.Err() != null) {
				return null;
			}
			emitHandler.updateSnapshot();
			return result;
		}

		// Emit only affected files if using builder for emit
		return emitHandler.emitAllAffectedFiles(options);
	}

	// --- port helpers ---

	// PORT: Go `append(s, other...)` where s is owned by the caller; nil stays nil when nothing is added.
	static function appendAll<T>(s:Array<T>, other:Array<T>):Array<T> {
		if (other == null || other.length == 0)
			return s;
		if (s == null)
			s = [];
		for (x in other)
			s.push(x);
		return s;
	}
}

// --- incremental.go (types) ---

interface BuildInfoReader {
	function ReadBuildInfo(config:ParsedCommandLine):BuildInfo;
}

// Go type buildInfoReader.
@:allow(ts.execute.incremental)
class BuildInfoReader_ implements BuildInfoReader {
	var host:CompilerHost = null;

	public function new(host:CompilerHost) {
		this.host = host;
	}

	public function ReadBuildInfo(config:ParsedCommandLine):BuildInfo {
		final buildInfoFileName = config.GetBuildInfoFileName();
		if (buildInfoFileName == "") {
			return null;
		}

		// Read build info file
		final r = this.host.FS().ReadFile(buildInfoFileName);
		if (!r.ok) {
			return null;
		}
		return Incremental.UnmarshalBuildInfo(r.value);
	}
}
