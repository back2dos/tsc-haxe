package ts.tspath;

// Port of internal/tspath/module_specifier.go (type and methods).

// PORT: an abstract over String; see RootedPath.hx.
// PORT: read-only String methods forwarded (Go reads the string with AsString()).
@:forward(indexOf, lastIndexOf, substring, substr, charCodeAt, charAt, split, toLowerCase)
abstract ModuleSpecifier(String) to String {
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

	public inline function IsAbsolute():Bool {
		return Tspath.PathIsAbsolute(this);
	}

	public inline function IsRelative():Bool {
		return Tspath.PathIsRelative(this);
	}

	public inline function Contains(substring:String):Bool {
		return this.indexOf(substring) >= 0;
	}

	public inline function Resolve(...parts:String):ModuleSpecifier {
		return new ModuleSpecifier(Tspath.ResolvePathWithoutTrailingDirectorySeparator(this, ...parts));
	}

	public inline function ResolveRelative(path:RelativePath):ModuleSpecifier {
		return Resolve(path.AsString());
	}

	public inline function CombineRelative(path:RelativePath):ModuleSpecifier {
		return new ModuleSpecifier(Tspath.CombinePaths(this, path.AsString()));
	}

	public inline function RemoveFileExtension():ModuleSpecifier {
		return new ModuleSpecifier(Tspath.RemoveFileExtension(this));
	}
}
