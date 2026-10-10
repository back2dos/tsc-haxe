package ts.tspath;

// Port of internal/tspath/path.go (types and methods). Package-level funcs are in Tspath.hx.

// Go `type Path string`.
abstract Path(String) from String to String {
	public inline function new(s:String) {
		this = s;
	}

	public inline function GetDirectoryPath():Path {
		return Tspath.GetDirectoryPath(this);
	}

	public inline function RemoveTrailingDirectorySeparator():Path {
		return Tspath.RemoveTrailingDirectorySeparator(this);
	}

	public inline function EnsureTrailingDirectorySeparator():Path {
		return Tspath.EnsureTrailingDirectorySeparator(this);
	}

	// ContainsPath checks whether child is contained within or equal to p.
	// Since Path values are already rooted, reduced, and case-canonicalized,
	// this is a simple string prefix check.
	public function ContainsPath(child:Path):Bool {
		final p:String = this;
		final c:String = child;
		if (p.length == 0) {
			return false;
		}
		return p == c
			|| c.length > p.length
			&& StringTools.startsWith(c, p)
			&& (StringTools.fastCodeAt(p, p.length - 1) == '/'.code || StringTools.fastCodeAt(c, p.length) == '/'.code);
	}
}

class ComparePathsOptions {
	public var UseCaseSensitiveFileNames:Bool = false;
	public var CurrentDirectory:String = "";

	public function new(UseCaseSensitiveFileNames:Bool = false, CurrentDirectory:String = "") {
		this.UseCaseSensitiveFileNames = UseCaseSensitiveFileNames;
		this.CurrentDirectory = CurrentDirectory;
	}

	// Go struct value copy.
	public function copy():ComparePathsOptions {
		return new ComparePathsOptions(UseCaseSensitiveFileNames, CurrentDirectory);
	}

	public function GetComparer():(a:String, b:String) -> Int {
		return Stringutil.GetStringComparer(!this.UseCaseSensitiveFileNames);
	}

	@:allow(ts.tspath)
	function getEqualityComparer():(a:String, b:String) -> Bool {
		return Stringutil.GetStringEqualityComparer(!this.UseCaseSensitiveFileNames);
	}
}
