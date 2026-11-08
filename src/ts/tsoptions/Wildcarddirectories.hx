package ts.tsoptions;

// Port of wildcarddirectories.go (types; package-level funcs are in Tsoptions.hx).

// wildcardDirectoryMatch represents the result of a wildcard directory match
class WildcardDirectoryMatch {
	public var Path:RootedDirectoryPath = cast "";
	public var Recursive:Bool = false;

	public function new(Path:RootedDirectoryPath, Recursive:Bool) {
		this.Path = Path;
		this.Recursive = Recursive;
	}
}
