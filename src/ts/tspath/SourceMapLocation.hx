package ts.tspath;

// Port of internal/tspath/source_map_location.go (type and methods).

// PORT: an abstract over String; see RootedPath.hx. Go's UnmarshalText/MarshalText are the identity on the
// text (after ToSourceMapLocation): callers that decode JSON call Tspath.ToSourceMapLocation.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract SourceMapLocation(String) to String {
	// PORT: Go len(p).
	public var length(get, never):Int;

	inline function get_length():Int {
		return this.length;
	}

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
