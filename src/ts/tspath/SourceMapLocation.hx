package ts.tspath;

// Port of internal/tspath/source_map_location.go (type and methods).

// PORT: an abstract over String; see RootedPath.hx. Go's UnmarshalText/MarshalText are the identity on the
// text (after ToSourceMapLocation): callers that decode JSON call Tspath.ToSourceMapLocation.
abstract SourceMapLocation(String) to String {
	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	public inline function IsRelative():Bool {
		return Tspath.GetRootLength(this) == 0;
	}

	public function ResolveDirectory(relativeBase:RootedDirectoryPath, currentDirectory:RootedDirectoryPath):RootedDirectoryPath {
		if (this == "") {
			throw "cannot resolve an empty source map root";
		}
		if (IsRelative()) {
			return relativeBase.ResolveDirectory(this);
		}
		return Tspath.ToRootedDirectoryPath(this, currentDirectory);
	}
}
