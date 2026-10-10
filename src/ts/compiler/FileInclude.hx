package ts.compiler;

import ts.diagnostics.Diagnostics.Message;

// Port of fileInclude.go.

// Go unexported type fileIncludeKind.
enum abstract FileIncludeKind(Int) from Int to Int {
	// References from file
	var fileIncludeKindImport = 0;
	var fileIncludeKindReferenceFile = 1;
	var fileIncludeKindTypeReferenceDirective = 2;
	var fileIncludeKindLibReferenceDirective = 3;

	var fileIncludeKindRootFile = 4;
	var fileIncludeKindLibFile = 5;
	var fileIncludeKindAutomaticTypeDirectiveFile = 6;
}

@:allow(ts.compiler)
class FileIncludeReason {
	var kind:FileIncludeKind = 0;
	// PORT: Go `any`: Int (root file / lib file index), ReferencedFileData, AutomaticTypeDirectiveFileData or null.
	var data:Any = null;

	// Uses relative file name
	var relativeFileNameDiag:Diagnostic = null;
	var relativeFileNameDiagOnce:Bool = false; // PORT: sync.Once → flag

	// Uses file name as is
	var diag:Diagnostic = null;
	var diagOnce:Bool = false; // PORT: sync.Once → flag

	public function new(kind:FileIncludeKind = 0, data:Any = null) {
		this.kind = kind;
		this.data = data;
	}

	function asIndex():Int {
		return (this.data : Int);
	}

	// PORT: (int, bool) → ValueOk
	function asLibFileIndex():ValueOk<Int> {
		if (this.data != null && Std.isOfType(this.data, Int)) {
			return new ValueOk((this.data : Int), true);
		}
		return new ValueOk(0, false);
	}

	// PORT: nil receiver allowed (Go checks r != nil): inline, so a null reason works like Go's nil.
	inline function isReferencedFile():Bool {
		return this != null && (this.kind : Int) <= (fileIncludeKindLibReferenceDirective : Int);
	}

	function asReferencedFileData():ReferencedFileData {
		return (this.data : ReferencedFileData);
	}

	function asAutomaticTypeDirectiveFileData():AutomaticTypeDirectiveFileData {
		return (this.data : AutomaticTypeDirectiveFileData);
	}

	function getReferencedLocation(program:Program):ReferenceFileLocation {
		final ref = this.asReferencedFileData();
		final file = program.GetSourceFileByPath(ref.file);
		switch (this.kind) {
			case fileIncludeKindImport:
				var specifier:Node = null;
				var isSynthetic = false;
				if (ref.synthetic != null) {
					specifier = ref.synthetic;
					isSynthetic = true;
				} else if (ref.index < file.Imports().length) {
					specifier = file.Imports()[ref.index];
				} else {
					var augIndex = file.Imports().length;
					if (file.ModuleAugmentations != null) {
						for (imp in file.ModuleAugmentations) {
							if (imp.Kind == KindStringLiteral) {
								if (augIndex == ref.index) {
									specifier = imp;
									break;
								}
								augIndex++;
							}
						}
					}
				}
				final resolution = program.GetResolvedModuleFromModuleSpecifier(ts.modulespecifiers.Types.SourceFileAdapter.Of(file), specifier);
				final loc = new ReferenceFileLocation();
				loc.file = file;
				loc.node = specifier;
				loc.packageId = resolution.PackageId;
				loc.isSynthetic = isSynthetic;
				return loc;
			case fileIncludeKindReferenceFile:
				final loc = new ReferenceFileLocation();
				loc.file = file;
				loc.ref = file.ReferencedFiles[ref.index];
				return loc;
			case fileIncludeKindTypeReferenceDirective:
				final loc = new ReferenceFileLocation();
				loc.file = file;
				loc.ref = file.TypeReferenceDirectives[ref.index];
				return loc;
			case fileIncludeKindLibReferenceDirective:
				final loc = new ReferenceFileLocation();
				loc.file = file;
				loc.ref = file.LibReferenceDirectives[ref.index];
				return loc;
			default:
				throw Fmt.Sprintf("unknown reason: %v", [(this.kind : Int)]);
		}
	}

	function toDiagnostic(program:Program, relativeFileName:Bool):Diagnostic {
		if (relativeFileName) {
			if (!this.relativeFileNameDiagOnce) {
				this.relativeFileNameDiagOnce = true;
				this.relativeFileNameDiag = this.computeDiagnostic(program, function(fileName:std.String):std.String {
					return Tspath.GetRelativePathFromDirectory(program.GetCurrentDirectory(), fileName, program.comparePathsOptions);
				});
			}
			return this.relativeFileNameDiag;
		} else {
			if (!this.diagOnce) {
				this.diagOnce = true;
				this.diag = this.computeDiagnostic(program, function(fileName:std.String):std.String {
					return fileName;
				});
			}
			return this.diag;
		}
	}

	function computeDiagnostic(program:Program, toFileName:(std.String) -> std.String):Diagnostic {
		if (this.isReferencedFile()) {
			return this.computeReferenceFileDiagnostic(program, toFileName);
		}
		switch (this.kind) {
			case fileIncludeKindRootFile:
				if (program.opts.Config.ConfigFile != null) {
					final config = program.opts.Config;
					final fileName = Tspath.GetNormalizedAbsolutePath(config.FileNames()[this.asIndex()], program.GetCurrentDirectory());
					final matchedFileSpec = config.GetMatchedFileSpec(fileName);
					if (matchedFileSpec != "") {
						return Ast.NewCompilerDiagnostic(Diagnostics.Part_of_files_list_in_tsconfig_json, matchedFileSpec, toFileName(fileName));
					} else {
						final m = config.GetMatchedIncludeSpec(fileName);
						final matchedIncludeSpec = m.value, isDefaultIncludeSpec = m.ok;
						if (matchedIncludeSpec != "") {
							if (isDefaultIncludeSpec) {
								return Ast.NewCompilerDiagnostic(Diagnostics.Matched_by_default_include_pattern_Asterisk_Asterisk_Slash_Asterisk);
							} else {
								return Ast.NewCompilerDiagnostic(Diagnostics.Matched_by_include_pattern_0_in_1, matchedIncludeSpec, toFileName(config.ConfigName()));
							}
						} else {
							return Ast.NewCompilerDiagnostic(Diagnostics.Root_file_specified_for_compilation);
						}
					}
				} else {
					return Ast.NewCompilerDiagnostic(Diagnostics.Root_file_specified_for_compilation);
				}
			case fileIncludeKindAutomaticTypeDirectiveFile:
				final data = this.asAutomaticTypeDirectiveFileData();
				if (!program.Options().UsesWildcardTypes()) {
					if (data.packageId.Name != "") {
						return Ast.NewCompilerDiagnostic(Diagnostics.Entry_point_of_type_library_0_specified_in_compilerOptions_with_packageId_1, data.typeReference,
							data.packageId.String());
					} else {
						return Ast.NewCompilerDiagnostic(Diagnostics.Entry_point_of_type_library_0_specified_in_compilerOptions, data.typeReference);
					}
				} else {
					if (data.packageId.Name != "") {
						return Ast.NewCompilerDiagnostic(Diagnostics.Entry_point_for_implicit_type_library_0_with_packageId_1, data.typeReference,
							data.packageId.String());
					} else {
						return Ast.NewCompilerDiagnostic(Diagnostics.Entry_point_for_implicit_type_library_0, data.typeReference);
					}
				}
			case fileIncludeKindLibFile:
				final li = this.asLibFileIndex();
				final target = program.Options().GetEmitScriptTarget().String();
				if (li.ok) {
					return Ast.NewCompilerDiagnostic(Diagnostics.Library_0_specified_in_compilerOptions, program.Options().Lib[li.value]);
				} else if (target != "") {
					return Ast.NewCompilerDiagnostic(Diagnostics.Default_library_for_target_0, target);
				} else {
					return Ast.NewCompilerDiagnostic(Diagnostics.Default_library);
				}
			default:
				throw Fmt.Sprintf("unknown reason: %v", [(this.kind : Int)]);
		}
	}

	function computeReferenceFileDiagnostic(program:Program, toFileName:(std.String) -> std.String):Diagnostic {
		final referenceLocation = program.includeProcessor.getReferenceLocation(this, program);
		final referenceText = referenceLocation.text();
		switch (this.kind) {
			case fileIncludeKindImport:
				if (!referenceLocation.isSynthetic) {
					if (referenceLocation.packageId.Name != "") {
						return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1_with_packageId_2, referenceText,
							toFileName(referenceLocation.file.FileName()), referenceLocation.packageId.String());
					} else {
						return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1, referenceText, toFileName(referenceLocation.file.FileName()));
					}
				} else {
					final specifiers = program.importHelpersImportSpecifiers;
					final specifier = specifiers == null ? null : specifiers.get(referenceLocation.file.Path());
					final ok = specifiers != null && specifiers.exists(referenceLocation.file.Path());
					if (ok && specifier == referenceLocation.node) {
						if (referenceLocation.packageId.Name != "") {
							return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1_with_packageId_2_to_import_importHelpers_as_specified_in_compilerOptions,
								referenceText, toFileName(referenceLocation.file.FileName()), referenceLocation.packageId.String());
						} else {
							return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1_to_import_importHelpers_as_specified_in_compilerOptions,
								referenceText, toFileName(referenceLocation.file.FileName()));
						}
					} else {
						if (referenceLocation.packageId.Name != "") {
							return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1_with_packageId_2_to_import_jsx_and_jsxs_factory_functions,
								referenceText, toFileName(referenceLocation.file.FileName()), referenceLocation.packageId.String());
						} else {
							return Ast.NewCompilerDiagnostic(Diagnostics.Imported_via_0_from_file_1_to_import_jsx_and_jsxs_factory_functions, referenceText,
								toFileName(referenceLocation.file.FileName()));
						}
					}
				}
			case fileIncludeKindReferenceFile:
				return Ast.NewCompilerDiagnostic(Diagnostics.Referenced_via_0_from_file_1, referenceText, toFileName(referenceLocation.file.FileName()));
			case fileIncludeKindTypeReferenceDirective:
				if (referenceLocation.packageId.Name != "") {
					return Ast.NewCompilerDiagnostic(Diagnostics.Type_library_referenced_via_0_from_file_1_with_packageId_2, referenceText,
						toFileName(referenceLocation.file.FileName()), referenceLocation.packageId.String());
				} else {
					return Ast.NewCompilerDiagnostic(Diagnostics.Type_library_referenced_via_0_from_file_1, referenceText,
						toFileName(referenceLocation.file.FileName()));
				}
			case fileIncludeKindLibReferenceDirective:
				return Ast.NewCompilerDiagnostic(Diagnostics.Library_referenced_via_0_from_file_1, referenceText, toFileName(referenceLocation.file.FileName()));
			default:
				throw Fmt.Sprintf("unknown reason: %v", [(this.kind : Int)]);
		}
	}

	function toRelatedInfo(program:Program):Diagnostic {
		if (this.isReferencedFile()) {
			return this.computeReferenceFileRelatedInfo(program);
		}
		if (program.opts.Config.ConfigFile == null) {
			return null;
		}
		final config = program.opts.Config;
		switch (this.kind) {
			case fileIncludeKindRootFile:
				final fileName = Tspath.GetNormalizedAbsolutePath(config.FileNames()[this.asIndex()], program.GetCurrentDirectory());
				final matchedFileSpec = config.GetMatchedFileSpec(fileName);
				if (matchedFileSpec != "") {
					final filesNode = Tsoptions.GetTsConfigPropArrayElementValue(config.ConfigFile.SourceFile, "files", matchedFileSpec);
					if (filesNode != null) {
						return Tsoptions.CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, filesNode.AsNode(),
							Diagnostics.File_is_matched_by_files_list_specified_here);
					}
				} else {
					final m = config.GetMatchedIncludeSpec(fileName);
					final matchedIncludeSpec = m.value, isDefaultIncludeSpec = m.ok;
					if (matchedIncludeSpec != "" && !isDefaultIncludeSpec) {
						final includeNode = Tsoptions.GetTsConfigPropArrayElementValue(config.ConfigFile.SourceFile, "include", matchedIncludeSpec);
						if (includeNode != null) {
							return Tsoptions.CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, includeNode.AsNode(),
								Diagnostics.File_is_matched_by_include_pattern_specified_here);
						}
					}
				}
			case fileIncludeKindAutomaticTypeDirectiveFile:
				if (!program.Options().UsesWildcardTypes()) {
					final data = this.asAutomaticTypeDirectiveFileData();
					final typesSyntax = Tsoptions.GetOptionsSyntaxByArrayElementValue(program.includeProcessor.getCompilerOptionsObjectLiteralSyntax(program),
						"types", data.typeReference);
					if (typesSyntax != null) {
						return Tsoptions.CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, typesSyntax.AsNode(),
							Diagnostics.File_is_entry_point_of_type_library_specified_here);
					}
				}
			case fileIncludeKindLibFile:
				final li = this.asLibFileIndex();
				if (li.ok) {
					final libSyntax = Tsoptions.GetOptionsSyntaxByArrayElementValue(program.includeProcessor.getCompilerOptionsObjectLiteralSyntax(program), "lib",
						program.Options().Lib[li.value]);
					if (libSyntax != null) {
						return Tsoptions.CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, libSyntax.AsNode(), Diagnostics.File_is_library_specified_here);
					}
				} else {
					final target = program.Options().GetEmitScriptTarget().String();
					if (target != "") {
						final targetValueSyntax = Tsoptions.ForEachPropertyAssignment(program.includeProcessor.getCompilerOptionsObjectLiteralSyntax(program), "target",
							Tsoptions.GetCallbackForFindingPropertyAssignmentByValue(target));
						if (targetValueSyntax != null) {
							return Tsoptions.CreateDiagnosticForNodeInSourceFile(config.ConfigFile.SourceFile, targetValueSyntax.AsNode(),
								Diagnostics.File_is_default_library_for_target_specified_here);
						}
					}
				}
			default:
				throw Fmt.Sprintf("unknown reason: %v", [(this.kind : Int)]);
		}
		return null;
	}

	function computeReferenceFileRelatedInfo(program:Program):Diagnostic {
		final referenceLocation = program.includeProcessor.getReferenceLocation(this, program);
		if (referenceLocation.isSynthetic) {
			return null;
		}
		switch (this.kind) {
			case fileIncludeKindImport:
				return referenceLocation.diagnosticAt(Diagnostics.File_is_included_via_import_here);
			case fileIncludeKindReferenceFile:
				return referenceLocation.diagnosticAt(Diagnostics.File_is_included_via_reference_here);
			case fileIncludeKindTypeReferenceDirective:
				return referenceLocation.diagnosticAt(Diagnostics.File_is_included_via_type_library_reference_here);
			case fileIncludeKindLibReferenceDirective:
				return referenceLocation.diagnosticAt(Diagnostics.File_is_included_via_library_reference_here);
			default:
				throw Fmt.Sprintf("unknown reason: %v", [(this.kind : Int)]);
		}
	}
}

@:allow(ts.compiler)
class ReferencedFileData {
	var file:Path = "";
	var index:Int = 0;
	var synthetic:Node = null;

	public function new(file:Path = "", index:Int = 0, ?synthetic:Node) {
		this.file = file;
		this.index = index;
		this.synthetic = synthetic;
	}
}

@:allow(ts.compiler)
class ReferenceFileLocation {
	var file:SourceFile = null;
	var node:Node = null;
	var ref:FileReference = null;
	var packageId:PackageId = new PackageId();
	var isSynthetic:Bool = false;

	public function new() {}

	function text():std.String {
		if (this.node != null) {
			if (!Ast.NodeIsSynthesized(this.node)) {
				return this.file.Text().substring(Scanner.SkipTrivia(this.file.Text(), this.node.Loc.Pos()), this.node.End());
			} else {
				return Fmt.Sprintf("\"%s\"", [this.node.Text()]);
			}
		} else {
			return this.file.Text().substring(this.ref.Pos(), this.ref.End());
		}
	}

	function diagnosticAt(message:Message, ...args:Any):Diagnostic {
		if (this.node != null) {
			return Tsoptions.CreateDiagnosticForNodeInSourceFile(this.file, this.node, message, ...args);
		} else {
			return Ast.NewDiagnostic(this.file, this.ref.TextRange, message, ...args);
		}
	}
}

@:allow(ts.compiler)
class AutomaticTypeDirectiveFileData {
	var typeReference:std.String = "";
	var packageId:PackageId = new PackageId();

	public function new(typeReference:std.String = "", ?packageId:PackageId) {
		this.typeReference = typeReference;
		if (packageId != null)
			this.packageId = packageId;
	}
}
