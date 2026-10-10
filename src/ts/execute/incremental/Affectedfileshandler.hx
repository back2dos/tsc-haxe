package ts.execute.incremental;

// Port of affectedfileshandler.go (types and methods). collectAllAffectedFiles is in Incremental.hx.

// Go `type dtsMayChange map[tspath.Path]FileEmitKind`.
// PORT: a map type with a method → class wrapping a GoMap (its iteration order is never relied on).
@:allow(ts.execute.incremental)
class DtsMayChange {
	var m:go.GoMap<Path, FileEmitKind> = new go.GoMap<Path, FileEmitKind>();

	public function new() {}

	function addFileToAffectedFilesPendingEmit(filePath:Path, emitKind:FileEmitKind):Void {
		this.m.set(filePath, emitKind);
	}
}

// Go type updatedSignature. PORT: sync.Mutex dropped (single-threaded).
@:allow(ts.execute.incremental)
class UpdatedSignature {
	var signature:std.String = "";
	var kind:SignatureUpdateKind = SignatureUpdateKindComputedDts;

	public function new() {}
}

// Go type affectedFilesHandler.
@:allow(ts.execute.incremental)
class AffectedFilesHandler {
	var ctx:Context = null;
	var program:Program = null;
	var hasAllFilesExcludingDefaultLibraryFile:Bool = false; // PORT: atomic.Bool → Bool
	var updatedSignatures:SyncMap<Path, UpdatedSignature> = new SyncMap<Path, UpdatedSignature>();
	var dtsMayChange:Array<DtsMayChange> = null;
	var filesToRemoveDiagnostics:SyncSet<Path> = new SyncSet<Path>();
	var cleanedDiagnosticsOfLibFiles:Bool = false; // PORT: sync.Once → flag
	var seenFileAndReferences:SyncMap<Path, Bool> = new SyncMap<Path, Bool>(false);

	public function new(ctx:Context, program:Program) {
		this.ctx = ctx;
		this.program = program;
	}

	function getDtsMayChange(affectedFilePath:Path, affectedFileEmitKind:FileEmitKind):DtsMayChange {
		final result = new DtsMayChange();
		result.m.set(affectedFilePath, affectedFileEmitKind);
		if (this.dtsMayChange == null)
			this.dtsMayChange = [];
		this.dtsMayChange.push(result);
		return result;
	}

	function isChangedSignature(path:Path):Bool {
		final newSignature = this.updatedSignatures.Load(path).value;
		// This method is called after updating signatures of that path, so signature is present in updatedSignatures
		// And is already calculated, so no need to lock and unlock mutex on the entry
		final oldInfo = this.program.snapshot.fileInfos.Load(path).value;
		return newSignature.signature != oldInfo.signature;
	}

	function removeSemanticDiagnosticsOf(path:Path):Void {
		this.filesToRemoveDiagnostics.Add(path);
	}

	function removeDiagnosticsOfLibraryFiles():Void {
		if (!this.cleanedDiagnosticsOfLibFiles) {
			this.cleanedDiagnosticsOfLibFiles = true;
			for (file in this.program.GetSourceFiles()) {
				if (this.program.program.IsSourceFileDefaultLibrary(file.Path()) && !this.program.program.SkipTypeChecking(file, true)) {
					this.removeSemanticDiagnosticsOf(file.Path());
				}
			}
		}
	}

	function computeDtsSignature(file:SourceFile):std.String {
		var signature = "";
		final options = new EmitOptions();
		options.TargetSourceFile = file;
		options.EmitOnly = EmitOnlyForcedDts;
		options.WriteFile = function(fileName:std.String, text:std.String, data:WriteFileData):Null<Error> {
			if (!Tspath.IsDeclarationFileName(fileName)) {
				throw "File extension for signature expected to be dts, got : " + fileName;
			}
			signature = this.program.snapshot.computeSignatureWithDiagnostics(file, text, data);
			return null;
		};
		this.program.program.Emit(this.ctx, options);
		return signature;
	}

	function updateShapeSignature(file:SourceFile, useFileVersionAsSignature:Bool):Bool {
		final update = new UpdatedSignature();
		// If we have cached the result for this file, that means hence forth we should assume file shape is uptodate
		if (this.updatedSignatures.LoadOrStore(file.Path(), update).ok) {
			// Ensure calculations for existing ones are complete before using the value
			return false;
		}

		final info = this.program.snapshot.fileInfos.Load(file.Path()).value;
		final prevSignature = info.signature;
		if (!file.IsDeclarationFile && !useFileVersionAsSignature) {
			update.signature = this.computeDtsSignature(file);
		}
		// Default is to use file version as signature
		if (update.signature == "") {
			update.signature = info.version;
			update.kind = SignatureUpdateKindUsedVersion;
		}
		return update.signature != prevSignature;
	}

	function getFilesAffectedBy(path:Path):Array<SourceFile> {
		final file = this.program.program.GetSourceFileByPath(path);
		if (file == null) {
			return null;
		}

		if (!this.updateShapeSignature(file, false)) {
			return [file];
		}

		final info = this.program.snapshot.fileInfos.Load(file.Path()).value;
		if (info.affectsGlobalScope) {
			this.hasAllFilesExcludingDefaultLibraryFile = true;
			this.program.snapshot.getAllFilesExcludingDefaultLibraryFile(this.program.program, file);
		}

		if (this.program.snapshot.options.IsolatedModules.IsTrue()) {
			return [file];
		}

		// Now we need to if each file in the referencedBy list has a shape change as well.
		// Because if so, its own referencedBy files need to be saved as well to make the
		// emitting result consistent with files on disk.
		final seenFileNamesMap = this.forEachFileReferencedBy(file, function(currentFile:SourceFile, currentPath:Path):Pair<Bool, Bool> {
			// If the current file is not nil and has a shape change, we need to queue it for processing
			if (currentFile != null && this.updateShapeSignature(currentFile, false)) {
				return new Pair(true, false);
			}
			return new Pair(false, false);
		});
		// Return array of values that needs emit
		return Core.Filter([for (f in seenFileNamesMap.Values()) f], function(file:SourceFile):Bool {
			return file != null;
		});
	}

	// PORT: fn returns (queueForFile, fastReturn) as Pair; the map keeps insertion order (Go: random).
	function forEachFileReferencedBy(file:SourceFile, fn:(currentFile:SourceFile, currentPath:Path) -> Pair<Bool, Bool>):OrderedMap<Path, SourceFile> {
		// Now we need to if each file in the referencedBy list has a shape change as well.
		// Because if so, its own referencedBy files need to be saved as well to make the
		// emitting result consistent with files on disk.
		final seenFileNamesMap = new OrderedMap<Path, SourceFile>();
		// Start with the paths this file was referenced by
		seenFileNamesMap.Set(file.Path(), file);
		final queue:Array<Path> = [for (p in this.program.snapshot.referencedMap.getReferencedBy(file.Path())) p];
		while (queue.length > 0) {
			final currentPath = queue.pop();
			if (!seenFileNamesMap.Has(currentPath)) {
				final currentFile = this.program.program.GetSourceFileByPath(currentPath);
				seenFileNamesMap.Set(currentPath, currentFile);
				final r = fn(currentFile, currentPath);
				final queueForFile = r.a, fastReturn = r.b;
				if (fastReturn) {
					return seenFileNamesMap;
				}
				if (queueForFile) {
					for (ref in this.program.snapshot.referencedMap.getReferencedBy(currentFile.Path())) {
						queue.push(ref);
					}
				}
			}
		}
		return seenFileNamesMap;
	}

	// Handles semantic diagnostics and dts emit for affectedFile and files, that are referencing modules that export entities from affected file
	// This is because even though js emit doesnt change, dts emit / type used can change resulting in need for dts emit and js change
	function handleDtsMayChangeOfAffectedFile(dtsMayChange:DtsMayChange, affectedFile:SourceFile):Void {
		this.removeSemanticDiagnosticsOf(affectedFile.Path());

		// If affected files is everything except default library, then nothing more to do
		if (this.hasAllFilesExcludingDefaultLibraryFile) {
			this.removeDiagnosticsOfLibraryFiles();
			// When a change affects the global scope, all files are considered to be affected without updating their signature
			// That means when affected file is handled, its signature can be out of date
			// To avoid this, ensure that we update the signature for any affected file in this scenario.
			this.updateShapeSignature(affectedFile, false);
			return;
		}

		if (this.program.snapshot.options.AssumeChangesOnlyAffectDirectDependencies.IsTrue()) {
			return;
		}

		// Iterate on referencing modules that export entities from affected file and delete diagnostics and add pending emit
		// If there was change in signature (dts output) for the changed file,
		// then only we need to handle pending file emit
		if (!this.program.snapshot.changedFilesSet.Has(affectedFile.Path()) || !this.isChangedSignature(affectedFile.Path())) {
			return;
		}

		// At this point affectedFile is actually one of the changed files
		// that has some change in its .d.ts signature.

		// Since isolated modules dont change js files, files affected by change in signature is itself
		// But we need to cleanup semantic diagnostics and queue dts emit for affected files
		if (this.program.snapshot.options.IsolatedModules.IsTrue()) {
			this.forEachFileReferencedBy(affectedFile, function(currentFile:SourceFile, currentPath:Path):Pair<Bool, Bool> {
				if (this.handleDtsMayChangeOfGlobalScope(dtsMayChange, currentPath /*invalidateJsFiles*/, false)) {
					return new Pair(false, true);
				}
				this.handleDtsMayChangeOf(dtsMayChange, currentPath /*invalidateJsFiles*/, false);
				if (this.isChangedSignature(currentPath)) {
					return new Pair(true, false);
				}
				return new Pair(false, false);
			});
		}

		var invalidateJsFiles = false;
		var typeChecker:Checker = null;
		var done:() -> Void = null;
		// If exported const enum, we need to ensure that js files are emitted as well since the const enum value changed
		if (affectedFile.Symbol != null) {
			// PORT: Go ranges over the exports map (random order); the result does not depend on it.
			for (exported in affectedFile.Symbol.Exports) {
				if (exported.Flags & SymbolFlagsConstEnum != 0) {
					invalidateJsFiles = true;
					break;
				}
				if (typeChecker == null) {
					final r = this.program.program.GetTypeCheckerForFileExclusive(this.ctx, affectedFile);
					typeChecker = r.a;
					done = r.b;
				}
				final aliased = Checker.SkipAlias(exported, typeChecker);
				if (aliased == exported) {
					continue;
				}
				if ((aliased.Flags & SymbolFlagsConstEnum) != 0) {
					if (Slices.ContainsFunc(aliased.Declarations, function(d:Node):Bool {
						return Ast.GetSourceFileOfNode(d) == affectedFile;
					})) {
						invalidateJsFiles = true;
						break;
					}
				}
			}
		}
		if (done != null) {
			done();
		}

		// Go through files that reference affected file and handle dts emit and semantic diagnostics for them and their references
		for (fileReferencingChangedFile in this.program.snapshot.referencedMap.getReferencedBy(affectedFile.Path())) {
			if (this.handleDtsMayChangeOfGlobalScope(dtsMayChange, fileReferencingChangedFile, invalidateJsFiles)) {
				return;
			}
			// Since references of changed file = affected files - we would have already handled d.ts emit and semantic diagnostics
			// for those files. Now we need to handle files referencing those affected files to ensure correctness.
			for (fileReferencingAffectedFile in this.program.snapshot.referencedMap.getReferencedBy(fileReferencingChangedFile)) {
				if (this.handleDtsMayChangeOfFileAndReferences(dtsMayChange, fileReferencingAffectedFile, invalidateJsFiles)) {
					return;
				}
			}
		}
	}

	function handleDtsMayChangeOfFileAndReferences(dtsMayChange:DtsMayChange, filePath:Path, invalidateJsFiles:Bool):Bool {
		final r = this.seenFileAndReferences.LoadOrStore(filePath, invalidateJsFiles);
		final existing = r.value, loaded = r.ok;
		if (loaded && (existing || !invalidateJsFiles)) {
			return false;
		} else if (loaded && invalidateJsFiles) {
			this.seenFileAndReferences.Store(filePath, true);
		}

		if (this.handleDtsMayChangeOfGlobalScope(dtsMayChange, filePath, invalidateJsFiles)) {
			return true;
		}
		this.handleDtsMayChangeOf(dtsMayChange, filePath, invalidateJsFiles);

		// Remove the diagnostics of files that import this file and
		// any files that are referenced by it (directly or indirectly)
		for (referencingFilePath in this.program.snapshot.referencedMap.getReferencedBy(filePath)) {
			if (this.handleDtsMayChangeOfFileAndReferences(dtsMayChange, referencingFilePath, invalidateJsFiles)) {
				return true;
			}
		}
		return false;
	}

	function handleDtsMayChangeOfGlobalScope(dtsMayChange:DtsMayChange, filePath:Path, invalidateJsFiles:Bool):Bool {
		final r = this.program.snapshot.fileInfos.Load(filePath);
		if (!r.ok || !r.value.affectsGlobalScope) {
			return false;
		}
		// Every file needs to be handled
		for (file in this.program.snapshot.getAllFilesExcludingDefaultLibraryFile(this.program.program, null)) {
			this.handleDtsMayChangeOf(dtsMayChange, file.Path(), invalidateJsFiles);
		}
		this.removeDiagnosticsOfLibraryFiles();
		return true;
	}

	// Handle the dts may change, so they need to be added to pending emit if dts emit is enabled,
	// Also we need to make sure signature is updated for these files
	function handleDtsMayChangeOf(dtsMayChange:DtsMayChange, path:Path, invalidateJsFiles:Bool):Void {
		if (this.program.snapshot.changedFilesSet.Has(path)) {
			return;
		}
		final file = this.program.program.GetSourceFileByPath(path);
		if (file == null) {
			return;
		}
		this.removeSemanticDiagnosticsOf(path);
		// Even though the js emit doesnt change and we are already handling dts emit and semantic diagnostics
		// we need to update the signature to reflect correctness of the signature(which is output d.ts emit) of this file
		// This ensures that we dont later during incremental builds considering wrong signature.
		// Eg where this also is needed to ensure that .tsbuildinfo generated by incremental build should be same as if it was first fresh build
		// But we avoid expensive full shape computation, as using file version as shape is enough for correctness.
		this.updateShapeSignature(file, true);
		// If not dts emit, nothing more to do
		if (invalidateJsFiles) {
			dtsMayChange.addFileToAffectedFilesPendingEmit(path, Incremental.GetFileEmitKind(this.program.snapshot.options));
		} else if (this.program.snapshot.options.GetEmitDeclarations()) {
			dtsMayChange.addFileToAffectedFilesPendingEmit(path,
				Core.IfElse(this.program.snapshot.options.DeclarationMap.IsTrue(), FileEmitKindAllDts, FileEmitKindDts));
		}
	}

	function updateSnapshot():Void {
		if (this.ctx.Err() != null) {
			return;
		}
		this.updatedSignatures.Range(function(filePath:Path, update:UpdatedSignature):Bool {
			final r = this.program.snapshot.fileInfos.Load(filePath);
			if (r.ok) {
				r.value.signature = update.signature;
				if (this.program.testingData != null) {
					this.program.testingData.UpdatedSignatureKinds.set(filePath, update.kind);
				}
			}
			return true;
		});
		this.filesToRemoveDiagnostics.Range(function(file:Path):Bool {
			this.program.snapshot.semanticDiagnosticsPerFile.Delete(file);
			return true;
		});
		for (change in this.dtsMayChange) {
			for (filePath in change.m.keys()) {
				this.program.snapshot.addFileToAffectedFilesPendingEmit(filePath, change.m.get(filePath));
			}
		}
		this.program.snapshot.changedFilesSet = new SyncSet<Path>();
		this.program.snapshot.buildInfoEmitPending = true;
	}
}
