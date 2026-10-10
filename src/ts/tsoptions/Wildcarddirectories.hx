package ts.tsoptions;

// Port of wildcarddirectories.go (types; package-level funcs are in Tsoptions.hx).

// wildcardDirectoryMatch represents the result of a wildcard directory match
class WildcardDirectoryMatch {
	public var Key:std.String = "";
	public var Path:std.String = "";
	public var Recursive:Bool = false;

	public function new(Key:std.String, Path:std.String, Recursive:Bool) {
		this.Key = Key;
		this.Path = Path;
		this.Recursive = Recursive;
	}
}
