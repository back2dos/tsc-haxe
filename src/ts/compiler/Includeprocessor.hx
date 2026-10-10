package ts.compiler;

// Port of includeprocessor.go.

@:allow(ts.compiler)
class IncludeProcessor {
	var fileIncludeReasons:StringMap<Array<FileIncludeReason>> = null;
	var processingDiagnostics:Array<ProcessingDiagnostic> = null;

	var reasonToReferenceLocation:SyncMap<FileIncludeReason, ReferenceFileLocation> = new SyncMap<FileIncludeReason, ReferenceFileLocation>();
	var includeReasonToRelatedInfo:SyncMap<FileIncludeReason, Diagnostic> = new SyncMap<FileIncludeReason, Diagnostic>();
	var redirectAndFileFormat:StringMap<Array<Diagnostic>> = new StringMap(); // PORT: SyncMap[tspath.Path, ...] → StringMap
	var computedDiagnostics:DiagnosticsCollection = null;
	var computedDiagnosticsOnce:Bool = false; // PORT: sync.Once → flag
	var compilerOptionsSyntax:ObjectLiteralExpression = null;
	var compilerOptionsSyntaxOnce:Bool = false; // PORT: sync.Once → flag

	public function new() {}

	function getDiagnostics(p:Program):DiagnosticsCollection {
		if (!this.computedDiagnosticsOnce) {
			this.computedDiagnosticsOnce = true;
			this.computedDiagnostics = new DiagnosticsCollection();
			if (this.processingDiagnostics != null) {
				for (d in this.processingDiagnostics) {
					this.computedDiagnostics.Add(d.toDiagnostic(p));
				}
			}
			// PORT: Go map iteration order is random; DiagnosticsCollection sorts its contents.
			for (resolutions in p.resolvedModules) {
				if (resolutions == null)
					continue;
				for (resolvedModule in resolutions) {
					if (resolvedModule.ResolutionDiagnostics != null) {
						for (diag in resolvedModule.ResolutionDiagnostics) {
							this.computedDiagnostics.Add(diag);
						}
					}
				}
			}
			for (typeResolutions in p.typeResolutionsInFile) {
				if (typeResolutions == null)
					continue;
				for (resolvedTypeRef in typeResolutions) {
					if (resolvedTypeRef.ResolutionDiagnostics != null) {
						for (diag in resolvedTypeRef.ResolutionDiagnostics) {
							this.computedDiagnostics.Add(diag);
						}
					}
				}
			}
		}
		return this.computedDiagnostics;
	}

	function addProcessingDiagnostic(...d:ProcessingDiagnostic):Void {
		if (this.processingDiagnostics == null)
			this.processingDiagnostics = [];
		for (x in d)
			this.processingDiagnostics.push(x);
	}

	function addProcessingDiagnosticsForFileCasing(file:Path, existingCasing:std.String, currentCasing:std.String, reason:FileIncludeReason):Void {
		if (!reason.isReferencedFile()
			&& Slices.ContainsFunc(this.fileIncludeReasons.get(file), function(r:FileIncludeReason) return r.isReferencedFile())) {
			this.addProcessingDiagnostic(new ProcessingDiagnostic(processingDiagnosticKindExplainingFileInclude,
				new IncludeExplainingDiagnostic(file, reason, Diagnostics.Already_included_file_name_0_differs_from_file_name_1_only_in_casing, [existingCasing, currentCasing])));
		} else {
			this.addProcessingDiagnostic(new ProcessingDiagnostic(processingDiagnosticKindExplainingFileInclude,
				new IncludeExplainingDiagnostic(file, reason, Diagnostics.File_name_0_differs_from_already_included_file_name_1_only_in_casing, [currentCasing, existingCasing])));
		}
	}

	function getReferenceLocation(r:FileIncludeReason, program:Program):ReferenceFileLocation {
		final existing = this.reasonToReferenceLocation.Load(r);
		if (existing.ok) {
			return existing.value;
		}

		final loc = this.reasonToReferenceLocation.LoadOrStore(r, r.getReferencedLocation(program)).value;
		return loc;
	}

	function getCompilerOptionsObjectLiteralSyntax(program:Program):ObjectLiteralExpression {
		if (!this.compilerOptionsSyntaxOnce) {
			this.compilerOptionsSyntaxOnce = true;
			final configFile = program.opts.Config.ConfigFile;
			if (configFile != null) {
				final compilerOptionsProperty = Tsoptions.ForEachTsConfigPropArray(configFile.SourceFile, "compilerOptions", Core.Identity);
				if (compilerOptionsProperty != null
					&& compilerOptionsProperty.Initializer != null
					&& Ast.IsObjectLiteralExpression(compilerOptionsProperty.Initializer)) {
					this.compilerOptionsSyntax = compilerOptionsProperty.Initializer.AsObjectLiteralExpression();
				}
			} else {
				this.compilerOptionsSyntax = null;
			}
		}
		return this.compilerOptionsSyntax;
	}

	function getRelatedInfo(r:FileIncludeReason, program:Program):Diagnostic {
		final existing = this.includeReasonToRelatedInfo.Load(r);
		if (existing.ok) {
			return existing.value;
		}

		final relatedInfo = this.includeReasonToRelatedInfo.LoadOrStore(r, r.toRelatedInfo(program)).value;
		return relatedInfo;
	}

	function explainRedirectAndImpliedFormat(program:Program, filePath:Path, toFileName:(fileName:std.String) -> std.String):Array<Diagnostic> {
		if (this.redirectAndFileFormat.exists(filePath)) {
			return this.redirectAndFileFormat.get(filePath);
		}
		var file:HasFileName = null;
		var sourceFile:SourceFile = null;
		final redirectsFile = program.redirectFilesByPath == null ? null : program.redirectFilesByPath.get(filePath);
		if (redirectsFile != null) {
			file = redirectsFile;
		} else {
			sourceFile = program.GetSourceFileByPath(filePath);
			if (sourceFile == null) {
				return null;
			}
			file = ts.modulespecifiers.Types.SourceFileAdapter.Of(sourceFile);
		}
		var result:Array<Diagnostic> = null;
		final source = program.GetSourceOfProjectReferenceIfOutputIncluded(file);
		if (source != file.FileName()) {
			if (result == null)
				result = [];
			result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_is_output_of_project_reference_source_0, toFileName(source)));
		}

		if (redirectsFile != null) {
			final targetFile = program.GetSourceFileByPath(redirectsFile.target);
			if (result == null)
				result = [];
			result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_redirects_to_file_0, toFileName(targetFile.FileName())));
		}

		if (sourceFile != null && Ast.IsExternalOrCommonJSModule(sourceFile)) {
			final metaData = program.GetSourceFileMetaData(file.Path());
			final format = program.GetImpliedNodeFormatForEmit(file);
			if (format == ModuleKindESNext) {
				if (metaData.PackageJsonType == "module") {
					if (result == null)
						result = [];
					result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_is_ECMAScript_module_because_0_has_field_type_with_value_module,
						toFileName(metaData.PackageJsonDirectory + "/package.json")));
				}
			} else if (format == ModuleKindCommonJS) {
				if (metaData.PackageJsonType != "") {
					if (result == null)
						result = [];
					result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_is_CommonJS_module_because_0_has_field_type_whose_value_is_not_module,
						toFileName(metaData.PackageJsonDirectory + "/package.json")));
				} else if (metaData.PackageJsonDirectory != "") {
					if (metaData.PackageJsonType == "") {
						if (result == null)
							result = [];
						result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_is_CommonJS_module_because_0_does_not_have_field_type,
							toFileName(metaData.PackageJsonDirectory + "/package.json")));
					}
				} else {
					if (result == null)
						result = [];
					result.push(Ast.NewCompilerDiagnostic(Diagnostics.File_is_CommonJS_module_because_package_json_was_not_found));
				}
			}
		}

		// result, _ = i.redirectAndFileFormat.LoadOrStore(filePath, result)
		this.redirectAndFileFormat.set(filePath, result);
		return result;
	}
}
