package ts.tspath;

// Port of internal/tspath/relative_path.go (type and methods). Package-level funcs are in Tspath.hx; the
// CaseSensitivity methods are in CaseSensitivity.hx.

// RelativePath is a slash-normalized, lexically normalized path without a
// root. Leading parent components and a trailing directory separator are
// permitted. Its zero value is a valid sentinel.
// PORT: an abstract over String; see RootedPath.hx.
abstract RelativePath(String) to String {
	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	public inline function AsModuleSpecifier():ModuleSpecifier {
		return new ModuleSpecifier(Tspath.EnsurePathIsNonModuleName(this));
	}

	public inline function ChangeExtension(extension:String):RelativePath {
		Tspath.validateFileExtension(extension);
		return new RelativePath(Tspath.ChangeExtension(this, extension));
	}

	public inline function BaseName():String {
		return Tspath.getBaseFileNameFromNormalized(this);
	}

	public inline function IsParentRelative():Bool {
		return this == ".." || StringTools.startsWith(this, "../");
	}

	public inline function HasTrailingDirectorySeparator():Bool {
		return Tspath.HasTrailingDirectorySeparator(this);
	}

	public function WithoutTrailingDirectorySeparator():RelativePath {
		if (!HasTrailingDirectorySeparator()) {
			return abstract;
		}
		return new RelativePath(Tspath.RemoveTrailingDirectorySeparator(this));
	}

	public function WithTrailingDirectorySeparator():RelativePath {
		if (this == "" || HasTrailingDirectorySeparator()) {
			return abstract;
		}
		return new RelativePath(this + "/");
	}

	@:allow(ts.tspath)
	inline function requiresResolution():Bool {
		return IsParentRelative() || Tspath.HasTrailingDirectorySeparator(this);
	}
}
