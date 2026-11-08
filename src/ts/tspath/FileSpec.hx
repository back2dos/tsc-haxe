package ts.tspath;

// Port of internal/tspath/file_spec.go (types and methods).

// FileSpec is a file name as written in a configuration file.
// It may be relative and may contain ${configDir}.
// PORT: an abstract over String; see RootedPath.hx.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract FileSpec(String) to String {
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
}

// PathPattern is an include or exclude pattern as written in configuration.
// It may be relative, rooted, or contain wildcards and ${configDir}.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract PathPattern(String) to String {
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
}
