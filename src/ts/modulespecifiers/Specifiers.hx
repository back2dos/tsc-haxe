package ts.modulespecifiers;

// Port of specifiers.go (types; the funcs are in Modulespecifiers.hx).

// PORT: Go value struct, never mutated → immutable class.
class Info {
	public final UseCaseSensitiveFileNames:Bool;
	public final ImportingSourceFileName:String;
	public final SourceDirectory:String;

	public function new(UseCaseSensitiveFileNames:Bool = false, ImportingSourceFileName:String = "", SourceDirectory:String = "") {
		this.UseCaseSensitiveFileNames = UseCaseSensitiveFileNames;
		this.ImportingSourceFileName = ImportingSourceFileName;
		this.SourceDirectory = SourceDirectory;
	}
}

class PkgJsonDirAttemptResult {
	public final moduleFileToTry:String;
	public final packageRootPath:String;
	public final blockedByExports:Bool;
	public final verbatimFromExports:Bool;

	public function new(moduleFileToTry:String = "", packageRootPath:String = "", blockedByExports:Bool = false, verbatimFromExports:Bool = false) {
		this.moduleFileToTry = moduleFileToTry;
		this.packageRootPath = packageRootPath;
		this.blockedByExports = blockedByExports;
		this.verbatimFromExports = verbatimFromExports;
	}
}

class SpecPair {
	public final ending:ModuleSpecifierEnding;
	public final value:String;

	public function new(ending:ModuleSpecifierEnding, value:String) {
		this.ending = ending;
		this.value = value;
	}
}
