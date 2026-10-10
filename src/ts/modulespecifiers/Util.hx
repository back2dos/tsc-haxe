package ts.modulespecifiers;

// Port of util.go (types; the funcs and vars are in Modulespecifiers.hx).
// PORT: type regexPatternCacheKey (struct map key) is encoded as a String key (PORTING.md §4a).

// PORT: Go value struct, never mutated → immutable class.
class NodeModulePathParts {
	public final TopLevelNodeModulesIndex:Int;
	public final TopLevelPackageNameIndex:Int;
	public final PackageRootIndex:Int;
	public final FileNameIndex:Int;

	public function new(TopLevelNodeModulesIndex:Int = 0, TopLevelPackageNameIndex:Int = 0, PackageRootIndex:Int = 0, FileNameIndex:Int = 0) {
		this.TopLevelNodeModulesIndex = TopLevelNodeModulesIndex;
		this.TopLevelPackageNameIndex = TopLevelPackageNameIndex;
		this.PackageRootIndex = PackageRootIndex;
		this.FileNameIndex = FileNameIndex;
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
