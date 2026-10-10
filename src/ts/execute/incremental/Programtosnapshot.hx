package ts.execute.incremental;

// Port of programtosnapshot.go (types and methods). Package-level funcs are in Incremental.hx.

// Go type toProgramSnapshot.
@:allow(ts.execute.incremental)
class ToProgramSnapshot {
	var program:CompilerProgram = null;
	var oldProgram:Program = null;
	var snapshot:Snapshot = null;
	var globalFileRemoved:Bool = false;

	public function new(program:CompilerProgram, oldProgram:Program, snapshot:Snapshot) {
		this.program = program;
		this.oldProgram = oldProgram;
		this.snapshot = snapshot;
	}

	function reuseFromOldProgram():Void {
		if (this.oldProgram != null) {
			if (this.snapshot.options.Composite.IsTrue()) {
				this.snapshot.latestChangedDtsFile = this.oldProgram.snapshot.latestChangedDtsFile;
			}
			// Copy old snapshot's changed files set
			this.oldProgram.snapshot.changedFilesSet.Range(function(key:Path):Bool {
				this.snapshot.changedFilesSet.Add(key);
				return true;
			});
			this.oldProgram.snapshot.affectedFilesPendingEmit.Range(function(key:Path, emitKind:FileEmitKind):Bool {
				this.snapshot.affectedFilesPendingEmit.Store(key, emitKind);
				return true;
			});
			this.snapshot.buildInfoEmitPending = this.oldProgram.snapshot.buildInfoEmitPending;
			this.snapshot.hasErrorsFromOldState = this.oldProgram.snapshot.hasErrors;
			this.snapshot.hasSemanticErrorsFromOldState = this.oldProgram.snapshot.hasSemanticErrors;
			this.snapshot.packageJsonsFromOldState = this.oldProgram.snapshot.packageJsons;
			this.snapshot.missingPackageJsonsFromOldState = this.oldProgram.snapshot.missingPackageJsons;
		} else {
			this.snapshot.buildInfoEmitPending = this.snapshot.options.IsIncremental();
		}
	}

	function computeProgramFileChanges():Void {
		final canCopySemanticDiagnostics = this.oldProgram != null
			&& !Tsoptions.CompilerOptionsAffectSemanticDiagnostics(this.oldProgram.snapshot.options, this.program.Options());
		// We can only reuse emit signatures (i.e. .d.ts signatures) if the .d.ts file is unchanged,
		// which will eg be depedent on change in options like declarationDir and outDir options are unchanged.
		// We need to look in oldState.compilerOptions, rather than oldCompilerOptions (i.e.we need to disregard useOldState) because
		// oldCompilerOptions can be undefined if there was change in say module from None to some other option
		// which would make useOldState as false since we can now use reference maps that are needed to track what to emit, what to check etc
		// but that option change does not affect d.ts file name so emitSignatures should still be reused.
		final canCopyEmitSignatures = this.snapshot.options.Composite.IsTrue()
			&& this.oldProgram != null
			&& !Tsoptions.CompilerOptionsAffectDeclarationPath(this.oldProgram.snapshot.options, this.program.Options());
		final copyDeclarationFileDiagnostics = canCopySemanticDiagnostics
			&& this.snapshot.options.SkipLibCheck.IsTrue() == this.oldProgram.snapshot.options.SkipLibCheck.IsTrue();
		final copyLibFileDiagnostics = copyDeclarationFileDiagnostics
			&& this.snapshot.options.SkipDefaultLibCheck.IsTrue() == this.oldProgram.snapshot.options.SkipDefaultLibCheck.IsTrue();

		final files = this.program.GetSourceFiles();
		final wg = Core.NewWorkGroup(this.program.SingleThreaded());
		for (file in files) {
			wg.Queue(function() {
				final version = this.snapshot.computeHash(file.Text());
				final impliedNodeFormat = this.program.GetSourceFileMetaData(file.Path()).ImpliedNodeFormat;
				final affectsGlobalScope = Incremental.fileAffectsGlobalScope(file);
				var signature = "";
				final newReferences = Incremental.getReferencedFiles(this.program, file);
				if (newReferences != null) {
					this.snapshot.referencedMap.storeReferences(file.Path(), newReferences);
				}
				if (this.oldProgram != null) {
					final old = this.oldProgram.snapshot.fileInfos.Load(file.Path());
					if (old.ok) {
						final oldFileInfo = old.value;
						signature = oldFileInfo.signature;
						if (oldFileInfo.version != version
							|| oldFileInfo.affectsGlobalScope != affectsGlobalScope
							|| oldFileInfo.impliedNodeFormat != impliedNodeFormat) {
							this.snapshot.addFileToChangeSet(file.Path());
						} else if (!newReferences.Equals(this.oldProgram.snapshot.referencedMap.getReferences(file.Path()).value)) {
							// Referenced files changed
							this.snapshot.addFileToChangeSet(file.Path());
						} else if (newReferences != null) {
							for (refPath in newReferences.Keys().keys()) {
								if (this.program.GetSourceFileByPath(refPath) == null) {
									if (this.oldProgram.snapshot.fileInfos.Load(refPath).ok) {
										// Referenced file was deleted in the new program
										this.snapshot.addFileToChangeSet(file.Path());
										break;
									}
								}
							}
						}
					} else {
						this.snapshot.addFileToChangeSet(file.Path());
					}
					if (!this.snapshot.changedFilesSet.Has(file.Path())) {
						final emitDiagnostics = this.oldProgram.snapshot.emitDiagnosticsPerFile.Load(file.Path());
						if (emitDiagnostics.ok) {
							this.snapshot.emitDiagnosticsPerFile.Store(file.Path(),
								Incremental.repopulateDiagnosticsOfFile(emitDiagnostics.value, this.program, file));
						}
						if (canCopySemanticDiagnostics) {
							if ((!file.IsDeclarationFile || copyDeclarationFileDiagnostics)
								&& (!this.program.IsSourceFileDefaultLibrary(file.Path()) || copyLibFileDiagnostics)) {
								// Unchanged file copy diagnostics
								final diagnostics = this.oldProgram.snapshot.semanticDiagnosticsPerFile.Load(file.Path());
								if (diagnostics.ok) {
									this.snapshot.semanticDiagnosticsPerFile.Store(file.Path(),
										Incremental.repopulateDiagnosticsOfFile(diagnostics.value, this.program, file));
								}
							}
						}
					}
					if (canCopyEmitSignatures) {
						final oldEmitSignature = this.oldProgram.snapshot.emitSignatures.Load(file.Path());
						if (oldEmitSignature.ok) {
							this.snapshot.emitSignatures.Store(file.Path(),
								oldEmitSignature.value.getNewEmitSignature(this.oldProgram.snapshot.options, this.snapshot.options));
						}
					}
				} else {
					this.snapshot.addFileToAffectedFilesPendingEmit(file.Path(), Incremental.GetFileEmitKind(this.snapshot.options));
					signature = version;
				}
				this.snapshot.fileInfos.Store(file.Path(), new FileInfo(version, signature, affectsGlobalScope, impliedNodeFormat));
			});
		}
		wg.RunAndWait();
	}

	function handleFileDelete():Void {
		if (this.oldProgram != null) {
			// If the global file is removed, add all files as changed
			this.oldProgram.snapshot.fileInfos.Range(function(filePath:Path, oldInfo:FileInfo):Bool {
				if (!this.snapshot.fileInfos.Load(filePath).ok) {
					if (oldInfo.affectsGlobalScope) {
						for (file in this.snapshot.getAllFilesExcludingDefaultLibraryFile(this.program, null)) {
							this.snapshot.addFileToChangeSet(file.Path());
						}
						this.globalFileRemoved = true;
					} else {
						this.snapshot.buildInfoEmitPending = true;
					}
					return false;
				}
				return true;
			});
		}
	}

	function handlePendingEmit():Void {
		if (this.oldProgram != null && !this.globalFileRemoved) {
			// If options affect emit, then we need to do complete emit per compiler options
			// otherwise only the js or dts that needs to emitted because its different from previously emitted options
			var pendingEmitKind:FileEmitKind;
			if (Tsoptions.CompilerOptionsAffectEmit(this.oldProgram.snapshot.options, this.snapshot.options)) {
				pendingEmitKind = Incremental.GetFileEmitKind(this.snapshot.options);
			} else {
				pendingEmitKind = Incremental.getPendingEmitKindWithOptions(this.snapshot.options, this.oldProgram.snapshot.options);
			}
			if (pendingEmitKind != FileEmitKindNone) {
				// Add all files to affectedFilesPendingEmit since emit changed
				for (file in this.program.GetSourceFiles()) {
					// Add to affectedFilesPending emit only if not changed since any changed file will do full emit
					if (!this.snapshot.changedFilesSet.Has(file.Path())) {
						this.snapshot.addFileToAffectedFilesPendingEmit(file.Path(), pendingEmitKind);
					}
				}
				this.snapshot.buildInfoEmitPending = true;
			}
		}
	}

	function handlePendingCheck():Void {
		if (this.oldProgram != null
			&& this.snapshot.semanticDiagnosticsPerFile.Size() != this.program.GetSourceFiles().length
			&& this.oldProgram.snapshot.checkPending != this.snapshot.checkPending) {
			this.snapshot.buildInfoEmitPending = true;
		}
	}
}
