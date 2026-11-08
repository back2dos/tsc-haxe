package ts.modulespecifiers;

// Port of specifiers.go (types; the funcs are in Modulespecifiers.hx).

// PORT: Go value struct, never mutated → immutable class.
class Info {
	public final CaseSensitivity:CaseSensitivity;
	public final ImportingSourceFileName:RootedFilePath;
	public final SourceDirectory:RootedDirectoryPath;

	public function new(CaseSensitivity:CaseSensitivity, ImportingSourceFileName:RootedFilePath, SourceDirectory:RootedDirectoryPath) {
		this.CaseSensitivity = CaseSensitivity;
		this.ImportingSourceFileName = ImportingSourceFileName;
		this.SourceDirectory = SourceDirectory;
	}
}

class PkgJsonDirAttemptResult {
	public final moduleFileToTry:RootedFilePath;
	public final packageRootDirectory:RootedDirectoryPath;
	public final blockedByExports:Bool;
	public final verbatimFromExports:ModuleSpecifier;

	public function new(moduleFileToTry:RootedFilePath, ?packageRootDirectory:RootedDirectoryPath, blockedByExports:Bool = false,
			?verbatimFromExports:ModuleSpecifier) {
		this.moduleFileToTry = moduleFileToTry;
		this.packageRootDirectory = packageRootDirectory != null ? packageRootDirectory : cast "";
		this.blockedByExports = blockedByExports;
		this.verbatimFromExports = verbatimFromExports != null ? verbatimFromExports : cast "";
	}
}

class SpecPair {
	public final ending:ModuleSpecifierEnding;
	public final value:ModuleSpecifier;

	public function new(ending:ModuleSpecifierEnding, value:ModuleSpecifier) {
		this.ending = ending;
		this.value = value;
	}
}
