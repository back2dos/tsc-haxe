package ts.execute.incremental;

// Port of buildinfotosnapshot.go (types and methods). Package-level funcs are in Incremental.hx.

// Go type toSnapshot.
@:allow(ts.execute.incremental)
class ToSnapshot {
	var buildInfo:BuildInfo = null;
	var buildInfoDirectory:std.String = "";
	var snapshot:Snapshot = new Snapshot();
	var filePaths:Array<Path> = null;
	var filePathSet:Array<Set<Path>> = null;

	public function new() {}

	function toAbsolutePath(path:std.String):std.String {
		return Tspath.GetNormalizedAbsolutePath(path, this.buildInfoDirectory);
	}

	function toFilePath(fileId:BuildInfoFileId):Path {
		return this.filePaths[fileId - 1];
	}

	function toFilePathSet(fileIdListId:BuildInfoFileIdListId):Set<Path> {
		return this.filePathSet[fileIdListId - 1];
	}

	function toBuildInfoDiagnosticsWithFileName(diagnostics:Array<BuildInfoDiagnostic>):Array<BuildInfoDiagnosticWithFileName> {
		return Core.Map(diagnostics, function(d:BuildInfoDiagnostic):BuildInfoDiagnosticWithFileName {
			var file:Path = "";
			if (d.File != 0) {
				file = this.toFilePath(d.File);
			}
			final r = new BuildInfoDiagnosticWithFileName();
			r.file = file;
			r.noFile = d.NoFile;
			r.pos = d.Pos;
			r.end = d.End;
			r.code = d.Code;
			r.category = d.Category;
			r.messageKey = d.MessageKey;
			r.messageArgs = d.MessageArgs;
			r.messageChain = this.toBuildInfoDiagnosticsWithFileName(d.MessageChain);
			r.relatedInformation = this.toBuildInfoDiagnosticsWithFileName(d.RelatedInformation);
			r.reportsUnnecessary = d.ReportsUnnecessary;
			r.reportsDeprecated = d.ReportsDeprecated;
			r.skippedOnNoEmit = d.SkippedOnNoEmit;
			r.repopulateInfo = Incremental.fromBuildInfoRepopulateInfo(d.RepopulateInfo);
			return r;
		});
	}

	function toDiagnosticsOrBuildInfoDiagnosticsWithFileName(dig:BuildInfoDiagnosticsOfFile):DiagnosticsOrBuildInfoDiagnosticsWithFileName {
		return new DiagnosticsOrBuildInfoDiagnosticsWithFileName(null, this.toBuildInfoDiagnosticsWithFileName(dig.Diagnostics));
	}

	function setCompilerOptions():Void {
		this.snapshot.options = this.buildInfo.GetCompilerOptions(this.buildInfoDirectory);
	}

	function setFileInfoAndEmitSignatures():Void {
		final isComposite = this.snapshot.options.Composite.IsTrue();
		if (this.buildInfo.FileInfos != null) {
			for (index in 0...this.buildInfo.FileInfos.length) {
				final buildInfoFileInfo = this.buildInfo.FileInfos[index];
				final path = this.toFilePath(index + 1);
				final info = buildInfoFileInfo.GetFileInfo();
				this.snapshot.fileInfos.Store(path, info);
				// Add default emit signature as file's signature
				if (info.signature != "" && isComposite) {
					this.snapshot.emitSignatures.Store(path, new EmitSignature(info.signature));
				}
			}
		}
		// Fix up emit signatures
		for (value in this.buildInfo.EmitSignatures) {
			if (value.noEmitSignature()) {
				this.snapshot.emitSignatures.Delete(this.toFilePath(value.FileId));
			} else {
				final path = this.toFilePath(value.FileId);
				this.snapshot.emitSignatures.Store(path, value.toEmitSignature(path, this.snapshot.emitSignatures));
			}
		}
	}

	function setReferencedMap():Void {
		for (entry in this.buildInfo.ReferencedMap) {
			this.snapshot.referencedMap.storeReferences(this.toFilePath(entry.FileId), this.toFilePathSet(entry.FileIdListId));
		}
	}

	function setChangeFileSet():Void {
		for (fileId in this.buildInfo.ChangeFileSet) {
			final filePath = this.toFilePath(fileId);
			this.snapshot.changedFilesSet.Add(filePath);
		}
	}

	function setSemanticDiagnostics():Void {
		this.snapshot.fileInfos.Range(function(path:Path, info:FileInfo):Bool {
			// Initialize to have no diagnostics if its not changed file
			if (!this.snapshot.changedFilesSet.Has(path)) {
				this.snapshot.semanticDiagnosticsPerFile.Store(path, new DiagnosticsOrBuildInfoDiagnosticsWithFileName());
			}
			return true;
		});
		for (diagnostic in this.buildInfo.SemanticDiagnosticsPerFile) {
			if (diagnostic.FileId != 0) {
				final filePath = this.toFilePath(diagnostic.FileId);
				this.snapshot.semanticDiagnosticsPerFile.Delete(filePath); // does not have cached diagnostics
			} else {
				final filePath = this.toFilePath(diagnostic.Diagnostics.FileId);
				this.snapshot.semanticDiagnosticsPerFile.Store(filePath, this.toDiagnosticsOrBuildInfoDiagnosticsWithFileName(diagnostic.Diagnostics));
			}
		}
	}

	function setEmitDiagnostics():Void {
		for (diagnostic in this.buildInfo.EmitDiagnosticsPerFile) {
			final filePath = this.toFilePath(diagnostic.FileId);
			this.snapshot.emitDiagnosticsPerFile.Store(filePath, this.toDiagnosticsOrBuildInfoDiagnosticsWithFileName(diagnostic));
		}
	}

	function setAffectedFilesPendingEmit():Void {
		if (Core.len(this.buildInfo.AffectedFilesPendingEmit) == 0) {
			return;
		}
		final ownOptionsEmitKind = Incremental.GetFileEmitKind(this.snapshot.options);
		for (pendingEmit in this.buildInfo.AffectedFilesPendingEmit) {
			this.snapshot.affectedFilesPendingEmit.Store(this.toFilePath(pendingEmit.FileId),
				Core.IfElse(pendingEmit.EmitKind == 0, ownOptionsEmitKind, pendingEmit.EmitKind));
		}
	}

	function setPackageJsons():Void {
		if (this.buildInfo.PackageJsons != null) {
			this.snapshot.packageJsons = Core.Map(this.buildInfo.PackageJsons, this.toAbsolutePath);
		} else {
			this.snapshot.packageJsons = [];
		}
		if (this.buildInfo.MissingPackageJsons != null) {
			this.snapshot.missingPackageJsons = Core.Map(this.buildInfo.MissingPackageJsons, this.toAbsolutePath);
		} else {
			this.snapshot.missingPackageJsons = [];
		}
	}
}
