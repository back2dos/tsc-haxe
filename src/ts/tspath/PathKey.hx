package ts.tspath;

import go.Strings;
import go.Tuple;
import ts.stringutil.Stringutil;

// Port of internal/tspath/pathkey.go (type and methods). Package-level funcs are in Tspath.hx.

// PathKey is a canonical key for a rooted, normalized path under a
// caller-selected CaseSensitivity. Keys are comparable only when they use the
// same CaseSensitivity. A PathKey is for comparison and lookup, and must not be
// used as a RootedPath because canonicalization may have changed its casing.
// The zero value is a valid sentinel. PathKey does not assert that the path
// exists.
// PORT: an abstract over String (no runtime cost); converts to String implicitly (Go: AsString()), never
// from String: use CaseSensitivity.PathKey or Tspath.PathKeyFromCanonical.
abstract PathKey(String) to String {
	@:allow(ts.tspath)
	inline function new(s:String) {
		this = s;
	}

	public inline function AsString():String {
		return this;
	}

	// Parent returns the lexical parent key. Root keys are fixed points, while the
	// parent of a single-component relative key is the empty key.
	public inline function Parent():PathKey {
		return new PathKey(Tspath.getDirectoryPathFromNormalized(this));
	}

	public inline function RemoveTrailingDirectorySeparator():PathKey {
		return new PathKey(Tspath.RemoveTrailingDirectorySeparator(this));
	}

	public inline function Extension():String {
		return Tspath.TryGetExtensionFromPath(this);
	}

	public inline function ExtensionIsOneOf(extensions:Array<String>):Bool {
		return Tspath.FileExtensionIsOneOf(this, extensions);
	}

	public inline function HasJSFileExtension():Bool {
		return Tspath.HasJSFileExtension(this);
	}

	public inline function BaseName():String {
		return Tspath.getBaseFileNameFromNormalized(this);
	}

	public inline function IsDynamic():Bool {
		return Tspath.IsDynamicFileName(this);
	}

	public function CaseInsensitiveKey():PathKey {
		if (Tspath.IsEncodedDynamicFileName(this)) {
			return abstract;
		}
		return new PathKey(Tspath.ToFileNameLowerCase(this));
	}

	// AppendCanonicalComponent appends an already canonical path component.
	public function AppendCanonicalComponent(component:String):PathKey {
		if (this == "") {
			throw "cannot append a component to an empty path key";
		}
		if (component == "" || Strings.IndexAny(component, "/\\") >= 0 || component == "." || component == "..") {
			throw "invalid canonical path component";
		}
		var result:String;
		if (Tspath.HasTrailingDirectorySeparator(this)) {
			result = this + component;
		} else {
			result = this + "/" + component;
		}
		return Tspath.PathKeyFromCanonical(result);
	}

	// AppendCanonicalSuffix appends a suffix that is already canonical under the
	// CaseSensitivity used to construct p.
	public function AppendCanonicalSuffix(suffix:String):PathKey {
		if (this == "" && suffix != "") {
			throw "cannot append a suffix to an empty path key";
		}
		if (Strings.IndexAny(suffix, "/\\") >= 0) {
			throw "path suffix must not contain a directory separator";
		}
		return Tspath.PathKeyFromCanonical(this + suffix);
	}

	// ReplaceCanonicalExtension replaces the suffix oldExt, which p must end with,
	// with newExt. newExt must already be canonical under the CaseSensitivity used
	// to construct p.
	public function ReplaceCanonicalExtension(oldExt:String, newExt:String):PathKey {
		if (!StringTools.endsWith(this, oldExt) || oldExt.length == this.length) {
			throw "path key must end with the extension being replaced";
		}
		if (Strings.IndexAny(newExt, "/\\") >= 0) {
			throw "extension must not contain a directory separator";
		}
		return new PathKey(this.substring(0, this.length - oldExt.length) + newExt);
	}

	// SplitAtCanonicalComponent finds component and returns the path before it and
	// the path through it. Both results retain the key's canonical casing.
	// PORT: (before, through, ok) -> null when !ok.
	public function SplitAtCanonicalComponent(component:String):Null<Pair<PathKey, PathKey>> {
		if (component == "" || Strings.IndexAny(component, "/\\") >= 0 || component == "." || component == "..") {
			throw "invalid canonical path component";
		}
		final needle = "/" + component;
		final path = this;
		final rootLength = Tspath.GetRootLength(path);
		if (rootLength == 0) {
			return null;
		}
		var offset = rootLength - 1;
		while (true) {
			final index = path.indexOf(needle, offset);
			if (index == -1) {
				return null;
			}
			final end = index + needle.length;
			if (end == path.length || StringTools.fastCodeAt(path, end) == Tspath.DirectorySeparator) {
				final beforeEnd = index > rootLength ? index : rootLength;
				return new Pair(new PathKey(path.substring(0, beforeEnd)), new PathKey(path.substring(0, end)));
			}
			offset = end;
		}
	}

	// ContainsLowercaseDirectorySequence checks a slash-delimited lowercase
	// component sequence that includes both its leading and trailing separators.
	public inline function ContainsLowercaseDirectorySequence(sequence:String):Bool {
		return this.indexOf(sequence) >= 0;
	}

	// ContainsPath checks whether child is contained within or equal to p.
	// Both keys must have been created with the same CaseSensitivity.
	public function ContainsPath(child:PathKey):Bool {
		if (this.length == 0) {
			return false;
		}
		final parent = this;
		final childText = child.AsString();
		final parentRootLength = Tspath.GetRootLength(parent);
		final childRootLength = Tspath.GetRootLength(childText);
		final dynamic_ = Tspath.IsEncodedDynamicFileName(parent) || Tspath.IsEncodedDynamicFileName(childText);
		var rootsEqual:Bool;
		if (dynamic_) {
			rootsEqual = Strings.TrimSuffix(parent.substring(0, parentRootLength), "/") == Strings.TrimSuffix(childText.substring(0, childRootLength), "/");
		} else {
			// PORT: perf — the roots compared in place first (usually "/" against "/")
			rootsEqual = (parentRootLength == childRootLength && Tspath.regionEquals(parent, childText, 0, parentRootLength))
				|| Stringutil.EquateStringCaseInsensitive(parent.substring(0, parentRootLength), childText.substring(0, childRootLength));
		}
		if (!rootsEqual) {
			return false;
		}
		// PORT: perf — parentRest/childRest compared in place instead of sliced
		final parentRestLength = parent.length - parentRootLength;
		final childRestLength = childText.length - childRootLength;
		if (parentRestLength == childRestLength && Tspath.regionEqualsAt(parent, parentRootLength, childText, childRootLength, parentRestLength)) {
			return true;
		}
		return childRestLength > parentRestLength
			&& Tspath.regionEqualsAt(parent, parentRootLength, childText, childRootLength, parentRestLength)
			&& (parentRestLength == 0
				|| StringTools.fastCodeAt(parent, parent.length - 1) == '/'.code
				|| StringTools.fastCodeAt(childText, childRootLength + parentRestLength) == '/'.code);
	}

	// ForEachAncestorDirectory calls callback for p and each of its ancestors.
	// PORT: Go's callback returns (result T, stop bool) and the function (result T, ok bool): ValueOk.
	public function ForEachAncestorDirectory<T>(callback:(path:PathKey) -> ValueOk<T>):ValueOk<T> {
		var p:PathKey = abstract;
		while (true) {
			final r = callback(p);
			if (r.ok) {
				return r;
			}
			final parent = p.Parent();
			if (parent == p) {
				return new ValueOk<T>(null, false);
			}
			p = parent;
		}
	}
}
