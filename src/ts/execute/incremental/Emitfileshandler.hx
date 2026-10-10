package ts.execute.incremental;

// Port of emitfileshandler.go (types and methods). emitFiles is in Incremental.hx.

// Go type emitUpdate.
@:allow(ts.execute.incremental)
class EmitUpdate {
	var pendingKind:FileEmitKind = FileEmitKindNone;
	var result:EmitResult = null;
	var dtsErrorsFromCache:Bool = false;

	public function new(pendingKind:FileEmitKind, result:EmitResult, dtsErrorsFromCache:Bool = false) {
		this.pendingKind = pendingKind;
		this.result = result;
		this.dtsErrorsFromCache = dtsErrorsFromCache;
	}
}

// Go type emitFilesHandler.
@:allow(ts.execute.incremental)
class EmitFilesHandler {
	var ctx:Context = null;
	var program:Program = null;
	var isForDtsErrors:Bool = false;
	var signatures:SyncMap<Path, std.String> = new SyncMap<Path, std.String>("");
	var emitSignatures:SyncMap<Path, EmitSignature> = new SyncMap<Path, EmitSignature>();
	var latestChangedDtsFiles:SyncMap<Path, std.String> = new SyncMap<Path, std.String>("");
	var deletedPendingKinds:Set<Path> = new Set<Path>();
	var emitUpdates:SyncMap<Path, EmitUpdate> = new SyncMap<Path, EmitUpdate>();
	var hasEmitDiagnostics:Bool = false; // PORT: atomic.Bool → Bool

	public function new(ctx:Context, program:Program, isForDtsErrors:Bool) {
		this.ctx = ctx;
		this.program = program;
		this.isForDtsErrors = isForDtsErrors;
	}

	// Determining what all is pending to be emitted based on previous options or previous file emit flags
	function getPendingEmitKindForEmitOptions(emitKind:FileEmitKind, options:EmitOptions):FileEmitKind {
		var pendingKind = Incremental.getPendingEmitKind(emitKind, 0);
		if (options.EmitOnly == EmitOnlyDts) {
			pendingKind = pendingKind & FileEmitKindAllDts;
		}
		if (this.isForDtsErrors) {
			pendingKind = pendingKind & FileEmitKindDtsErrors;
		}
		return pendingKind;
	}

	// Emits the next affected file's emit result (EmitResult and sourceFiles emitted) or returns undefined if iteration is complete
	// The first of writeFile if provided, writeFile of BuilderProgramHost if provided, writeFile of compiler host
	// in that order would be used to write the files
	function emitAllAffectedFiles(options:EmitOptions):EmitResult {
		// Emit all affected files
		if (this.program.snapshot.canUseIncrementalState()) {
			final results = this.emitFilesIncremental(options);
			if (this.isForDtsErrors) {
				if (options.TargetSourceFile != null) {
					// Result from cache
					final diagnostics = this.program.snapshot.emitDiagnosticsPerFile.Load(options.TargetSourceFile.Path()).value;
					final result = new EmitResult();
					result.EmitSkipped = true;
					// PORT: Go calls the method on a possibly nil *DiagnosticsOrBuildInfoDiagnosticsWithFileName
					// (it would panic); kept as a plain call.
					result.Diagnostics = diagnostics.getDiagnostics(this.program.program, options.TargetSourceFile);
					this.updateHasEmitDiagnostics(result);
					return result;
				}
				for (result in results) {
					this.updateHasEmitDiagnostics(result);
				}
				return Compiler.CombineEmitResults(results);
			} else {
				// Combine results and update buildInfo
				final result = Compiler.CombineEmitResults(results);
				this.updateHasEmitDiagnostics(result);
				this.emitBuildInfo(options, result);
				return result;
			}
		} else if (!this.isForDtsErrors) {
			final result = this.program.program.Emit(this.ctx, this.getEmitOptions(options));
			this.updateHasEmitDiagnostics(result);
			this.updateSnapshot();
			this.emitBuildInfo(options, result);
			return result;
		} else {
			final result = new EmitResult();
			result.EmitSkipped = true;
			result.Diagnostics = this.program.program.GetDeclarationDiagnostics(this.ctx, options.TargetSourceFile);
			if (Core.len(result.Diagnostics) != 0) {
				this.updateHasEmitDiagnostics(result);
				this.program.snapshot.hasEmitDiagnostics = true;
			}
			return result;
		}
	}

	function updateHasEmitDiagnostics(result:EmitResult):Void {
		if (result != null && Core.len(result.Diagnostics) != 0) {
			this.hasEmitDiagnostics = true;
		}
	}

	function emitBuildInfo(options:EmitOptions, result:EmitResult):Void {
		final buildInfoResult = this.program.emitBuildInfo(this.ctx, options);
		if (buildInfoResult != null) {
			result.Diagnostics = Incremental.appendAll(result.Diagnostics, buildInfoResult.Diagnostics);
			result.EmittedFiles = Incremental.appendAll(result.EmittedFiles, buildInfoResult.EmittedFiles);
		}
	}

	function emitFilesIncremental(options:EmitOptions):Array<EmitResult> {
		// Get all affected files
		Incremental.collectAllAffectedFiles(this.ctx, this.program);
		if (this.ctx.Err() != null) {
			return null;
		}

		final wg = Core.NewWorkGroup(this.program.program.SingleThreaded());
		this.program.snapshot.affectedFilesPendingEmit.Range(function(path:Path, emitKind:FileEmitKind):Bool {
			final affectedFile = this.program.program.GetSourceFileByPath(path);
			if (affectedFile == null || !this.program.program.SourceFileMayBeEmitted(affectedFile, false)) {
				this.deletedPendingKinds.Add(path);
				return true;
			}
			final pendingKind = this.getPendingEmitKindForEmitOptions(emitKind, options);
			if (pendingKind != 0) {
				wg.Queue(function() {
					// Determine if we can do partial emit
					var emitOnly:EmitOnly = EmitAll;
					if ((pendingKind & FileEmitKindAllJs) != 0) {
						emitOnly = EmitOnlyJs;
					}
					if ((pendingKind & FileEmitKindAllDts) != 0) {
						if (emitOnly == EmitOnlyJs) {
							emitOnly = EmitAll;
						} else {
							emitOnly = EmitOnlyDts;
						}
					}
					var result:EmitResult;
					if (!this.isForDtsErrors) {
						final o = new EmitOptions();
						o.TargetSourceFile = affectedFile;
						o.EmitOnly = emitOnly;
						o.WriteFile = options.WriteFile;
						result = this.program.program.Emit(this.ctx, this.getEmitOptions(o));
					} else {
						result = new EmitResult();
						result.EmitSkipped = true;
						result.Diagnostics = this.program.program.GetDeclarationDiagnostics(this.ctx, affectedFile);
					}
					this.updateHasEmitDiagnostics(result);

					// Update the pendingEmit for the file
					this.emitUpdates.Store(path, new EmitUpdate(Incremental.getPendingEmitKind(emitKind, pendingKind), result));
				});
			}
			return true;
		});
		wg.RunAndWait();
		if (this.ctx.Err() != null) {
			return null;
		}

		// Get updated errors that were not included in affected files emit
		this.program.snapshot.emitDiagnosticsPerFile.Range(function(path:Path, diagnostics:DiagnosticsOrBuildInfoDiagnosticsWithFileName):Bool {
			if (!this.emitUpdates.Load(path).ok) {
				final affectedFile = this.program.program.GetSourceFileByPath(path);
				if (affectedFile == null || !this.program.program.SourceFileMayBeEmitted(affectedFile, false)) {
					this.deletedPendingKinds.Add(path);
					return true;
				}
				final pendingKind = this.program.snapshot.affectedFilesPendingEmit.Load(path).value;
				final result = new EmitResult();
				result.EmitSkipped = true;
				result.Diagnostics = diagnostics.getDiagnostics(this.program.program, affectedFile);
				this.emitUpdates.Store(path, new EmitUpdate(pendingKind, result, true));
			}
			return true;
		});

		return this.updateSnapshot();
	}

	function getEmitOptions(options:EmitOptions):EmitOptions {
		if (!this.program.snapshot.options.GetEmitDeclarations()) {
			return options;
		}
		final canUseIncrementalState = this.program.snapshot.canUseIncrementalState();
		final result = new EmitOptions();
		result.TargetSourceFile = options.TargetSourceFile;
		result.EmitOnly = options.EmitOnly;
		result.WriteFile = function(fileName:std.String, text:std.String, data:WriteFileData):Null<Error> {
			final differsOnlyInMap = new BoolRef(); // PORT: pointer
			if (Tspath.IsDeclarationFileName(fileName)) {
				if (canUseIncrementalState) {
					var emitSignature = "";
					final info = this.program.snapshot.fileInfos.Load(options.TargetSourceFile.Path()).value;
					if (info.signature == info.version) {
						final signature = this.program.snapshot.computeSignatureWithDiagnostics(options.TargetSourceFile, text, data);
						// With d.ts diagnostics they are also part of the signature so emitSignature will be different from it since its just hash of d.ts
						if (Core.len(data.Diagnostics) == 0) {
							emitSignature = signature;
						}
						if (signature != info.version) { // Update it
							this.signatures.Store(options.TargetSourceFile.Path(), signature);
						}
					}

					// Store d.ts emit hash so later can be compared to check if d.ts has changed.
					// Currently we do this only for composite projects since these are the only projects that can be referenced by other projects
					// and would need their d.ts change time in --build mode
					if (this.skipDtsOutputOfComposite(options.TargetSourceFile, fileName, text, data, emitSignature, differsOnlyInMap)) {
						return null;
					}
				}
			}

			var aTime = Time.Zero();
			if (differsOnlyInMap.value) {
				aTime = this.program.host.GetMTime(fileName);
			}
			var err:Null<Error>;
			if (options.WriteFile != null) {
				err = options.WriteFile(fileName, text, data);
			} else {
				err = this.program.program.Host().FS().WriteFile(fileName, text);
			}
			if (err == null && differsOnlyInMap.value) {
				// Revert the time to original one
				err = this.program.host.SetMTime(fileName, aTime);
			}
			return err;
		};
		return result;
	}

	// Compare to existing computed signature and store it or handle the changes in d.ts map option from before
	// returning undefined means that, we dont need to emit this d.ts file since its contents didnt change
	function skipDtsOutputOfComposite(file:SourceFile, outputFileName:std.String, text:std.String, data:WriteFileData, newSignature:std.String,
			differsOnlyInMap:BoolRef):Bool {
		if (!this.program.snapshot.options.Composite.IsTrue()) {
			return false;
		}
		var oldSignature = "";
		final r = this.program.snapshot.emitSignatures.Load(file.Path());
		final oldSignatureFormat = r.value;
		if (r.ok) {
			if (oldSignatureFormat.signature != "") {
				oldSignature = oldSignatureFormat.signature;
			} else {
				oldSignature = oldSignatureFormat.signatureWithDifferentOptions[0];
			}
		}
		if (newSignature == "") {
			newSignature = this.program.snapshot.computeHash(Incremental.getTextHandlingSourceMapForSignature(text, data));
		}
		// Dont write dts files if they didn't change
		if (newSignature == oldSignature) {
			// If the signature was encoded as string the dts map options match so nothing to do
			if (oldSignatureFormat != null && oldSignatureFormat.signature == oldSignature) {
				data.SkippedDtsWrite = true;
				return true;
			} else {
				// Mark as differsOnlyInMap so that we can reverse the timestamp with --build so that
				// the downstream projects dont detect this as change in d.ts file
				differsOnlyInMap.value = this.program.Options().Build.IsTrue();
			}
		} else {
			this.latestChangedDtsFiles.Store(file.Path(), outputFileName);
		}
		this.emitSignatures.Store(file.Path(), new EmitSignature(newSignature));
		return false;
	}

	function updateSnapshot():Array<EmitResult> {
		if (this.program.snapshot.canUseIncrementalState()) {
			this.signatures.Range(function(file:Path, signature:std.String):Bool {
				final info = this.program.snapshot.fileInfos.Load(file).value;
				info.signature = signature;
				if (this.program.testingData != null) {
					this.program.testingData.UpdatedSignatureKinds.set(file, SignatureUpdateKindStoredAtEmit);
				}
				this.program.snapshot.buildInfoEmitPending = true;
				return true;
			});
			this.emitSignatures.Range(function(file:Path, signature:EmitSignature):Bool {
				this.program.snapshot.emitSignatures.Store(file, signature);
				this.program.snapshot.buildInfoEmitPending = true;
				return true;
			});
			for (file in this.deletedPendingKinds.Keys().keys()) {
				this.program.snapshot.affectedFilesPendingEmit.Delete(file);
				this.program.snapshot.buildInfoEmitPending = true;
			}
			// Always use correct order when to collect the result
			var results:Array<EmitResult> = null;
			for (file in this.program.GetSourceFiles()) {
				final latest = this.latestChangedDtsFiles.Load(file.Path());
				if (latest.ok) {
					this.program.snapshot.latestChangedDtsFile = latest.value;
					this.program.snapshot.buildInfoEmitPending = true;
					this.program.snapshot.hasChangedDtsFile = true;
				}
				final u = this.emitUpdates.Load(file.Path());
				if (u.ok) {
					final update = u.value;
					if (!update.dtsErrorsFromCache) {
						if (update.pendingKind == 0) {
							this.program.snapshot.affectedFilesPendingEmit.Delete(file.Path());
						} else {
							this.program.snapshot.affectedFilesPendingEmit.Store(file.Path(), update.pendingKind);
						}
						this.program.snapshot.buildInfoEmitPending = true;
					}
					if (update.result != null) {
						if (results == null)
							results = [];
						results.push(update.result);
						if (Core.len(update.result.Diagnostics) != 0) {
							this.program.snapshot.emitDiagnosticsPerFile.Store(file.Path(),
								new DiagnosticsOrBuildInfoDiagnosticsWithFileName(update.result.Diagnostics));
						}
					}
				}
			}
			return results;
		} else if (this.hasEmitDiagnostics) {
			this.program.snapshot.hasEmitDiagnostics = true;
		}
		return null;
	}
}

// PORT: pointer — Go `*bool` out parameter of skipDtsOutputOfComposite.
class BoolRef {
	public var value:Bool = false;

	public function new() {}
}
