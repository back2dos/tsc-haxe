package ts.transformers.tstransforms;

// Port of internal/transformers/tstransforms/importelision_test.go.
// PORT: the Go fake also has methods outside checker.Program (IsSourceFromProjectReference,
// ResolveModuleName); Haxe only needs the interface members.
private class FakeProgram implements Program {
	public var singleThreaded:Bool = false;
	public var compilerOptions:CompilerOptions = null;
	public var files:Array<SourceFile> = null;
	public var getEmitModuleFormatOfFile:(sourceFile:HasFileName) -> ModuleKind = null;
	public var getImpliedNodeFormatForEmit:(sourceFile:HasFileName) -> ModuleKind = null;
	public var getResolvedModule:(currentSourceFile:HasFileName, moduleReference:std.String, mode:ResolutionMode) -> ResolvedModule = null;
	public var getSourceFile:(FileName:std.String) -> SourceFile = null;
	public var getSourceFileForResolvedModule:(FileName:std.String) -> SourceFile = null;

	public function new() {}

	// GetRedirectForResolution implements checker.Program.
	public function GetRedirectForResolution(file:HasFileName):ParsedCommandLine {
		throw "unimplemented";
	}

	// SourceFileMayBeEmitted implements checker.Program.
	public function SourceFileMayBeEmitted(sourceFile:SourceFile, forceDtsEmit:Bool):Bool {
		throw "unimplemented";
	}

	// GetEmitSyntaxForUsageLocation implements checker.Program.
	public function GetEmitSyntaxForUsageLocation(sourceFile:HasFileName, usageLocation:StringLiteralLike):ResolutionMode {
		throw "unimplemented";
	}

	// CommonSourceDirectory implements checker.Program.
	public function CommonSourceDirectory():std.String {
		throw "unimplemented";
	}

	public function GetResolvedModuleFromModuleSpecifier(file:HasFileName, moduleSpecifier:StringLiteralLike):ResolvedModule {
		throw "unimplemented";
	}

	public function FileExists(path:std.String):Bool {
		return false;
	}

	public function GetCurrentDirectory():std.String {
		return "";
	}

	public function GetGlobalTypingsCacheLocation():std.String {
		return "";
	}

	public function GetNearestAncestorDirectoryWithPackageJson(dirname:std.String):std.String {
		return "";
	}

	public function GetSymlinkCache():KnownSymlinks {
		return null;
	}

	public function GetPackageJsonInfo(pkgJsonPath:std.String):InfoCacheEntry {
		return null;
	}

	public function GetRedirectTargets(path:Path):Array<std.String> {
		return null;
	}

	public function GetSourceOfProjectReferenceIfOutputIncluded(file:HasFileName):std.String {
		return "";
	}

	public function GetProjectReferenceFromSource(path:Path):SourceOutputAndProjectReference {
		return null;
	}

	public function GetPackagesMap():StringMap<Bool> {
		return null;
	}

	public function GetProjectReferenceFromOutputDts(path:Path):SourceOutputAndProjectReference {
		return null;
	}

	public function UseCaseSensitiveFileNames():Bool {
		return true;
	}

	public function Options():CompilerOptions {
		return compilerOptions;
	}

	public function SourceFiles():Array<SourceFile> {
		return files;
	}

	public function BindSourceFiles():Void {
		// PORT: core.WorkGroup → sequential loop.
		for (file in files) {
			if (!file.IsBound()) {
				Binder.BindSourceFile(file);
			}
		}
	}

	public function GetEmitModuleFormatOfFile(sourceFile:HasFileName):ModuleKind {
		return getEmitModuleFormatOfFile(sourceFile);
	}

	public function GetImpliedNodeFormatForEmit(sourceFile:HasFileName):ModuleKind {
		return getImpliedNodeFormatForEmit(sourceFile);
	}

	public function GetDefaultResolutionModeForFile(sourceFile:HasFileName):ResolutionMode {
		return getEmitModuleFormatOfFile(sourceFile);
	}

	public function GetModeForUsageLocation(sourceFile:HasFileName, location:StringLiteralLike):ResolutionMode {
		return getEmitModuleFormatOfFile(sourceFile);
	}

	public function GetResolvedModule(currentSourceFile:HasFileName, moduleReference:std.String, mode:ResolutionMode):ResolvedModule {
		return getResolvedModule(currentSourceFile, moduleReference, mode);
	}

	public function GetSourceFile(FileName:std.String):SourceFile {
		return getSourceFile(FileName);
	}

	public function GetSourceFileForResolvedModule(FileName:std.String):SourceFile {
		return getSourceFileForResolvedModule(FileName);
	}

	public function GetSourceFileMetaData(path:Path):SourceFileMetaData {
		return new SourceFileMetaData();
	}

	public function GetImportHelpersImportSpecifier(path:Path):Node {
		return null;
	}

	public function GetJSXRuntimeImportSpecifier(path:Path):Pair<std.String, Node> {
		return new Pair("", null);
	}

	public function GetResolvedModules():StringMap<ModeAwareCache<ResolvedModule>> {
		throw "unimplemented";
	}

	public function IsSourceFileDefaultLibrary(path:Path):Bool {
		return false;
	}
}

private class ImportElisionCase {
	public final title:std.String;
	public final input:std.String;
	public final output:std.String;
	public final other:std.String;
	public final jsx:Bool;

	public function new(title:std.String, input:std.String, output:std.String, other:std.String = "", jsx:Bool = false) {
		this.title = title;
		this.input = input;
		this.output = output;
		this.other = other;
		this.jsx = jsx;
	}
}

class ImportelisionTest {
	public static function run() {
		T.run("TestImportElision", TestImportElision);
	}

	static function TestImportElision() {
		final data = [
			new ImportElisionCase("ImportEquals#1", "import x = require(\"other\"); x;", "import x = require(\"other\");\nx;"),
			new ImportElisionCase("ImportEquals#2", "import x = require(\"other\");", ""),
			new ImportElisionCase("ImportDeclaration#1", 'import "m";', 'import "m";'),
			new ImportElisionCase("ImportDeclaration#2", "import * as x from \"other\"; x;", "import * as x from \"other\";\nx;"),
			new ImportElisionCase("ImportDeclaration#3", "import x from \"other\"; x;", "import x from \"other\";\nx;"),
			new ImportElisionCase("ImportDeclaration#4", "import { x } from \"other\"; x;", "import { x } from \"other\";\nx;"),
			new ImportElisionCase("ImportDeclaration#5", "import * as x from \"other\";", ""),
			new ImportElisionCase("ImportDeclaration#6", "import x from \"other\";", ""),
			new ImportElisionCase("ImportDeclaration#7", "import { x } from \"other\";", ""),
			new ImportElisionCase("ExportDeclaration#1", "export * from \"other\";", "export * from \"other\";", "export let x;"),
			new ImportElisionCase("ExportDeclaration#2", "export * as x from \"other\";", "export * as x from \"other\";", "export let x;"),
			new ImportElisionCase("ExportDeclaration#3", "export * from \"other\";", "export * from \"other\";", "export let x;"),
			new ImportElisionCase("ExportDeclaration#4", "export * as x from \"other\";", "export * as x from \"other\";", "export let x;"),
			new ImportElisionCase("ExportDeclaration#5", "export { x } from \"other\";", "export { x } from \"other\";", "export let x;"),
			new ImportElisionCase("ExportDeclaration#6", "export { x } from \"other\";", "", "export type x = any;"),
			new ImportElisionCase("ExportDeclaration#7", "export { x }; let x;", "export { x };\nlet x;"),
			new ImportElisionCase("ExportDeclaration#8", "export { x }; type x = any;", ""),
			new ImportElisionCase("ExportDeclaration#9", "import { x } from \"other\"; export { x };", "", "export type x = any;"),
			new ImportElisionCase("ExportAssignment#1", "let x; export default x;", "let x;\nexport default x;"),
			new ImportElisionCase("ExportAssignment#2", "type x = any; export default x;", ""),
		];

		for (rec in data) {
			T.run("TestImportElision/" + rec.title, () -> {
				var file = Parsetestutil.ParseTypeScript(rec.input, rec.jsx);
				Parsetestutil.CheckDiagnostics(file);
				final files = [file];

				var other:SourceFile = null;
				if (rec.other.length > 0) {
					other = Parsetestutil.ParseTypeScript(rec.other, rec.jsx);
					Parsetestutil.CheckDiagnostics(other);
					files.push(other);
				}

				final compilerOptions = new CompilerOptions();

				final program = new FakeProgram();
				program.singleThreaded = true;
				program.compilerOptions = compilerOptions;
				program.files = files;
				program.getEmitModuleFormatOfFile = function(sourceFile:HasFileName):ModuleKind {
					return ModuleKindESNext;
				};
				program.getImpliedNodeFormatForEmit = function(sourceFile:HasFileName):ModuleKind {
					return ModuleKindESNext;
				};
				program.getSourceFile = function(fileName:std.String):SourceFile {
					if (fileName == "other.ts") {
						return other;
					}
					return null;
				};
				program.getSourceFileForResolvedModule = function(fileName:std.String):SourceFile {
					if (fileName == "other.ts") {
						return other;
					}
					return null;
				};
				final originalFile = file;
				program.getResolvedModule = function(currentSourceFile:HasFileName, moduleReference:std.String, mode:ResolutionMode):ResolvedModule {
					// PORT: a SourceFile passed as ast.HasFileName is its cached adapter.
					if (currentSourceFile == ts.modulespecifiers.Types.SourceFileAdapter.Of(originalFile) && moduleReference == "other") {
						final r = new ResolvedModule();
						r.ResolvedFileName = "other.ts";
						r.Extension = Tspath.ExtensionTs;
						return r;
					}
					return null;
				};
				final c = Checker.NewChecker(program, null).a;

				final emitResolver = c.GetEmitResolver();

				final opts = new TransformOptions();
				opts.CompilerOptions = compilerOptions;
				opts.Context = Printer.NewEmitContext();
				opts.EmitResolver = emitResolver;
				opts.Resolver = emitResolver;
				file = Tstransforms.NewTypeEraserTransformer(opts).TransformSourceFile(file);
				file = Tstransforms.NewImportElisionTransformer(opts).TransformSourceFile(file);
				Emittestutil.CheckEmit(null, file, rec.output);
			});
		}
	}
}
