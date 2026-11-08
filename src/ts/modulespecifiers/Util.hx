package ts.modulespecifiers;

// Port of util.go (types; the funcs and vars are in Modulespecifiers.hx).
// PORT: type regexPatternCacheKey (struct map key) is encoded as a String key (PORTING.md §4a).

// PORT: Go value struct, never mutated → immutable class.
class NodeModulePathParts {
	public final TopLevelNodeModulesSearchRoot:RootedDirectoryPath;
	public final TopLevelNodeModulesDirectory:RootedDirectoryPath;
	public final PackageRootDirectory:RootedDirectoryPath;
	public final PackageName:String;
	public final PackageRelativePath:RelativePath;
	public final HasNestedNodeModules:Bool;
	public final IsDirectNodeModulesFile:Bool;

	public function new(TopLevelNodeModulesSearchRoot:RootedDirectoryPath, TopLevelNodeModulesDirectory:RootedDirectoryPath,
			PackageRootDirectory:RootedDirectoryPath, PackageName:String, PackageRelativePath:RelativePath, HasNestedNodeModules:Bool,
			IsDirectNodeModulesFile:Bool) {
		this.TopLevelNodeModulesSearchRoot = TopLevelNodeModulesSearchRoot;
		this.TopLevelNodeModulesDirectory = TopLevelNodeModulesDirectory;
		this.PackageRootDirectory = PackageRootDirectory;
		this.PackageName = PackageName;
		this.PackageRelativePath = PackageRelativePath;
		this.HasNestedNodeModules = HasNestedNodeModules;
		this.IsDirectNodeModulesFile = IsDirectNodeModulesFile;
	}
}

enum abstract NodeModulesPathParseState(Int) from Int to Int {
	// PORT: Go integer ordering of the enum values.
	@:op(A > B) static function gt(a:NodeModulesPathParseState, b:NodeModulesPathParseState):Bool;

	var nodeModulesPathParseStateBeforeNodeModules = 0;
	var nodeModulesPathParseStateNodeModules = 1;
	var nodeModulesPathParseStateScope = 2;
	var nodeModulesPathParseStatePackageContent = 3;
}
