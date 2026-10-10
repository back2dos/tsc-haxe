package ts.execute.incremental;

// Port of snapshot.go (types and methods). Package-level funcs are in Incremental.hx.

@:allow(ts.execute.incremental)
class FileInfo {
	var version:std.String = "";
	var signature:std.String = "";
	var affectsGlobalScope:Bool = false;
	var impliedNodeFormat:ResolutionMode = ModuleKindNone;

	public function new(version:std.String = "", signature:std.String = "", affectsGlobalScope:Bool = false,
			impliedNodeFormat:ResolutionMode = ModuleKindNone) {
		this.version = version;
		this.signature = signature;
		this.affectsGlobalScope = affectsGlobalScope;
		this.impliedNodeFormat = impliedNodeFormat;
	}

	public function Version():std.String {
		return this.version;
	}

	public function Signature():std.String {
		return this.signature;
	}

	public function AffectsGlobalScope():Bool {
		return this.affectsGlobalScope;
	}

	public function ImpliedNodeFormat():ResolutionMode {
		return this.impliedNodeFormat;
	}
}

enum abstract FileEmitKind(Int) from Int to Int {
	var FileEmitKindNone = 0;
	var FileEmitKindJs = 1 << 0; // emit js file
	var FileEmitKindJsMap = 1 << 1; // emit js.map file
	var FileEmitKindJsInlineMap = 1 << 2; // emit inline source map in js file
	var FileEmitKindDtsErrors = 1 << 3; // emit dts errors
	var FileEmitKindDtsEmit = 1 << 4; // emit d.ts file
	var FileEmitKindDtsMap = 1 << 5; // emit d.ts.map file

	var FileEmitKindDts = (1 << 3) | (1 << 4); // FileEmitKindDtsErrors | FileEmitKindDtsEmit
	var FileEmitKindAllJs = (1 << 0) | (1 << 1) | (1 << 2); // FileEmitKindJs | FileEmitKindJsMap | FileEmitKindJsInlineMap
	var FileEmitKindAllDtsEmit = (1 << 4) | (1 << 5); // FileEmitKindDtsEmit | FileEmitKindDtsMap
	var FileEmitKindAllDts = (1 << 3) | (1 << 4) | (1 << 5); // FileEmitKindDts | FileEmitKindDtsMap
	var FileEmitKindAll = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5); // FileEmitKindAllJs | FileEmitKindAllDts

	@:op(A | B) static function or(a:FileEmitKind, b:FileEmitKind):FileEmitKind;

	@:op(A & B) static function and(a:FileEmitKind, b:FileEmitKind):FileEmitKind;

	@:op(A ^ B) static function xor(a:FileEmitKind, b:FileEmitKind):FileEmitKind;

	@:op(~A) static function not(a:FileEmitKind):FileEmitKind;
}

// Signature (Hash of d.ts emitted), is string if it was emitted using same d.ts.map option as what compilerOptions indicate,
// otherwise tuple of string
@:allow(ts.execute.incremental)
class EmitSignature {
	var signature:std.String = "";
	var signatureWithDifferentOptions:Array<std.String> = null;

	public function new(signature:std.String = "", ?signatureWithDifferentOptions:Array<std.String>) {
		this.signature = signature;
		this.signatureWithDifferentOptions = signatureWithDifferentOptions;
	}

	// Covert to Emit signature based on oldOptions and EmitSignature format
	// If d.ts map options differ then swap the format, otherwise use as is
	function getNewEmitSignature(oldOptions:CompilerOptions, newOptions:CompilerOptions):EmitSignature {
		if (oldOptions.DeclarationMap.IsTrue() == newOptions.DeclarationMap.IsTrue()) {
			return this;
		}
		if (this.signatureWithDifferentOptions == null) {
			return new EmitSignature("", [this.signature]);
		} else {
			return new EmitSignature(this.signatureWithDifferentOptions[0]);
		}
	}
}

// Go type buildInfoDiagnosticWithFileName.
@:allow(ts.execute.incremental)
class BuildInfoDiagnosticWithFileName {
	// filename if it is for a File thats other than its stored for
	var file:Path = "";
	var noFile:Bool = false;
	var pos:Int = 0;
	var end:Int = 0;
	var code:Int = 0;
	var category:Category = cast 0;
	var messageKey:Key = "";
	var messageArgs:Array<std.String> = null;
	var messageChain:Array<BuildInfoDiagnosticWithFileName> = null;
	var relatedInformation:Array<BuildInfoDiagnosticWithFileName> = null;
	var reportsUnnecessary:Bool = false;
	var reportsDeprecated:Bool = false;
	var skippedOnNoEmit:Bool = false;
	var repopulateInfo:RepopulateDiagnosticInfo = null;

	public function new() {}

	function toDiagnostic(p:CompilerProgram, file:SourceFile):Diagnostic {
		var fileForDiagnostic:SourceFile = null;
		if (this.file != "") {
			fileForDiagnostic = p.GetSourceFileByPath(this.file);
		} else if (!this.noFile) {
			fileForDiagnostic = file;
		}

		if (this.repopulateInfo != null) {
			return Incremental.repopulateDiagnosticChain(this, p, fileForDiagnostic);
		}

		var messageChain:Array<Diagnostic> = null;
		for (msg in this.messageChain) {
			if (messageChain == null)
				messageChain = [];
			messageChain.push(msg.toDiagnostic(p, fileForDiagnostic));
		}
		var relatedInformation:Array<Diagnostic> = null;
		for (info in this.relatedInformation) {
			if (relatedInformation == null)
				relatedInformation = [];
			relatedInformation.push(info.toDiagnostic(p, fileForDiagnostic));
		}
		return Ast.NewDiagnosticFromSerialized(fileForDiagnostic, Core.NewTextRange(this.pos, this.end), this.code, this.category, this.messageKey,
			this.messageArgs, messageChain, relatedInformation, this.reportsUnnecessary, this.reportsDeprecated, this.skippedOnNoEmit);
	}

	function toDiagnosticWithoutRepopulate(p:CompilerProgram, file:SourceFile):Diagnostic {
		var messageChain:Array<Diagnostic> = null;
		for (msg in this.messageChain) {
			if (messageChain == null)
				messageChain = [];
			messageChain.push(msg.toDiagnostic(p, file));
		}
		var relatedInformation:Array<Diagnostic> = null;
		for (info in this.relatedInformation) {
			if (relatedInformation == null)
				relatedInformation = [];
			relatedInformation.push(info.toDiagnostic(p, file));
		}
		return Ast.NewDiagnosticFromSerialized(file, Core.NewTextRange(this.pos, this.end), this.code, this.category, this.messageKey, this.messageArgs,
			messageChain, relatedInformation, this.reportsUnnecessary, this.reportsDeprecated, this.skippedOnNoEmit);
	}
}

@:allow(ts.execute.incremental)
class DiagnosticsOrBuildInfoDiagnosticsWithFileName {
	var diagnostics:Array<Diagnostic> = null;
	var buildInfoDiagnostics:Array<BuildInfoDiagnosticWithFileName> = null;

	public function new(?diagnostics:Array<Diagnostic>, ?buildInfoDiagnostics:Array<BuildInfoDiagnosticWithFileName>) {
		this.diagnostics = diagnostics;
		this.buildInfoDiagnostics = buildInfoDiagnostics;
	}

	function getDiagnostics(p:CompilerProgram, file:SourceFile):Array<Diagnostic> {
		if (this.diagnostics != null) {
			return this.diagnostics;
		}
		// Convert and cache the diagnostics
		this.diagnostics = Core.Map(this.buildInfoDiagnostics, function(diag:BuildInfoDiagnosticWithFileName):Diagnostic {
			return diag.toDiagnostic(p, file);
		});
		return this.diagnostics;
	}
}

// Go type snapshot.
@:allow(ts.execute.incremental)
class Snapshot {
	// These are the fields that get serialized

	// Information of the file eg. its version, signature etc
	var fileInfos:SyncMap<Path, FileInfo> = new SyncMap<Path, FileInfo>();
	var options:CompilerOptions = null;
	//  Contains the map of ReferencedSet=Referenced files of the file if module emit is enabled
	var referencedMap:ReferenceMap = new ReferenceMap();
	// Cache of semantic diagnostics for files with their Path being the key
	var semanticDiagnosticsPerFile:SyncMap<Path, DiagnosticsOrBuildInfoDiagnosticsWithFileName> = new SyncMap<Path,
		DiagnosticsOrBuildInfoDiagnosticsWithFileName>();
	// Cache of dts emit diagnostics for files with their Path being the key
	var emitDiagnosticsPerFile:SyncMap<Path, DiagnosticsOrBuildInfoDiagnosticsWithFileName> = new SyncMap<Path,
		DiagnosticsOrBuildInfoDiagnosticsWithFileName>();
	// The map has key by source file's path that has been changed
	var changedFilesSet:SyncSet<Path> = new SyncSet<Path>();
	// Files pending to be emitted
	var affectedFilesPendingEmit:SyncMap<Path, FileEmitKind> = new SyncMap<Path, FileEmitKind>(FileEmitKindNone);
	// Name of the file whose dts was the latest to change
	var latestChangedDtsFile:std.String = "";
	// Hash of d.ts emitted for the file, use to track when emit of d.ts changes
	var emitSignatures:SyncMap<Path, EmitSignature> = new SyncMap<Path, EmitSignature>();
	// Recorded if program had errors that need to be reported even with --noCheck
	var hasErrors:Tristate = TSUnknown;
	// Recorded if program had semantic errors only for non incremental build
	var hasSemanticErrors:Bool = false;
	// If semantic diagnostic check is pending
	var checkPending:Bool = false;
	// Looked up package.json files from
	var packageJsons:Array<std.String> = null;
	var missingPackageJsons:Array<std.String> = null;

	// Additional fields that are not serialized but needed to track state

	// true if build info emit is pending
	var buildInfoEmitPending:Bool = false; // PORT: atomic.Bool → Bool
	var hasErrorsFromOldState:Tristate = TSUnknown;
	var hasSemanticErrorsFromOldState:Bool = false;
	var allFilesExcludingDefaultLibraryFileOnce:Bool = false; // PORT: sync.Once → flag
	var packageJsonsFromOldState:Array<std.String> = null;
	var missingPackageJsonsFromOldState:Array<std.String> = null;
	//  Cache of all files excluding default library file for the current program
	var allFilesExcludingDefaultLibraryFile:Array<SourceFile> = null;
	var hasChangedDtsFile:Bool = false;
	var hasEmitDiagnostics:Bool = false;

	// Used with testing to add text of hash for better comparison
	var hashWithText:Bool = false;

	public function new() {}

	function addFileToChangeSet(filePath:Path):Void {
		this.changedFilesSet.Add(filePath);
		this.buildInfoEmitPending = true;
	}

	function addFileToAffectedFilesPendingEmit(filePath:Path, emitKind:FileEmitKind):Void {
		final existingKind = this.affectedFilesPendingEmit.Load(filePath).value;
		this.affectedFilesPendingEmit.Store(filePath, existingKind | emitKind);
		if (emitKind & FileEmitKindDtsErrors != 0) {
			this.emitDiagnosticsPerFile.Delete(filePath);
		}
		this.buildInfoEmitPending = true;
	}

	function getAllFilesExcludingDefaultLibraryFile(program:CompilerProgram, firstSourceFile:SourceFile):Array<SourceFile> {
		if (!this.allFilesExcludingDefaultLibraryFileOnce) {
			this.allFilesExcludingDefaultLibraryFileOnce = true;
			final files = program.GetSourceFiles();
			this.allFilesExcludingDefaultLibraryFile = [];
			final addSourceFile = function(file:SourceFile) {
				if (!program.IsSourceFileDefaultLibrary(file.Path())) {
					this.allFilesExcludingDefaultLibraryFile.push(file);
				}
			};
			if (firstSourceFile != null) {
				addSourceFile(firstSourceFile);
			}
			for (file in files) {
				if (file != firstSourceFile) {
					addSourceFile(file);
				}
			}
		}
		return this.allFilesExcludingDefaultLibraryFile;
	}

	function computeSignatureWithDiagnostics(file:SourceFile, text:std.String, data:WriteFileData):std.String {
		final builder = new go.Strings.Builder();
		builder.WriteString(Incremental.getTextHandlingSourceMapForSignature(text, data));
		for (diag in data.Diagnostics) {
			Incremental.diagnosticToStringBuilder(diag, file, builder);
		}
		return this.computeHash(builder.String());
	}

	function computeHash(text:std.String):std.String {
		return Incremental.ComputeHash(text, this.hashWithText);
	}

	function canUseIncrementalState():Bool {
		if (!this.options.IsIncremental() && this.options.Build.IsTrue()) {
			// If not incremental build (with tsc -b), we don't need to track state except diagnostics per file so we can use it
			return false;
		}
		return true;
	}
}
