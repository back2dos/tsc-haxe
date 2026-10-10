package ts.compiler;

// Port of emitHost.go (types and methods; newEmitHost is in Compiler.hx).

// NOTE: EmitHost operations must be thread-safe
interface EmitHost extends ts.printer.Emithost.EmitHost extends ts.transformers.declarations.Transform.DeclarationEmitHost extends SourceFileMayBeEmittedHost {
	function Options():CompilerOptions;
	function SourceFiles():Array<SourceFile>;
	function UseCaseSensitiveFileNames():Bool;
	function GetCurrentDirectory():std.String;
	function CommonSourceDirectory():std.String;
	function IsEmitBlocked(file:std.String):Bool;
}

// NOTE: emitHost operations must be thread-safe
// Go type emitHost (the exported name EmitHost is the interface).
@:allow(ts.compiler)
class EmitHost_ implements EmitHost implements OutputPathsHost {
	var program:Program = null;
	var emitResolver:EmitResolver = null;

	public function new() {}

	public function GetModeForUsageLocation(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolutionMode {
		return this.program.GetModeForUsageLocation(file, moduleSpecifier);
	}

	public function GetResolvedModuleFromModuleSpecifier(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolvedModule {
		return this.program.GetResolvedModuleFromModuleSpecifier(file, moduleSpecifier);
	}

	public function GetDefaultResolutionModeForFile(file:HasFileName):ResolutionMode {
		return this.program.GetDefaultResolutionModeForFile(file);
	}

	public function GetEmitModuleFormatOfFile(file:HasFileName):ModuleKind {
		return this.program.GetEmitModuleFormatOfFile(file);
	}

	public function FileExists(path:std.String):Bool {
		return this.program.FileExists(path);
	}

	public function GetGlobalTypingsCacheLocation():std.String {
		return this.program.GetGlobalTypingsCacheLocation();
	}

	public function GetNearestAncestorDirectoryWithPackageJson(dirname:std.String):std.String {
		return this.program.GetNearestAncestorDirectoryWithPackageJson(dirname);
	}

	public function GetPackageJsonInfo(pkgJsonPath:std.String):InfoCacheEntry {
		return this.program.GetPackageJsonInfo(pkgJsonPath);
	}

	public function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):std.String {
		return this.program.GetSourceOfProjectReferenceIfOutputIncluded(file);
	}

	public function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference {
		return this.program.GetProjectReferenceFromSource(path);
	}

	public function GetRedirectTargets(path:Path):Array<std.String> {
		return this.program.GetRedirectTargets(path);
	}

	public function GetEffectiveDeclarationFlags(node:Node, flags:ModifierFlags):ModifierFlags {
		return this.GetEmitResolver().GetEffectiveDeclarationFlags(node, flags);
	}

	public function GetOutputPathsFor(file:SourceFile, forceDtsPaths:Bool):ts.transformers.declarations.Transform.OutputPaths {
		// TODO: cache
		// PORT: outputpaths.OutputPaths does not declare declarations.OutputPaths (nominal interfaces): adapter.
		return new OutputPathsAdapter(Outputpaths.GetOutputPathsFor(file, this.Options(), this, forceDtsPaths));
	}

	public function GetResolutionModeOverride(node:Node):ResolutionMode {
		return this.GetEmitResolver().GetResolutionModeOverride(node);
	}

	public function GetSourceFileFromReference(origin:SourceFile, ref:FileReference):SourceFile {
		return this.program.GetSourceFileFromReference(origin, ref);
	}

	public function Options():CompilerOptions {
		return this.program.Options();
	}

	public function SourceFiles():Array<SourceFile> {
		return this.program.SourceFiles();
	}

	public function GetCurrentDirectory():std.String {
		return this.program.GetCurrentDirectory();
	}

	public function CommonSourceDirectory():std.String {
		return this.program.CommonSourceDirectory();
	}

	public function UseCaseSensitiveFileNames():Bool {
		return this.program.UseCaseSensitiveFileNames();
	}

	public function IsEmitBlocked(file:std.String):Bool {
		return this.program.IsEmitBlocked(file);
	}

	public function WriteFile(fileName:std.String, text:std.String):Null<Error> {
		return this.program.Host().FS().WriteFile(fileName, text);
	}

	public function GetEmitResolver():EmitResolver {
		return this.emitResolver;
	}

	public function IsSourceFileFromExternalLibrary(file:SourceFile):Bool {
		return this.program.IsSourceFileFromExternalLibrary(file);
	}

	public function GetSymlinkCache():KnownSymlinks {
		return this.program.GetSymlinkCache();
	}

	public function ResolveModuleName(moduleName:std.String, containingFile:std.String, resolutionMode:ResolutionMode):ResolvedModule {
		final resolved = this.program.processedFiles.resolver.ResolveModuleName(moduleName, containingFile, resolutionMode, null).a;
		return resolved;
	}
}

// PORT: adapter so an outputpaths.OutputPaths can be used as a declarations.OutputPaths.
class OutputPathsAdapter implements ts.transformers.declarations.Transform.OutputPaths {
	public final paths:ts.outputpaths.Outputpaths.OutputPaths;

	public function new(paths:ts.outputpaths.Outputpaths.OutputPaths) {
		this.paths = paths;
	}

	public function DeclarationFilePath():std.String {
		return this.paths.DeclarationFilePath();
	}

	public function JsFilePath():std.String {
		return this.paths.JsFilePath();
	}
}
