package ts.tspath;

// Port of internal/tspath/file_spec.go (types and methods).

// FileSpec is a file name as written in a configuration file.
// It may be relative and may contain ${configDir}.
// PORT: an abstract over String; see RootedPath.hx.
abstract FileSpec(String) to String {
	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}
}

// PathPattern is an include or exclude pattern as written in configuration.
// It may be relative, rooted, or contain wildcards and ${configDir}.
abstract PathPattern(String) to String {
	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}
}
