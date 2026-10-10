package ts.execute.incremental;

// Port of snapshottobuildinfo.go (types and methods). Package-level funcs are in Incremental.hx.

// Go type toBuildInfo.
@:allow(ts.execute.incremental)
class ToBuildInfo {
	var snapshot:Snapshot = null;
	var program:CompilerProgram = null;
	var buildInfo:BuildInfo = null;
	var buildInfoDirectory:std.String = "";
	var comparePathsOptions:ComparePathsOptions = null;
	var fileNameToFileId:StringMap<BuildInfoFileId> = new StringMap();
	var fileNamesToFileIdListId:StringMap<BuildInfoFileIdListId> = new StringMap();
	var roots:ObjectMap<SourceFile, Path> = new ObjectMap();

	public function new() {}

	function relativeToBuildInfo(path:std.String):std.String {
		return Tspath.EnsurePathIsNonModuleName(Tspath.GetRelativePathFromDirectory(this.buildInfoDirectory, path, this.comparePathsOptions));
	}

	function toFileId(path:Path):BuildInfoFileId {
		var fileId:BuildInfoFileId = this.fileNameToFileId.exists(path) ? this.fileNameToFileId.get(path) : 0;
		if (fileId == 0) {
			final libFile = this.program.GetDefaultLibFile(path);
			if (this.buildInfo.FileNames == null)
				this.buildInfo.FileNames = [];
			if (libFile != null && !libFile.Replaced) {
				this.buildInfo.FileNames.push(libFile.Name);
			} else {
				this.buildInfo.FileNames.push(this.relativeToBuildInfo(path));
			}
			fileId = this.buildInfo.FileNames.length;
			this.fileNameToFileId.set(path, fileId);
		}
		return fileId;
	}

	function toFileIdListId(set:Set<Path>):BuildInfoFileIdListId {
		final fileIds = Core.Map(Slices.Collect(set.Keys().keys()), this.toFileId);
		Slices.SortInts(fileIds);
		final key = Core.Map(fileIds, function(id:BuildInfoFileId):std.String {
			return Std.string(id);
		}).join(",");

		var fileIdListId:BuildInfoFileIdListId = this.fileNamesToFileIdListId.exists(key) ? this.fileNamesToFileIdListId.get(key) : 0;
		if (fileIdListId == 0) {
			if (this.buildInfo.FileIdsList == null)
				this.buildInfo.FileIdsList = [];
			this.buildInfo.FileIdsList.push(fileIds);
			fileIdListId = this.buildInfo.FileIdsList.length;
			this.fileNamesToFileIdListId.set(key, fileIdListId);
		}
		return fileIdListId;
	}

	// PORT: Go `v.([]string)` / `v.(string)` on the reflect value; `isStrings` tells whether the
	// field is a []string (compilerOptionsFields kind).
	function toRelativeToBuildInfoCompilerOptionValue(option:CommandLineOption, v:Dynamic, isStrings:Bool):Dynamic {
		if (option.Kind == CommandLineOptionTypeList) {
			if (option.Elements().IsFilePath) {
				if (isStrings && v != null) {
					return Core.Map((v : Array<std.String>), this.relativeToBuildInfo);
				}
			}
		} else if (option.IsFilePath) {
			if (Std.isOfType(v, std.String) && (v : std.String) != "") {
				return this.relativeToBuildInfo(v);
			}
		}
		return v;
	}

	function toBuildInfoDiagnosticsFromFileNameDiagnostics(diagnostics:Array<BuildInfoDiagnosticWithFileName>):Array<BuildInfoDiagnostic> {
		return Core.Map(diagnostics, function(d:BuildInfoDiagnosticWithFileName):BuildInfoDiagnostic {
			var file:BuildInfoFileId = 0;
			if (d.file != "") {
				file = this.toFileId(d.file);
			}
			final r = new BuildInfoDiagnostic();
			r.File = file;
			r.NoFile = d.noFile;
			r.Pos = d.pos;
			r.End = d.end;
			r.Code = d.code;
			r.Category = d.category;
			r.MessageKey = d.messageKey;
			r.MessageArgs = d.messageArgs;
			r.MessageChain = this.toBuildInfoDiagnosticsFromFileNameDiagnostics(d.messageChain);
			r.RelatedInformation = this.toBuildInfoDiagnosticsFromFileNameDiagnostics(d.relatedInformation);
			r.ReportsUnnecessary = d.reportsUnnecessary;
			r.ReportsDeprecated = d.reportsDeprecated;
			r.SkippedOnNoEmit = d.skippedOnNoEmit;
			r.RepopulateInfo = Incremental.toBuildInfoRepopulateInfo(d.repopulateInfo);
			return r;
		});
	}

	function toBuildInfoDiagnosticsFromDiagnostics(filePath:Path, diagnostics:Array<Diagnostic>):Array<BuildInfoDiagnostic> {
		return Core.Map(diagnostics, function(d:Diagnostic):BuildInfoDiagnostic {
			var file:BuildInfoFileId = 0;
			var noFile = false;
			if (d.File() == null) {
				noFile = true;
			} else if (d.File().Path() != filePath) {
				file = this.toFileId(d.File().Path());
			}
			final r = new BuildInfoDiagnostic();
			r.File = file;
			r.NoFile = noFile;
			r.Pos = d.Loc().Pos();
			r.End = d.Loc().End();
			r.Code = d.Code();
			r.Category = d.Category();
			r.MessageKey = d.MessageKey();
			r.MessageArgs = d.MessageArgs();
			r.MessageChain = this.toBuildInfoDiagnosticsFromDiagnostics(filePath, d.MessageChain());
			r.RelatedInformation = this.toBuildInfoDiagnosticsFromDiagnostics(filePath, d.RelatedInformation());
			r.ReportsUnnecessary = d.ReportsUnnecessary();
			r.ReportsDeprecated = d.ReportsDeprecated();
			r.SkippedOnNoEmit = d.SkippedOnNoEmit();
			r.RepopulateInfo = Incremental.toBuildInfoRepopulateInfo(d.RepopulateInfo());
			return r;
		});
	}

	function toBuildInfoDiagnosticsOfFile(filePath:Path, diags:DiagnosticsOrBuildInfoDiagnosticsWithFileName):BuildInfoDiagnosticsOfFile {
		if (Core.len(diags.diagnostics) > 0) {
			return new BuildInfoDiagnosticsOfFile(this.toFileId(filePath), this.toBuildInfoDiagnosticsFromDiagnostics(filePath, diags.diagnostics));
		}
		if (Core.len(diags.buildInfoDiagnostics) > 0) {
			return new BuildInfoDiagnosticsOfFile(this.toFileId(filePath), this.toBuildInfoDiagnosticsFromFileNameDiagnostics(diags.buildInfoDiagnostics));
		}
		return null;
	}

	function collectRootFiles():Void {
		for (fileName in this.program.CommandLine().FileNames()) {
			var file:SourceFile;
			final redirect = this.program.GetParseFileRedirect(fileName);
			if (redirect != "") {
				file = this.program.GetSourceFile(redirect);
			} else {
				file = this.program.GetSourceFile(fileName);
			}
			if (file != null) {
				this.roots.set(file, Tspath.ToPath(fileName, this.comparePathsOptions.CurrentDirectory, this.comparePathsOptions.UseCaseSensitiveFileNames));
			}
		}
	}

	function setFileInfoAndEmitSignatures():Void {
		this.buildInfo.FileInfos = Core.Map(this.program.GetSourceFiles(), function(file:SourceFile):BuildInfoFileInfo {
			final info = this.snapshot.fileInfos.Load(file.Path()).value;
			final fileId = this.toFileId(file.Path());
			//  tryAddRoot(key, fileId);
			if (this.buildInfo.FileNames[fileId - 1] != this.relativeToBuildInfo(file.Path())) {
				final libFile = this.program.GetDefaultLibFile(file.Path());
				if (libFile == null || libFile.Replaced || this.buildInfo.FileNames[fileId - 1] != libFile.Name) {
					throw Fmt.Sprintf("File name at index %d does not match expected relative path or libName: %s != %s",
						[fileId - 1, this.buildInfo.FileNames[fileId - 1], this.relativeToBuildInfo(file.Path())]);
				}
			}
			if (this.snapshot.options.Composite.IsTrue()) {
				if (!Ast.IsJsonSourceFile(file) && this.program.SourceFileMayBeEmitted(file, false)) {
					final loaded = this.snapshot.emitSignatures.Load(file.Path());
					if (this.buildInfo.EmitSignatures == null)
						this.buildInfo.EmitSignatures = [];
					if (!loaded.ok) {
						this.buildInfo.EmitSignatures.push(new BuildInfoEmitSignature(fileId));
					} else if (loaded.value.signature != info.signature) {
						final emitSignature = loaded.value;
						final incrementalEmitSignature = new BuildInfoEmitSignature(fileId);
						if (emitSignature.signature != "") {
							incrementalEmitSignature.Signature = emitSignature.signature;
						} else if (emitSignature.signatureWithDifferentOptions[0] == info.signature) {
							incrementalEmitSignature.DiffersOnlyInDtsMap = true;
						} else {
							incrementalEmitSignature.Signature = emitSignature.signatureWithDifferentOptions[0];
							incrementalEmitSignature.DiffersInOptions = true;
						}
						this.buildInfo.EmitSignatures.push(incrementalEmitSignature);
					}
					if (this.buildInfo.EmitSignatures.length == 0)
						this.buildInfo.EmitSignatures = null; // PORT: Go append on nil only allocates when something is added
				}
			}
			return Incremental.newBuildInfoFileInfo(info);
		});
	}

	function setRootOfIncrementalProgram():Void {
		final keys:Array<SourceFile> = [for (k in this.roots.keys()) k];
		Slices.SortFunc(keys, function(a:SourceFile, b:SourceFile):Int {
			return this.toFileId(a.Path()) - this.toFileId(b.Path());
		});
		for (file in keys) {
			final root = this.toFileId(this.roots.get(file));
			final resolved = this.toFileId(file.Path());
			if (this.buildInfo.Root == null) {
				// First fileId as is
				this.buildInfo.Root = [new BuildInfoRoot(resolved)];
			} else {
				final last = this.buildInfo.Root[this.buildInfo.Root.length - 1];
				if (last.End == resolved - 1) {
					// If its [..., last = [start, end = fileId - 1]], update last to [start, fileId]
					last.End = resolved;
				} else if (last.End == 0 && last.Start == resolved - 1) {
					// If its [..., last = start = fileId - 1 ], update last to [start, fileId]
					last.End = resolved;
				} else {
					this.buildInfo.Root.push(new BuildInfoRoot(resolved));
				}
			}
			if (root != resolved) {
				if (this.buildInfo.ResolvedRoot == null)
					this.buildInfo.ResolvedRoot = [];
				this.buildInfo.ResolvedRoot.push(new BuildInfoResolvedRoot(resolved, root));
			}
		}
	}

	function setCompilerOptions():Void {
		final fields = @:privateAccess Tsoptions.compilerOptionsFields;
		Tsoptions.ForEachCompilerOptionValue(this.snapshot.options, function(option:CommandLineOption):Bool {
			return option.AffectsBuildInfo;
		}, function(option:CommandLineOption, value:Dynamic, i:Int):Bool {
			final field = fields[i];
			if (field.IsZero(value)) {
				return false;
			}
			// Make it relative to buildInfo directory if file path
			if (this.buildInfo.Options == null) {
				this.buildInfo.Options = new OrderedMap<std.String, Dynamic>();
			}
			this.buildInfo.Options.Set(option.Name,
				this.toRelativeToBuildInfoCompilerOptionValue(option, Incremental.optionValueForJSON(field, value), field.Kind == CompilerOptionsFieldKind.FieldStrings));
			return false;
		});
	}

	function setReferencedMap():Void {
		final keys = this.snapshot.referencedMap.getPathsWithReferences();
		Slices.SortStrings(cast keys);
		this.buildInfo.ReferencedMap = Core.Map(keys, function(filePath:Path):BuildInfoReferenceMapEntry {
			final references = this.snapshot.referencedMap.getReferences(filePath).value;
			// PORT: Go evaluates the struct literal fields in order (toFileId before toFileIdListId).
			final fileId = this.toFileId(filePath);
			return new BuildInfoReferenceMapEntry(fileId, this.toFileIdListId(references));
		});
	}

	function setChangeFileSet():Void {
		final files = Slices.Collect(this.snapshot.changedFilesSet.Keys());
		Slices.SortStrings(cast files);
		this.buildInfo.ChangeFileSet = Core.Map(files, this.toFileId);
	}

	function setSemanticDiagnostics():Void {
		for (file in this.program.GetSourceFiles()) {
			final r = this.snapshot.semanticDiagnosticsPerFile.Load(file.Path());
			if (!r.ok) {
				if (!this.snapshot.changedFilesSet.Has(file.Path())) {
					if (this.buildInfo.SemanticDiagnosticsPerFile == null)
						this.buildInfo.SemanticDiagnosticsPerFile = [];
					this.buildInfo.SemanticDiagnosticsPerFile.push(new BuildInfoSemanticDiagnostic(this.toFileId(file.Path())));
				}
			} else {
				final diagnostics = this.toBuildInfoDiagnosticsOfFile(file.Path(), r.value);
				if (diagnostics != null) {
					if (this.buildInfo.SemanticDiagnosticsPerFile == null)
						this.buildInfo.SemanticDiagnosticsPerFile = [];
					this.buildInfo.SemanticDiagnosticsPerFile.push(new BuildInfoSemanticDiagnostic(0, diagnostics));
				}
			}
		}
	}

	function setEmitDiagnostics():Void {
		final files = Slices.Collect(this.snapshot.emitDiagnosticsPerFile.Keys());
		Slices.SortStrings(cast files);
		this.buildInfo.EmitDiagnosticsPerFile = Core.Map(files, function(filePath:Path):BuildInfoDiagnosticsOfFile {
			final value = this.snapshot.emitDiagnosticsPerFile.Load(filePath).value;
			return this.toBuildInfoDiagnosticsOfFile(filePath, value);
		});
	}

	function setAffectedFilesPendingEmit():Void {
		final files = Slices.Collect(this.snapshot.affectedFilesPendingEmit.Keys());
		Slices.SortStrings(cast files);
		final fullEmitKind = Incremental.GetFileEmitKind(this.snapshot.options);
		for (filePath in files) {
			final file = this.program.GetSourceFileByPath(filePath);
			if (file == null || !this.program.SourceFileMayBeEmitted(file, false)) {
				continue;
			}
			final pendingEmit = this.snapshot.affectedFilesPendingEmit.Load(filePath).value;
			if (this.buildInfo.AffectedFilesPendingEmit == null)
				this.buildInfo.AffectedFilesPendingEmit = [];
			this.buildInfo.AffectedFilesPendingEmit.push(new BuildInfoFilePendingEmit(this.toFileId(filePath),
				Core.IfElse(pendingEmit == fullEmitKind, FileEmitKindNone, pendingEmit)));
		}
	}

	function setRootOfNonIncrementalProgram():Void {
		this.buildInfo.Root = Core.Map(this.program.CommandLine().FileNames(), function(fileName:std.String):BuildInfoRoot {
			return new BuildInfoRoot(0, 0,
				this.relativeToBuildInfo(Tspath.ToPath(fileName, this.comparePathsOptions.CurrentDirectory, this.comparePathsOptions.UseCaseSensitiveFileNames)));
		});
	}

	function setPackageJsons():Void {
		if (Core.len(this.snapshot.packageJsons) > 0) {
			this.buildInfo.PackageJsons = Core.Map(this.snapshot.packageJsons, this.relativeToBuildInfo);
		}
		if (Core.len(this.snapshot.missingPackageJsons) > 0) {
			this.buildInfo.MissingPackageJsons = Core.Map(this.snapshot.missingPackageJsons, this.relativeToBuildInfo);
		}
	}
}
